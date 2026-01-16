from django.db import models
from django.contrib.auth.models import User


class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    avatar = models.ImageField(upload_to='avatars/', blank=True, null=True)
    bio = models.TextField(blank=True)
    
    def __str__(self):
        return self.user.username


class MiniApp(models.Model):
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='apps', null=True, blank=True)
    bundle_id = models.CharField(max_length=100, unique=True, help_text="ex: com.ondes.calculator")
    name = models.CharField(max_length=100)
    description = models.TextField()
    icon = models.ImageField(upload_to='icons/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class AppVersion(models.Model):
    app = models.ForeignKey(MiniApp, on_delete=models.CASCADE, related_name='versions')
    version_number = models.CharField(max_length=20, help_text="ex: 1.0.0")
    zip_file = models.FileField(upload_to='apps_zips/')
    release_notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.app.name} v{self.version_number}"
