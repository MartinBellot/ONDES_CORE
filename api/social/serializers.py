from rest_framework import serializers
from django.contrib.auth.models import User
from store.models import UserProfile
from .models import (
    Follow, Post, PostMedia, PostLike, PostComment, 
    CommentLike, Story, StoryView, Bookmark
)


class UserMiniSerializer(serializers.ModelSerializer):
    """Serializer minimal pour les utilisateurs dans le contexte social"""
    avatar = serializers.SerializerMethodField()
    bio = serializers.SerializerMethodField()
    followers_count = serializers.SerializerMethodField()
    following_count = serializers.SerializerMethodField()
    is_following = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ['id', 'username', 'avatar', 'bio', 'followers_count', 'following_count', 'is_following']
    
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
    
    def get_followers_count(self, obj):
        return obj.followers_set.count()
    
    def get_following_count(self, obj):
        return obj.following_set.count()
    
    def get_is_following(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return Follow.objects.filter(follower=request.user, following=obj).exists()
        return False


class FollowSerializer(serializers.ModelSerializer):
    """Serializer pour les follows"""
    follower = UserMiniSerializer(read_only=True)
    following = UserMiniSerializer(read_only=True)
    
    class Meta:
        model = Follow
        fields = ['id', 'follower', 'following', 'created_at']
        read_only_fields = ['id', 'created_at']


class PostMediaSerializer(serializers.ModelSerializer):
    """Serializer pour les médias de posts"""
    display_url = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()
    hls_url = serializers.SerializerMethodField()
    
    class Meta:
        model = PostMedia
        fields = [
            'uuid', 'media_type', 'display_url', 'thumbnail_url', 'hls_url',
            'width', 'height', 'duration', 'processing_status', 'hls_ready', 'order'
        ]
    
    def get_display_url(self, obj):
        request = self.context.get('request')
        if obj.media_type == 'image' and obj.compressed_file:
            url = obj.compressed_file.url
        elif obj.media_type == 'video' and obj.hls_playlist and obj.hls_ready:
            url = obj.hls_playlist.url
        else:
            url = obj.original_file.url if obj.original_file else None
        
        if url and request:
            return request.build_absolute_uri(url)
        return url
    
    def get_thumbnail_url(self, obj):
        request = self.context.get('request')
        if obj.thumbnail:
            url = obj.thumbnail.url
            if request:
                return request.build_absolute_uri(url)
            return url
        return None
    
    def get_hls_url(self, obj):
        request = self.context.get('request')
        if obj.media_type == 'video' and obj.hls_playlist and obj.hls_ready:
            url = obj.hls_playlist.url
            if request:
                return request.build_absolute_uri(url)
            return url
        return None


class PostCommentSerializer(serializers.ModelSerializer):
    """Serializer pour les commentaires"""
    user = UserMiniSerializer(read_only=True)
    is_liked = serializers.SerializerMethodField()
    replies_count = serializers.SerializerMethodField()
    
    class Meta:
        model = PostComment
        fields = [
            'uuid', 'user', 'content', 'likes_count', 'is_liked',
            'replies_count', 'parent', 'created_at', 'updated_at'
        ]
        read_only_fields = ['uuid', 'likes_count', 'created_at', 'updated_at']
    
    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return CommentLike.objects.filter(user=request.user, comment=obj).exists()
        return False
    
    def get_replies_count(self, obj):
        return obj.replies.filter(is_deleted=False).count()


class PostSerializer(serializers.ModelSerializer):
    """Serializer complet pour les posts"""
    author = UserMiniSerializer(read_only=True)
    media = PostMediaSerializer(many=True, read_only=True)
    is_liked = serializers.SerializerMethodField()
    is_bookmarked = serializers.SerializerMethodField()
    comments_preview = serializers.SerializerMethodField()
    
    class Meta:
        model = Post
        fields = [
            'uuid', 'author', 'content', 'visibility', 'tags',
            'media', 'likes_count', 'comments_count', 'shares_count', 'views_count',
            'is_liked', 'is_bookmarked', 'comments_preview',
            'latitude', 'longitude', 'location_name',
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'uuid', 'likes_count', 'comments_count', 'shares_count', 
            'views_count', 'created_at', 'updated_at'
        ]
    
    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return PostLike.objects.filter(user=request.user, post=obj).exists()
        return False
    
    def get_is_bookmarked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return Bookmark.objects.filter(user=request.user, post=obj).exists()
        return False
    
    def get_comments_preview(self, obj):
        comments = obj.comments.filter(is_deleted=False, parent__isnull=True)[:3]
        return PostCommentSerializer(comments, many=True, context=self.context).data


class PostCreateSerializer(serializers.Serializer):
    """Serializer pour la création de posts"""
    content = serializers.CharField(required=False, allow_blank=True)
    visibility = serializers.ChoiceField(
        choices=['public', 'followers', 'private', 'local_mesh'],
        default='followers'
    )
    tags = serializers.ListField(
        child=serializers.CharField(),
        required=False,
        default=list
    )
    latitude = serializers.FloatField(required=False, allow_null=True)
    longitude = serializers.FloatField(required=False, allow_null=True)
    location_name = serializers.CharField(required=False, allow_blank=True)
    
    # Les médias sont gérés séparément via multipart


class StorySerializer(serializers.ModelSerializer):
    """Serializer pour les stories"""
    author = UserMiniSerializer(read_only=True)
    media_url = serializers.SerializerMethodField()
    hls_url = serializers.SerializerMethodField()
    is_viewed = serializers.SerializerMethodField()
    
    class Meta:
        model = Story
        fields = [
            'uuid', 'author', 'media_url', 'hls_url', 'media_type',
            'duration', 'views_count', 'is_viewed',
            'created_at', 'expires_at'
        ]
    
    def get_media_url(self, obj):
        request = self.context.get('request')
        if obj.media:
            url = obj.media.url
            if request:
                return request.build_absolute_uri(url)
            return url
        return None
    
    def get_hls_url(self, obj):
        request = self.context.get('request')
        if obj.media_type == 'video' and obj.hls_playlist and obj.hls_ready:
            url = obj.hls_playlist.url
            if request:
                return request.build_absolute_uri(url)
            return url
        return None
    
    def get_is_viewed(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return StoryView.objects.filter(user=request.user, story=obj).exists()
        return False


class UserStoriesSerializer(serializers.Serializer):
    """Groupement des stories par utilisateur"""
    user = UserMiniSerializer()
    stories = StorySerializer(many=True)
    has_unviewed = serializers.BooleanField()


class FeedPostSerializer(PostSerializer):
    """Serializer pour les posts du feed avec score d'algorithme local"""
    relevance_score = serializers.FloatField(read_only=True, required=False)
    
    class Meta(PostSerializer.Meta):
        fields = PostSerializer.Meta.fields + ['relevance_score']


class UserProfileSerializer(serializers.ModelSerializer):
    """Serializer complet pour le profil utilisateur social"""
    avatar = serializers.SerializerMethodField()
    bio = serializers.SerializerMethodField()
    followers_count = serializers.SerializerMethodField()
    following_count = serializers.SerializerMethodField()
    posts_count = serializers.SerializerMethodField()
    is_following = serializers.SerializerMethodField()
    recent_posts = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = [
            'id', 'username', 'avatar', 'bio',
            'followers_count', 'following_count', 'posts_count',
            'is_following', 'recent_posts'
        ]
    
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
    
    def get_followers_count(self, obj):
        return obj.followers_set.count()
    
    def get_following_count(self, obj):
        return obj.following_set.count()
    
    def get_posts_count(self, obj):
        return obj.posts.filter(is_deleted=False).count()
    
    def get_is_following(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated and request.user != obj:
            return Follow.objects.filter(follower=request.user, following=obj).exists()
        return False
    
    def get_recent_posts(self, obj):
        posts = obj.posts.filter(is_deleted=False)[:6]
        return PostSerializer(posts, many=True, context=self.context).data
