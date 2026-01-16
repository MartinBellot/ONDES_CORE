from django.contrib import admin
from .models import (
    Follow, Post, PostMedia, PostLike, PostComment, 
    CommentLike, Story, StoryView, Bookmark
)


@admin.register(Follow)
class FollowAdmin(admin.ModelAdmin):
    list_display = ['follower', 'following', 'created_at']
    list_filter = ['created_at']
    search_fields = ['follower__username', 'following__username']
    raw_id_fields = ['follower', 'following']


class PostMediaInline(admin.TabularInline):
    model = PostMedia
    extra = 0
    readonly_fields = ['uuid', 'processing_status', 'hls_ready', 'created_at']


@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ['uuid', 'author', 'visibility', 'likes_count', 'comments_count', 'views_count', 'created_at']
    list_filter = ['visibility', 'is_deleted', 'created_at']
    search_fields = ['author__username', 'content', 'tags']
    raw_id_fields = ['author']
    readonly_fields = ['uuid', 'likes_count', 'comments_count', 'shares_count', 'views_count']
    inlines = [PostMediaInline]


@admin.register(PostMedia)
class PostMediaAdmin(admin.ModelAdmin):
    list_display = ['uuid', 'post', 'media_type', 'processing_status', 'hls_ready', 'created_at']
    list_filter = ['media_type', 'processing_status', 'hls_ready']
    readonly_fields = ['uuid', 'width', 'height', 'duration', 'file_size']


@admin.register(PostLike)
class PostLikeAdmin(admin.ModelAdmin):
    list_display = ['user', 'post', 'created_at']
    raw_id_fields = ['user', 'post']


@admin.register(PostComment)
class PostCommentAdmin(admin.ModelAdmin):
    list_display = ['uuid', 'user', 'post', 'content', 'likes_count', 'created_at']
    list_filter = ['is_deleted', 'created_at']
    search_fields = ['user__username', 'content']
    raw_id_fields = ['user', 'post', 'parent']


@admin.register(Story)
class StoryAdmin(admin.ModelAdmin):
    list_display = ['uuid', 'author', 'media_type', 'views_count', 'created_at', 'expires_at', 'is_expired']
    list_filter = ['media_type', 'hls_ready', 'created_at']
    search_fields = ['author__username']
    readonly_fields = ['uuid', 'views_count']


@admin.register(Bookmark)
class BookmarkAdmin(admin.ModelAdmin):
    list_display = ['user', 'post', 'created_at']
    raw_id_fields = ['user', 'post']
