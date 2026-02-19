from django.db import models
from django.contrib.auth.models import User
import uuid


class GenesisProject(models.Model):
    """Top-level container for a user's generated Mini-App."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='genesis_projects')
    title = models.CharField(max_length=255, default='Untitled App')
    is_deployed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f"[{self.user.username}] {self.title}"

    @property
    def current_version(self):
        """Returns the latest ProjectVersion, or None."""
        return self.versions.order_by('-version_number').first()


class ProjectVersion(models.Model):
    """Immutable snapshot of the generated HTML code at a given iteration."""
    project = models.ForeignKey(GenesisProject, on_delete=models.CASCADE, related_name='versions')
    version_number = models.PositiveIntegerField(default=1)
    html_code = models.TextField(blank=True)
    change_description = models.TextField(blank=True, help_text="Short changelog explaining what changed in this version")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-version_number']
        unique_together = [('project', 'version_number')]

    def __str__(self):
        return f"{self.project.title} v{self.version_number}"


class ConversationTurn(models.Model):
    """One message in the conversation between the user and GENESIS."""
    ROLES = [
        ('user', 'User'),
        ('assistant', 'Assistant'),
        ('system', 'System'),
    ]

    project = models.ForeignKey(GenesisProject, on_delete=models.CASCADE, related_name='conversation')
    role = models.CharField(max_length=16, choices=ROLES)
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['timestamp']

    def __str__(self):
        return f"[{self.role}] {self.project.title} — {self.timestamp:%Y-%m-%d %H:%M}"
