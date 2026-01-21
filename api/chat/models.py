"""
Ondes Chat - Modèles pour la messagerie chiffrée de bout en bout (E2EE)

Architecture E2EE:
- Chaque utilisateur génère une paire de clés X25519 (publique/privée)
- La clé publique est stockée sur le serveur
- La clé privée reste UNIQUEMENT sur l'appareil de l'utilisateur
- Les messages sont chiffrés avec AES-256-GCM côté client
- Le serveur ne stocke QUE les messages chiffrés (jamais en clair)
"""

import uuid
from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone


class UserKeyPair(models.Model):
    """
    Stocke la clé publique de l'utilisateur pour le chiffrement E2EE.
    La clé privée n'est JAMAIS transmise au serveur.
    """
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='chat_keypair',
        verbose_name="Utilisateur"
    )
    # Clé publique X25519 encodée en base64
    public_key = models.CharField(
        max_length=64,
        verbose_name="Clé publique (Base64)"
    )
    # Signature de la clé pour vérification d'identité
    key_signature = models.CharField(
        max_length=128,
        blank=True,
        verbose_name="Signature de la clé"
    )
    # Date de création/rotation de la clé
    created_at = models.DateTimeField(auto_now_add=True)
    rotated_at = models.DateTimeField(auto_now=True)
    # Version de la clé (pour rotation)
    version = models.PositiveIntegerField(default=1)
    
    class Meta:
        verbose_name = "Clé utilisateur"
        verbose_name_plural = "Clés utilisateurs"
    
    def __str__(self):
        return f"{self.user.username} - v{self.version}"


class Conversation(models.Model):
    """
    Représente une conversation (privée ou groupe).
    """
    CONVERSATION_TYPES = [
        ('private', 'Conversation privée'),
        ('group', 'Groupe'),
    ]
    
    uuid = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    name = models.CharField(
        max_length=100, 
        blank=True, 
        verbose_name="Nom du groupe"
    )
    conversation_type = models.CharField(
        max_length=20,
        choices=CONVERSATION_TYPES,
        default='private',
        verbose_name="Type"
    )
    # Avatar du groupe (optionnel)
    avatar = models.ImageField(
        upload_to='chat/avatars/',
        null=True,
        blank=True,
        verbose_name="Avatar"
    )
    # Créateur du groupe
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_conversations',
        verbose_name="Créé par"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Clé de groupe chiffrée (pour les groupes uniquement)
    # Chaque membre a sa propre version de la clé, chiffrée avec sa clé publique
    
    class Meta:
        verbose_name = "Conversation"
        verbose_name_plural = "Conversations"
        ordering = ['-updated_at']
    
    def __str__(self):
        if self.conversation_type == 'private':
            members = self.members.all()[:2]
            names = [m.user.username for m in members]
            return f"DM: {' ↔ '.join(names)}"
        return f"Groupe: {self.name}"


class ConversationMember(models.Model):
    """
    Membre d'une conversation avec ses clés de déchiffrement.
    """
    ROLE_CHOICES = [
        ('member', 'Membre'),
        ('admin', 'Admin'),
        ('owner', 'Propriétaire'),
    ]
    
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='members',
        verbose_name="Conversation"
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='chat_memberships',
        verbose_name="Utilisateur"
    )
    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default='member',
        verbose_name="Rôle"
    )
    # Clé de conversation chiffrée avec la clé publique de l'utilisateur
    # Pour les groupes: clé de groupe chiffrée
    # Pour les DM: clé partagée chiffrée
    encrypted_conversation_key = models.TextField(
        blank=True,
        verbose_name="Clé de conversation chiffrée"
    )
    # Notifications
    notifications_enabled = models.BooleanField(default=True)
    muted_until = models.DateTimeField(null=True, blank=True)
    # Dernier message lu
    last_read_message = models.ForeignKey(
        'Message',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='read_by_members'
    )
    joined_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = "Membre"
        verbose_name_plural = "Membres"
        unique_together = ('conversation', 'user')
    
    def __str__(self):
        return f"{self.user.username} dans {self.conversation}"


class Message(models.Model):
    """
    Message chiffré de bout en bout.
    Le contenu est TOUJOURS chiffré côté client avant envoi.
    """
    MESSAGE_TYPES = [
        ('text', 'Texte'),
        ('image', 'Image'),
        ('video', 'Vidéo'),
        ('audio', 'Audio'),
        ('file', 'Fichier'),
        ('system', 'Système'),
    ]
    
    uuid = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='messages',
        verbose_name="Conversation"
    )
    sender = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='chat_messages_sent',
        verbose_name="Expéditeur"
    )
    # Message type
    message_type = models.CharField(
        max_length=20,
        choices=MESSAGE_TYPES,
        default='text',
        verbose_name="Type"
    )
    
    # ====== CONTENU CHIFFRÉ ======
    # Le contenu du message chiffré avec AES-256-GCM
    # Format: base64(nonce || ciphertext || tag)
    encrypted_content = models.TextField(
        verbose_name="Contenu chiffré (E2EE)"
    )
    # Métadonnées chiffrées (nom de fichier, taille, etc.)
    encrypted_metadata = models.TextField(
        blank=True,
        verbose_name="Métadonnées chiffrées"
    )
    
    # ====== FICHIERS CHIFFRÉS ======
    # Pour les médias: fichier chiffré
    encrypted_file = models.FileField(
        upload_to='chat/encrypted/',
        null=True,
        blank=True,
        verbose_name="Fichier chiffré"
    )
    
    # ====== RÉPONSE À UN MESSAGE ======
    reply_to = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='replies',
        verbose_name="En réponse à"
    )
    
    # ====== TIMESTAMPS ======
    created_at = models.DateTimeField(auto_now_add=True)
    edited_at = models.DateTimeField(null=True, blank=True)
    is_deleted = models.BooleanField(default=False)
    
    class Meta:
        verbose_name = "Message"
        verbose_name_plural = "Messages"
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['conversation', 'created_at']),
            models.Index(fields=['sender', 'created_at']),
        ]
    
    def __str__(self):
        return f"{self.sender.username if self.sender else 'System'}: [Chiffré] ({self.uuid})"
    
    def mark_as_edited(self):
        self.edited_at = timezone.now()
        self.save(update_fields=['edited_at'])
    
    def soft_delete(self):
        """Suppression douce - le message reste mais son contenu est effacé"""
        self.is_deleted = True
        self.encrypted_content = ""
        self.encrypted_metadata = ""
        if self.encrypted_file:
            self.encrypted_file.delete()
            self.encrypted_file = None
        self.save()


class MessageReceipt(models.Model):
    """
    Accusé de réception pour les messages.
    """
    RECEIPT_TYPES = [
        ('delivered', 'Délivré'),
        ('read', 'Lu'),
    ]
    
    message = models.ForeignKey(
        Message,
        on_delete=models.CASCADE,
        related_name='receipts'
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='message_receipts'
    )
    receipt_type = models.CharField(max_length=20, choices=RECEIPT_TYPES)
    timestamp = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ('message', 'user', 'receipt_type')
        verbose_name = "Accusé de réception"
        verbose_name_plural = "Accusés de réception"


class TypingIndicator(models.Model):
    """
    Indicateur de frappe en temps réel.
    Stockage temporaire, nettoyé régulièrement.
    """
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='typing_indicators'
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='typing_in'
    )
    started_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ('conversation', 'user')
