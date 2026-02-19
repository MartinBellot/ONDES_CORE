import logging

from asgiref.sync import sync_to_async
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated

from .models import GenesisProject, ProjectVersion, ConversationTurn
from .serializers import (
    GenesisProjectDetailSerializer,
    GenesisProjectListSerializer,
    ProjectVersionSerializer,
    ProjectVersionListSerializer,
)
from .services import GenesisAgent

logger = logging.getLogger('genesis')


# ---------------------------------------------------------------------------
# Async ORM helpers
# All Django ORM access must be wrapped with sync_to_async when called from
# an async view to avoid SynchronousOnlyOperation errors, and to ensure the
# long-running LLM awaits do not block the ASGI thread pool.
# ---------------------------------------------------------------------------

@sync_to_async
def _get_project(project_id, user):
    return GenesisProject.objects.get(id=project_id, user=user)


@sync_to_async
def _create_project(user, title):
    return GenesisProject.objects.create(user=user, title=title)


@sync_to_async
def _delete_project(project):
    project.delete()


@sync_to_async
def _create_turn(project, role, content):
    return ConversationTurn.objects.create(project=project, role=role, content=content)


@sync_to_async
def _create_version(project, version_number, html_code, description):
    return ProjectVersion.objects.create(
        project=project,
        version_number=version_number,
        html_code=html_code,
        change_description=description,
    )


@sync_to_async
def _build_history(project) -> list:
    turns = project.conversation.exclude(role='system').order_by('timestamp')
    return [{'role': t.role, 'content': t.content} for t in turns]


@sync_to_async
def _get_current_version(project):
    return project.current_version


@sync_to_async
def _serialize_project_detail(project):
    return GenesisProjectDetailSerializer(project).data


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

    Async: the LLM streaming call runs entirely in the asyncio event loop.
    No ThreadPoolExecutor is involved, so the ASGI thread pool stays free
    for other requests during the (potentially multi-minute) generation.
    """
    permission_classes = [IsAuthenticated]

    async def post(self, request):
        prompt = request.data.get('prompt', '').strip()
        if not prompt:
            return Response({'error': 'prompt is required'}, status=status.HTTP_400_BAD_REQUEST)

        title = request.data.get('title') or prompt[:60]

        project = await _create_project(user=request.user, title=title)
        await _create_turn(project, 'user', prompt)

        try:
            agent = GenesisAgent()
            html_code, description = await agent.create_async(prompt)
        except Exception as exc:
            logger.exception("GenesisAgent.create_async failed: %s", exc)
            await _delete_project(project)
            return Response({'error': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        await _create_version(project, 1, html_code, description)
        await _create_turn(project, 'assistant', f"[Version 1] {description}")

        data = await _serialize_project_detail(project)
        return Response(data, status=status.HTTP_201_CREATED)


class GenesisIterateView(APIView):
    """
    POST /api/genesis/<id>/iterate/
    Body: { "feedback": "change la couleur de fond en violet" }
    """
    permission_classes = [IsAuthenticated]

    async def post(self, request, project_id):
        try:
            project = await _get_project(project_id, request.user)
        except GenesisProject.DoesNotExist:
            return Response({'error': 'Project not found'}, status=status.HTTP_404_NOT_FOUND)

        feedback = request.data.get('feedback', '').strip()
        if not feedback:
            return Response({'error': 'feedback is required'}, status=status.HTTP_400_BAD_REQUEST)

        current_version = await _get_current_version(project)
        if not current_version:
            return Response(
                {'error': 'No code to iterate on. Call /create/ first.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        await _create_turn(project, 'user', feedback)
        history = await _build_history(project)

        try:
            agent = GenesisAgent()
            html_code, description = await agent.iterate_async(
                current_html=current_version.html_code,
                history=history[:-1],
                feedback=feedback,
            )
        except Exception as exc:
            logger.exception("GenesisAgent.iterate_async failed: %s", exc)
            return Response({'error': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        next_number = current_version.version_number + 1
        await _create_version(project, next_number, html_code, description)
        await _create_turn(project, 'assistant', f"[Version {next_number}] {description}")

        data = await _serialize_project_detail(project)
        return Response(data)


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

    async def post(self, request, project_id):
        try:
            project = await _get_project(project_id, request.user)
        except GenesisProject.DoesNotExist:
            return Response({'error': 'Project not found'}, status=status.HTTP_404_NOT_FOUND)

        error_message = request.data.get('message', '').strip()
        if not error_message:
            return Response({'error': 'message is required'}, status=status.HTTP_400_BAD_REQUEST)

        error_source = request.data.get('source', None)
        error_line = request.data.get('lineno', None)

        current_version = await _get_current_version(project)
        if not current_version:
            return Response({'error': 'No code yet.'}, status=status.HTTP_400_BAD_REQUEST)

        # Store as system turn for traceability
        error_content = f"[AUTO-FIX] JS Error: {error_message}"
        if error_source:
            error_content += f" | source: {error_source}"
        if error_line:
            error_content += f" | line: {error_line}"
        await _create_turn(project, 'system', error_content)

        history = await _build_history(project)

        try:
            agent = GenesisAgent()
            html_code, description = await agent.fix_error_async(
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
        await _create_version(
            project, next_number, html_code,
            f"[Auto-fix v{next_number}] {description}",
        )
        await _create_turn(
            project, 'assistant',
            f"[Auto-fix v{next_number}] Corrected: {error_message[:100]}",
        )

        data = await _serialize_project_detail(project)
        return Response(data)


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
