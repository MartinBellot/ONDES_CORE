import logging

import stripe
from asgiref.sync import async_to_sync
from django.conf import settings
from django.http import HttpResponse
from django.utils import timezone
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import ConversationTurn, GenesisProject, GenesisQuota, ProjectVersion
from .serializers import (
    GenesisProjectDetailSerializer,
    GenesisProjectListSerializer,
    GenesisQuotaSerializer,
    ProjectVersionListSerializer,
    ProjectVersionSerializer,
)
from .services import GenesisAgent

stripe.api_key = settings.STRIPE_SECRET_KEY

logger = logging.getLogger('genesis')


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_or_create_quota(user):
    quota, _ = GenesisQuota.objects.get_or_create(user=user)
    return quota


def _quota_response_data(project, user):
    """Merge project detail + live quota into a single response dict."""
    data = GenesisProjectDetailSerializer(project).data
    data['quota'] = GenesisQuotaSerializer(_get_or_create_quota(user)).data
    return data


def _build_history(project, max_turns: int = 20) -> list:
    turns = list(
        project.conversation.exclude(role='system').order_by('timestamp')
    )
    # Keep only the most recent turns to bound context-window growth.
    turns = turns[-max_turns:]
    return [{'role': t.role, 'content': t.content} for t in turns]


# ---------------------------------------------------------------------------
# Views
# ---------------------------------------------------------------------------

class GenesisProjectListView(APIView):
    """
    GET  /api/genesis/         → list the current user's projects
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        projects = GenesisProject.objects.filter(user=request.user)
        serializer = GenesisProjectListSerializer(projects, many=True)
        return Response(serializer.data)


class GenesisCreateView(APIView):
    """
    POST /api/genesis/create/
    Body: { "prompt": "une app météo avec animation de pluie", "title": "Météo" (opt) }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        prompt = request.data.get('prompt', '').strip()
        if not prompt:
            return Response({'error': 'prompt is required'}, status=status.HTTP_400_BAD_REQUEST)

        # ── Quota check (before any LLM call) ──────────────────────────────
        quota = _get_or_create_quota(request.user)
        if not quota.can_create():
            return Response(
                {
                    'error': 'quota_exceeded',
                    'message': f"Tu as atteint ta limite de {quota.monthly_limit} créations ce mois-ci.",
                    'plan': quota.plan,
                    'monthly_limit': quota.monthly_limit,
                    'remaining_creations': quota.remaining_creations,
                    'quota': GenesisQuotaSerializer(quota).data,
                },
                status=status.HTTP_402_PAYMENT_REQUIRED,
            )

        title = request.data.get('title') or prompt[:60]

        project = GenesisProject.objects.create(user=request.user, title=title)
        ConversationTurn.objects.create(project=project, role='user', content=prompt)

        try:
            agent = GenesisAgent()
            # async_to_sync runs the coroutine in a fresh thread with its own
            # event loop — safe from both sync and ASGI contexts, no asyncio.run()
            html_code, description = async_to_sync(agent.create_async)(prompt)
        except Exception as exc:
            logger.exception("GenesisAgent.create_async failed: %s", exc)
            project.delete()
            return Response({'error': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        ProjectVersion.objects.create(
            project=project,
            version_number=1,
            html_code=html_code,
            change_description=description,
        )
        ConversationTurn.objects.create(
            project=project,
            role='assistant',
            content=f"[Version 1] {description}",
        )

        # ── Consume quota credit (after HTML is saved) ─────────────────────
        try:
            quota.consume_creation()
        except ValueError:
            pass  # should not happen — we checked can_create() above

        return Response(
            _quota_response_data(project, request.user),
            status=status.HTTP_201_CREATED,
        )


class GenesisIterateView(APIView):
    """
    POST /api/genesis/<id>/iterate/
    Body: { "feedback": "change la couleur de fond en violet" }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, project_id):
        try:
            project = GenesisProject.objects.get(id=project_id, user=request.user)
        except GenesisProject.DoesNotExist:
            return Response({'error': 'Project not found'}, status=status.HTTP_404_NOT_FOUND)

        feedback = request.data.get('feedback', '').strip()
        if not feedback:
            return Response({'error': 'feedback is required'}, status=status.HTTP_400_BAD_REQUEST)

        current_version = project.current_version
        if not current_version:
            return Response(
                {'error': 'No code to iterate on. Call /create/ first.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        ConversationTurn.objects.create(project=project, role='user', content=feedback)
        history = _build_history(project)

        try:
            agent = GenesisAgent()
            html_code, description = async_to_sync(agent.iterate_async)(
                current_html=current_version.html_code,
                history=history[:-1],
                feedback=feedback,
            )
        except Exception as exc:
            logger.exception("GenesisAgent.iterate_async failed: %s", exc)
            return Response({'error': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        next_number = current_version.version_number + 1
        ProjectVersion.objects.create(
            project=project,
            version_number=next_number,
            html_code=html_code,
            change_description=description,
        )
        ConversationTurn.objects.create(
            project=project,
            role='assistant',
            content=f"[Version {next_number}] {description}",
        )

        return Response(_quota_response_data(project, request.user))


class GenesisReportErrorView(APIView):
    """
    POST /api/genesis/<id>/report_error/
    Body: {
        "message": "TypeError: Cannot read property ...",
        "source": "blob:...",   (optional)
        "lineno": 42            (optional)
    }

    Triggers automatic LLM-based self-correction.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, project_id):
        try:
            project = GenesisProject.objects.get(id=project_id, user=request.user)
        except GenesisProject.DoesNotExist:
            return Response({'error': 'Project not found'}, status=status.HTTP_404_NOT_FOUND)

        error_message = request.data.get('message', '').strip()
        if not error_message:
            return Response({'error': 'message is required'}, status=status.HTTP_400_BAD_REQUEST)

        error_source = request.data.get('source', None)
        error_line = request.data.get('lineno', None)

        current_version = project.current_version
        if not current_version:
            return Response({'error': 'No code yet.'}, status=status.HTTP_400_BAD_REQUEST)

        # Store as system turn for traceability
        error_content = f"[AUTO-FIX] JS Error: {error_message}"
        if error_source:
            error_content += f" | source: {error_source}"
        if error_line:
            error_content += f" | line: {error_line}"
        ConversationTurn.objects.create(project=project, role='system', content=error_content)

        history = _build_history(project)

        try:
            agent = GenesisAgent()
            html_code, description = async_to_sync(agent.fix_error_async)(
                current_html=current_version.html_code,
                history=history,
                error_message=error_message,
                error_source=error_source,
                error_line=error_line,
            )
        except Exception as exc:
            logger.exception("GenesisAgent.fix_error_async failed: %s", exc)
            return Response({'error': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        next_number = current_version.version_number + 1
        ProjectVersion.objects.create(
            project=project,
            version_number=next_number,
            html_code=html_code,
            change_description=f"[Auto-fix v{next_number}] {description}",
        )
        ConversationTurn.objects.create(
            project=project,
            role='assistant',
            content=f"[Auto-fix v{next_number}] Corrected: {error_message[:100]}",
        )

        serializer = GenesisProjectDetailSerializer(project)
        return Response(serializer.data)


class GenesisDeployView(APIView):
    """
    POST /api/genesis/<id>/deploy/
    Marks the current version as production (is_deployed = True).
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, project_id):
        try:
            project = GenesisProject.objects.get(id=project_id, user=request.user)
        except GenesisProject.DoesNotExist:
            return Response({'error': 'Project not found'}, status=status.HTTP_404_NOT_FOUND)

        if not project.current_version or not project.current_version.html_code.strip():
            return Response({'error': 'No valid code to deploy'}, status=status.HTTP_400_BAD_REQUEST)

        project.is_deployed = True
        project.save(update_fields=['is_deployed', 'updated_at'])

        serializer = GenesisProjectDetailSerializer(project)
        return Response(serializer.data)


class GenesisProjectDetailView(APIView):
    """
    GET  /api/genesis/<id>/   → project details with conversation, current version & version history
    DELETE /api/genesis/<id>/ → delete the project
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, project_id):
        try:
            project = GenesisProject.objects.get(id=project_id, user=request.user)
        except GenesisProject.DoesNotExist:
            return Response({'error': 'Project not found'}, status=status.HTTP_404_NOT_FOUND)

        serializer = GenesisProjectDetailSerializer(project)
        return Response(serializer.data)

    def delete(self, request, project_id):
        try:
            project = GenesisProject.objects.get(id=project_id, user=request.user)
        except GenesisProject.DoesNotExist:
            return Response({'error': 'Project not found'}, status=status.HTTP_404_NOT_FOUND)

        project.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class GenesisVersionDetailView(APIView):
    """
    GET /api/genesis/<id>/versions/<version_id>/
    Returns the full version object including html_code (used to preview an old version).
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, project_id, version_id):
        try:
            project = GenesisProject.objects.get(id=project_id, user=request.user)
        except GenesisProject.DoesNotExist:
            return Response({'error': 'Project not found'}, status=status.HTTP_404_NOT_FOUND)

        try:
            version = project.versions.get(id=version_id)
        except ProjectVersion.DoesNotExist:
            return Response({'error': 'Version not found'}, status=status.HTTP_404_NOT_FOUND)

        serializer = ProjectVersionSerializer(version)
        return Response(serializer.data)


class GenesisSaveEditView(APIView):
    """
    POST /api/genesis/<id>/save_edit/
    Body: { "html_code": "...", "description": "..." (optional) }
    Persists a manually-edited version as the new current version.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, project_id):
        try:
            project = GenesisProject.objects.get(id=project_id, user=request.user)
        except GenesisProject.DoesNotExist:
            return Response({'error': 'Project not found'}, status=status.HTTP_404_NOT_FOUND)

        html_code = request.data.get('html_code', '').strip()
        if not html_code:
            return Response({'error': 'html_code is required'}, status=status.HTTP_400_BAD_REQUEST)

        description = (request.data.get('description') or 'Édition manuelle').strip()

        current = project.current_version
        next_number = (current.version_number + 1) if current else 1

        ProjectVersion.objects.create(
            project=project,
            version_number=next_number,
            html_code=html_code,
            change_description=description,
        )

        ConversationTurn.objects.create(
            project=project,
            role='system',
            content=f'[v{next_number}] {description}',
        )

        logger.info("GenesisSaveEdit: project %s → v%d", project_id, next_number)
        serializer = GenesisProjectDetailSerializer(project)
        return Response(serializer.data)


# ---------------------------------------------------------------------------
# Quota
# ---------------------------------------------------------------------------

class GenesisQuotaView(APIView):
    """GET /api/genesis/quota/"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        quota = _get_or_create_quota(request.user)
        return Response(GenesisQuotaSerializer(quota).data)


# ---------------------------------------------------------------------------
# Stripe
# ---------------------------------------------------------------------------

class GenesisCheckoutView(APIView):
    """
    POST /api/genesis/checkout/
    Body: { "price_id": "price_xxx", "success_url": "...", "cancel_url": "..." }
    Returns: { "checkout_url": "https://checkout.stripe.com/..." }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        price_id = request.data.get('price_id', '').strip()
        success_url = request.data.get('success_url', '').strip()
        cancel_url = request.data.get('cancel_url', '').strip()

        if not price_id or not success_url or not cancel_url:
            return Response(
                {'error': 'price_id, success_url and cancel_url are required'},
                status=400,
            )

        quota = _get_or_create_quota(request.user)

        # Get or create Stripe customer
        if not quota.stripe_customer_id:
            customer = stripe.Customer.create(
                email=request.user.email,
                metadata={'user_id': str(request.user.id), 'username': request.user.username},
            )
            quota.stripe_customer_id = customer.id
            quota.save(update_fields=['stripe_customer_id'])

        try:
            pro_price_ids = [
                settings.STRIPE_PRO_MONTHLY_PRICE_ID,
                settings.STRIPE_PRO_YEARLY_PRICE_ID,
            ]
            mode = 'subscription' if price_id in pro_price_ids else 'payment'

            session = stripe.checkout.Session.create(
                customer=quota.stripe_customer_id,
                line_items=[{'price': price_id, 'quantity': 1}],
                mode=mode,
                success_url=success_url,
                cancel_url=cancel_url,
                metadata={
                    'user_id': str(request.user.id),
                    'price_id': price_id,
                },
            )
            return Response({'checkout_url': session.url})
        except stripe.StripeError as e:
            return Response({'error': str(e)}, status=502)


class GenesisPortalView(APIView):
    """
    POST /api/genesis/portal/
    Body: { "return_url": "..." }
    Returns: { "portal_url": "https://billing.stripe.com/..." }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        quota = _get_or_create_quota(request.user)
        if not quota.stripe_customer_id:
            return Response({'error': 'No Stripe customer found'}, status=400)

        return_url = request.data.get('return_url', '')
        try:
            session = stripe.billing_portal.Session.create(
                customer=quota.stripe_customer_id,
                return_url=return_url,
            )
            return Response({'portal_url': session.url})
        except stripe.StripeError as e:
            return Response({'error': str(e)}, status=502)


@method_decorator(csrf_exempt, name='dispatch')
class GenesisStripeWebhookView(APIView):
    """
    POST /api/genesis/stripe/webhook/
    Handles: checkout.session.completed, customer.subscription.deleted,
             customer.subscription.updated, invoice.payment_failed
    """
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        payload = request.body
        sig_header = request.META.get('HTTP_STRIPE_SIGNATURE', '')

        try:
            event = stripe.Webhook.construct_event(
                payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
            )
        except (ValueError, stripe.SignatureVerificationError):
            return HttpResponse(status=400)

        data = event['data']['object']

        if event['type'] == 'checkout.session.completed':
            user_id = data.get('metadata', {}).get('user_id')
            price_id = data.get('metadata', {}).get('price_id')
            if not user_id:
                return HttpResponse(status=200)

            try:
                from django.contrib.auth.models import User as DjangoUser
                user = DjangoUser.objects.get(id=user_id)
                quota = _get_or_create_quota(user)

                if price_id == settings.STRIPE_PRO_MONTHLY_PRICE_ID:
                    quota.plan = GenesisQuota.PLAN_PRO
                    quota.subscription_period = 'monthly'
                    quota.stripe_subscription_id = data.get('subscription', '')
                elif price_id == settings.STRIPE_PRO_YEARLY_PRICE_ID:
                    quota.plan = GenesisQuota.PLAN_PRO
                    quota.subscription_period = 'yearly'
                    quota.stripe_subscription_id = data.get('subscription', '')
                elif price_id == settings.STRIPE_CREDIT_PACK_PRICE_ID:
                    quota.extra_credits += 10

                quota.save()
            except Exception:
                pass

        elif event['type'] in ('customer.subscription.deleted', 'invoice.payment_failed'):
            sub_id = data.get('id') or data.get('subscription', '')
            if sub_id:
                GenesisQuota.objects.filter(stripe_subscription_id=sub_id).update(
                    plan=GenesisQuota.PLAN_FREE,
                    stripe_subscription_id='',
                    subscription_period='',
                    subscription_end_date=timezone.now(),
                )

        elif event['type'] == 'customer.subscription.updated':
            sub_id = data.get('id', '')
            if data.get('cancel_at_period_end', False):
                end_ts = data.get('current_period_end')
                if end_ts:
                    import datetime
                    GenesisQuota.objects.filter(stripe_subscription_id=sub_id).update(
                        subscription_end_date=datetime.datetime.fromtimestamp(
                            end_ts, tz=datetime.timezone.utc
                        )
                    )

        return HttpResponse(status=200)
