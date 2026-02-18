import uuid
import os
from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from django.core.validators import FileExtensionValidator


def post_media_upload_path(instance, filename):
    """Génère un chemin unique pour les médias de posts"""
    ext = filename.split('.')[-1]
    unique_id = uuid.uuid4().hex[:8]
    return f"posts/{instance.post.author.id}/{instance.post.uuid}/{unique_id}.{ext}"


def compressed_image_upload_path(instance, filename):
    """Chemin pour les images compressées"""
    ext = filename.split('.')[-1]
    unique_id = uuid.uuid4().hex[:8]
    return f"posts/{instance.post.author.id}/{instance.post.uuid}/compressed/{unique_id}.{ext}"


def hls_video_upload_path(instance, filename):
    """Chemin pour les vidéos HLS"""
    return f"posts/{instance.post.author.id}/{instance.post.uuid}/hls/{filename}"


class Follow(models.Model):
    """
    Représente une relation de follow (unidirectionnelle).
    follower suit following.
    """
    follower = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='following_set',
        verbose_name="Follower"
    )
    following = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='followers_set',
        verbose_name="Following"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = "Follow"
        verbose_name_plural = "Follows"
        unique_together = ('follower', 'following')
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.follower.username} → {self.following.username}"


class Post(models.Model):
    """
    Représente un post/publication dans le feed.
    """
    VISIBILITY_CHOICES = [
        ('public', 'Public'),
        ('followers', 'Followers only'),
        ('private', 'Private'),
        ('local_mesh', 'Local Mesh'),
    ]
    
    uuid = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    author = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='posts',
        verbose_name="Auteur"
    )
    content = models.TextField(blank=True, verbose_name="Contenu")
    visibility = models.CharField(
        max_length=20,
        choices=VISIBILITY_CHOICES,
        default='followers',
        verbose_name="Visibilité"
    )
    tags = models.JSONField(default=list, blank=True, verbose_name="Tags")
    
    # Statistiques
    likes_count = models.PositiveIntegerField(default=0)
    comments_count = models.PositiveIntegerField(default=0)
    shares_count = models.PositiveIntegerField(default=0)
    views_count = models.PositiveIntegerField(default=0)
    
    # Métadonnées
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)
    
    # Localisation optionnelle
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    location_name = models.CharField(max_length=200, blank=True)
    
    class Meta:
        verbose_name = "Post"
        verbose_name_plural = "Posts"
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.author.username}: {self.content[:50]}..."
    
    def increment_views(self):
        self.views_count += 1
        self.save(update_fields=['views_count'])


class PostMedia(models.Model):
    """
    Média attaché à un post (image ou vidéo).
    Gère la compression d'images et la conversion HLS pour les vidéos.
    """
    MEDIA_TYPE_CHOICES = [
        ('image', 'Image'),
        ('video', 'Video'),
    ]
    
    PROCESSING_STATUS_CHOICES = [
        ('pending', 'En attente'),
        ('processing', 'En cours'),
        ('completed', 'Terminé'),
        ('failed', 'Échec'),
    ]
    
    uuid = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    post = models.ForeignKey(
        Post,
        on_delete=models.CASCADE,
        related_name='media',
        verbose_name="Post"
    )
    
    # Fichier original
    original_file = models.FileField(
        upload_to=post_media_upload_path,
        verbose_name="Fichier original",
        validators=[FileExtensionValidator(
            allowed_extensions=['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'avi', 'webm', 'mkv']
        )]
    )
    
    media_type = models.CharField(
        max_length=10,
        choices=MEDIA_TYPE_CHOICES,
        verbose_name="Type"
    )
    
    # Image compressée (pour les images)
    compressed_file = models.FileField(
        upload_to=compressed_image_upload_path,
        null=True,
        blank=True,
        verbose_name="Fichier compressé"
    )
    thumbnail = models.ImageField(
        upload_to=compressed_image_upload_path,
        null=True,
        blank=True,
        verbose_name="Miniature"
    )
    
    # HLS (pour les vidéos)
    hls_playlist = models.FileField(
        upload_to=hls_video_upload_path,
        null=True,
        blank=True,
        verbose_name="Playlist HLS (.m3u8)"
    )
    hls_ready = models.BooleanField(default=False, verbose_name="HLS prêt")
    
    # Statut de traitement
    processing_status = models.CharField(
        max_length=20,
        choices=PROCESSING_STATUS_CHOICES,
        default='pending',
        verbose_name="Statut"
    )
    processing_error = models.TextField(blank=True)
    
    # Métadonnées du média
    width = models.PositiveIntegerField(null=True, blank=True)
    height = models.PositiveIntegerField(null=True, blank=True)
    duration = models.FloatField(null=True, blank=True, help_text="Durée en secondes (vidéos)")
    file_size = models.PositiveIntegerField(null=True, blank=True, help_text="Taille en bytes")
    
    order = models.PositiveIntegerField(default=0, verbose_name="Ordre")
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = "Média"
        verbose_name_plural = "Médias"
        ordering = ['order', 'created_at']
    
    def __str__(self):
        return f"{self.media_type}: {self.original_file.name}"
    
    @property
    def display_url(self):
        """Retourne l'URL optimale à afficher"""
        if self.media_type == 'image' and self.compressed_file:
            return self.compressed_file.url
        elif self.media_type == 'video' and self.hls_playlist and self.hls_ready:
            return self.hls_playlist.url
        return self.original_file.url


class PostLike(models.Model):
    """
    Like sur un post.
    """
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='post_likes'
    )
    post = models.ForeignKey(
        Post,
        on_delete=models.CASCADE,
        related_name='likes'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = "Like"
        verbose_name_plural = "Likes"
        unique_together = ('user', 'post')
    
    def __str__(self):
        return f"{self.user.username} ❤️ {self.post.uuid}"


class PostComment(models.Model):
    """
    Commentaire sur un post.
    """
    uuid = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='post_comments'
    )
    post = models.ForeignKey(
        Post,
        on_delete=models.CASCADE,
        related_name='comments'
    )
    content = models.TextField(verbose_name="Contenu")
    parent = models.ForeignKey(
        'self',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='replies',
        verbose_name="Commentaire parent"
    )
    likes_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)
    
    class Meta:
        verbose_name = "Commentaire"
        verbose_name_plural = "Commentaires"
        ordering = ['created_at']
    
    def __str__(self):
        return f"{self.user.username}: {self.content[:30]}..."


class CommentLike(models.Model):
    """
    Like sur un commentaire.
    """
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='comment_likes'
    )
    comment = models.ForeignKey(
        PostComment,
        on_delete=models.CASCADE,
        related_name='likes'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = "Like de commentaire"
        verbose_name_plural = "Likes de commentaires"
        unique_together = ('user', 'comment')


class Story(models.Model):
    """
    Story temporaire (24h) - comme Instagram/TikTok.
    """
    uuid = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    author = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='stories'
    )
    media = models.FileField(
        upload_to='stories/',
        validators=[FileExtensionValidator(
            allowed_extensions=['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov']
        )]
    )
    media_type = models.CharField(max_length=10, choices=[('image', 'Image'), ('video', 'Video')])
    
    # HLS pour vidéos
    hls_playlist = models.FileField(upload_to='stories/hls/', null=True, blank=True)
    hls_ready = models.BooleanField(default=False)
    
    duration = models.FloatField(default=5.0, help_text="Durée d'affichage en secondes")
    views_count = models.PositiveIntegerField(default=0)
    
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    
    class Meta:
        verbose_name = "Story"
        verbose_name_plural = "Stories"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['expires_at']),
            models.Index(fields=['author', '-created_at']),
        ]
    
    def save(self, *args, **kwargs):
        if not self.expires_at:
            self.expires_at = timezone.now() + timezone.timedelta(hours=24)
        super().save(*args, **kwargs)
    
    @property
    def is_expired(self):
        return timezone.now() > self.expires_at
    
    def __str__(self):
        return f"Story de {self.author.username}"


class StoryView(models.Model):
    """
    Vue d'une story.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='story_views')
    story = models.ForeignKey(Story, on_delete=models.CASCADE, related_name='views')
    viewed_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ('user', 'story')


class Bookmark(models.Model):
    """
    Post sauvegardé/bookmarké.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='bookmarks')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='bookmarked_by')
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ('user', 'post')
        ordering = ['-created_at']
