from rest_framework import serializers
from django.contrib.auth.models import User
from store.models import UserProfile
from .models import Friendship, FriendshipActivity


class UserMiniSerializer(serializers.ModelSerializer):
    """Serializer minimal pour les utilisateurs dans le contexte des amitiés"""
    avatar = serializers.SerializerMethodField()
    bio = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ['id', 'username', 'avatar', 'bio']
    
    def get_avatar(self, obj):
        try:
            if obj.profile and obj.profile.avatar:
                request = self.context.get('request')
                if request:
                    return request.build_absolute_uri(obj.profile.avatar.url)
                return obj.profile.avatar.url
        except UserProfile.DoesNotExist:
            pass
        return f"https://api.dicebear.com/7.x/avataaars/png?seed={obj.username}"
    
    def get_bio(self, obj):
        try:
            return obj.profile.bio or ""
        except UserProfile.DoesNotExist:
            return ""


class FriendshipSerializer(serializers.ModelSerializer):
    """Serializer pour les demandes d'amitié"""
    from_user = UserMiniSerializer(read_only=True)
    to_user = UserMiniSerializer(read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = Friendship
        fields = [
            'id', 'from_user', 'to_user', 'status', 'status_display',
            'created_at', 'updated_at', 'accepted_at'
        ]
        read_only_fields = ['id', 'from_user', 'to_user', 'created_at', 'updated_at', 'accepted_at']


class FriendSerializer(serializers.Serializer):
    """Serializer pour la liste d'amis (vue simplifiée)"""
    id = serializers.IntegerField()
    username = serializers.CharField()
    avatar = serializers.CharField()
    bio = serializers.CharField()
    friendship_id = serializers.IntegerField()
    friends_since = serializers.DateTimeField()


class FriendshipActivitySerializer(serializers.ModelSerializer):
    actor_username = serializers.CharField(source='actor.username', read_only=True)
    target_username = serializers.CharField(source='target.username', read_only=True)
    action_display = serializers.CharField(source='get_action_display', read_only=True)
    
    class Meta:
        model = FriendshipActivity
        fields = [
            'id', 'actor', 'actor_username', 'target', 'target_username',
            'action', 'action_display', 'timestamp', 'ip_address'
        ]
