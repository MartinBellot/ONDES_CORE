from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone


class Friendship(models.Model):
    """
    Représente une relation d'amitié entre deux utilisateurs.
    from_user envoie la demande, to_user la reçoit.
    """
    STATUS_CHOICES = [
        ('pending', 'En attente'),
        ('accepted', 'Acceptée'),
        ('rejected', 'Refusée'),
        ('blocked', 'Bloquée'),
    ]
    
    from_user = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name='friendships_sent',
        verbose_name="De l'utilisateur"
    )
    to_user = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name='friendships_received',
        verbose_name="Vers l'utilisateur"
    )
    status = models.CharField(
        max_length=20, 
        choices=STATUS_CHOICES, 
        default='pending',
        verbose_name="Statut"
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Créé le")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Mis à jour le")
    accepted_at = models.DateTimeField(null=True, blank=True, verbose_name="Accepté le")
    
    class Meta:
        verbose_name = "Amitié"
        verbose_name_plural = "Amitiés"
        unique_together = ('from_user', 'to_user')
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.from_user.username} → {self.to_user.username} ({self.get_status_display()})"
    
    def accept(self):
        """Accepter la demande d'amitié"""
        self.status = 'accepted'
        self.accepted_at = timezone.now()
        self.save()
    
    def reject(self):
        """Refuser la demande d'amitié"""
        self.status = 'rejected'
        self.save()
    
    def block(self):
        """Bloquer l'utilisateur"""
        self.status = 'blocked'
        self.save()


class FriendshipActivity(models.Model):
    """
    Log des activités liées aux amitiés pour monitoring admin
    """
    ACTION_CHOICES = [
        ('request', 'Demande envoyée'),
        ('accept', 'Demande acceptée'),
        ('reject', 'Demande refusée'),
        ('block', 'Utilisateur bloqué'),
        ('unblock', 'Utilisateur débloqué'),
        ('remove', 'Ami supprimé'),
    ]
    
    friendship = models.ForeignKey(
        Friendship, 
        on_delete=models.CASCADE, 
        related_name='activities',
        null=True,
        blank=True
    )
    actor = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name='friendship_activities'
    )
    target = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name='friendship_activities_received'
    )
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    timestamp = models.DateTimeField(auto_now_add=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    
    class Meta:
        verbose_name = "Activité d'amitié"
        verbose_name_plural = "Activités d'amitiés"
        ordering = ['-timestamp']
    
    def __str__(self):
        return f"{self.actor.username} {self.get_action_display()} {self.target.username}"
