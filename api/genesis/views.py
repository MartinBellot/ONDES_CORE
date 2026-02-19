import logging

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
# Helpers
# ---------------------------------------------------------------------------

def _build_history(project: GenesisProject) -> list[dict]:
    """
    Convert stored ConversationTurns into the message list expected by the
    Anthropic API (role/content pairs, system role excluded).
    """
    turns = project.conversation.exclude(role='system').order_by('timestamp')
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

        title = request.data.get('title') or prompt[:60]

        # Create project
        project = GenesisProject.objects.create(user=request.user, title=title)

        # Store user turn
        ConversationTurn.objects.create(project=project, role='user', content=prompt)

        # Call LLM
        try:
            agent = GenesisAgent()
            html_code, description = agent.create(prompt)
        except Exception as exc:
            logger.exception("GenesisAgent.create failed: %s", exc)
            project.delete()
            return Response({'error': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        # Persist first version
        ProjectVersion.objects.create(
            project=project,
            version_number=1,
            html_code=html_code,
            change_description=description,
        )

        # Store assistant turn
        ConversationTurn.objects.create(
            project=project,
            role='assistant',
            content=f"[Version 1] {description}",
        )

        serializer = GenesisProjectDetailSerializer(project)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


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
            return Response({'error': 'No code to iterate on. Call /create/ first.'}, status=status.HTTP_400_BAD_REQUEST)

        # Persist user turn
        ConversationTurn.objects.create(project=project, role='user', content=feedback)

        history = _build_history(project)

        try:
            agent = GenesisAgent()
            html_code, description = agent.iterate(
                current_html=current_version.html_code,
                history=history[:-1],   # exclude the turn we just added
                feedback=feedback,
            )
        except Exception as exc:
            logger.exception("GenesisAgent.iterate failed: %s", exc)
            return Response({'error': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        # Create new version
        next_number = current_version.version_number + 1
        ProjectVersion.objects.create(
            project=project,
            version_number=next_number,
            html_code=html_code,
            change_description=description,
        )

        # Store assistant turn
        ConversationTurn.objects.create(
            project=project,
            role='assistant',
            content=f"[Version {next_number}] {description}",
        )

        serializer = GenesisProjectDetailSerializer(project)
        return Response(serializer.data)


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
            html_code, description = agent.fix_error(
                current_html=current_version.html_code,
                history=history,
                error_message=error_message,
                error_source=error_source,
                error_line=error_line,
            )
        except Exception as exc:
            logger.exception("GenesisAgent.fix_error failed: %s", exc)
            return Response({'error': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        # Create fixed version
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
