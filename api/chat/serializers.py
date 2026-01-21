from rest_framework import serializers
from django.contrib.auth.models import User
from .models import (
    UserKeyPair, Conversation, ConversationMember,
    Message, MessageReceipt
)


class UserPublicKeySerializer(serializers.ModelSerializer):
    """Sérialiseur pour les clés publiques utilisateur"""
    username = serializers.CharField(source='user.username', read_only=True)
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    
    class Meta:
        model = UserKeyPair
        fields = ('user_id', 'username', 'public_key', 'key_signature', 'version', 'rotated_at')
        read_only_fields = ('user_id', 'username', 'version', 'rotated_at')


class UserKeyPairCreateSerializer(serializers.ModelSerializer):
    """Sérialiseur pour la création/mise à jour de clé"""
    
    class Meta:
        model = UserKeyPair
        fields = ('public_key', 'key_signature')


class MemberSerializer(serializers.ModelSerializer):
    """Sérialiseur pour les membres de conversation"""
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    avatar = serializers.SerializerMethodField()
    public_key = serializers.SerializerMethodField()
    
    class Meta:
        model = ConversationMember
        fields = (
            'user_id', 'username', 'avatar', 'role',
            'encrypted_conversation_key', 'public_key',
            'notifications_enabled', 'joined_at'
        )
        read_only_fields = ('user_id', 'username', 'avatar', 'joined_at')
    
    def get_avatar(self, obj):
        # Récupérer l'avatar depuis le profil si existant
        if hasattr(obj.user, 'userprofile') and obj.user.userprofile.avatar:
            return obj.user.userprofile.avatar.url
        return None
    
    def get_public_key(self, obj):
        try:
            return obj.user.chat_keypair.public_key
        except UserKeyPair.DoesNotExist:
            return None


class ConversationListSerializer(serializers.ModelSerializer):
    """Sérialiseur pour la liste des conversations"""
    members = MemberSerializer(many=True, read_only=True)
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Conversation
        fields = (
            'uuid', 'name', 'conversation_type', 'avatar',
            'members', 'last_message', 'unread_count',
            'created_at', 'updated_at'
        )
        read_only_fields = ('uuid', 'created_at', 'updated_at')
    
    def get_last_message(self, obj):
        last_msg = obj.messages.filter(is_deleted=False).last()
        if last_msg:
            return {
                'uuid': str(last_msg.uuid),
                'sender_id': last_msg.sender.id if last_msg.sender else None,
                'sender_username': last_msg.sender.username if last_msg.sender else 'System',
                'message_type': last_msg.message_type,
                'encrypted_content': last_msg.encrypted_content,
                'created_at': last_msg.created_at.isoformat(),
            }
        return None
    
    def get_unread_count(self, obj):
        user = self.context.get('request').user
        try:
            membership = obj.members.get(user=user)
            if membership.last_read_message:
                return obj.messages.filter(
                    created_at__gt=membership.last_read_message.created_at,
                    is_deleted=False
                ).exclude(sender=user).count()
            return obj.messages.filter(is_deleted=False).exclude(sender=user).count()
        except ConversationMember.DoesNotExist:
            return 0


class ConversationCreateSerializer(serializers.Serializer):
    """Sérialiseur pour créer une conversation"""
    conversation_type = serializers.ChoiceField(
        choices=['private', 'group'],
        default='private'
    )
    name = serializers.CharField(max_length=100, required=False, allow_blank=True)
    member_ids = serializers.ListField(
        child=serializers.IntegerField(),
        min_length=1
    )
    # Clés de conversation chiffrées pour chaque membre
    encrypted_keys = serializers.DictField(
        child=serializers.CharField(),
        help_text="Dict {user_id: encrypted_key}"
    )


class MessageSerializer(serializers.ModelSerializer):
    """Sérialiseur pour les messages"""
    sender_id = serializers.IntegerField(source='sender.id', read_only=True)
    sender_username = serializers.CharField(source='sender.username', read_only=True)
    reply_to_uuid = serializers.CharField(source='reply_to.uuid', read_only=True, allow_null=True)
    receipts = serializers.SerializerMethodField()
    
    class Meta:
        model = Message
        fields = (
            'uuid', 'conversation', 'sender_id', 'sender_username',
            'message_type', 'encrypted_content', 'encrypted_metadata',
            'encrypted_file', 'reply_to_uuid', 'receipts',
            'created_at', 'edited_at', 'is_deleted'
        )
        read_only_fields = (
            'uuid', 'sender_id', 'sender_username', 
            'created_at', 'edited_at', 'is_deleted'
        )
    
    def get_receipts(self, obj):
        return {
            'delivered': list(obj.receipts.filter(
                receipt_type='delivered'
            ).values_list('user_id', flat=True)),
            'read': list(obj.receipts.filter(
                receipt_type='read'
            ).values_list('user_id', flat=True)),
        }


class MessageCreateSerializer(serializers.Serializer):
    """Sérialiseur pour créer un message"""
    conversation_uuid = serializers.UUIDField()
    message_type = serializers.ChoiceField(
        choices=['text', 'image', 'video', 'audio', 'file'],
        default='text'
    )
    encrypted_content = serializers.CharField()
    encrypted_metadata = serializers.CharField(required=False, allow_blank=True)
    reply_to_uuid = serializers.UUIDField(required=False, allow_null=True)


class TypingIndicatorSerializer(serializers.Serializer):
    """Sérialiseur pour l'indicateur de frappe"""
    conversation_uuid = serializers.UUIDField()
    is_typing = serializers.BooleanField()
