import os
import shutil
import uuid
import mimetypes
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.contrib.auth.models import User
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.conf import settings

from .models import (
    Follow, Post, PostMedia, PostLike, PostComment,
    CommentLike, Story, StoryView, Bookmark
)
from .serializers import (
    UserMiniSerializer, FollowSerializer, PostSerializer, PostCreateSerializer,
    PostCommentSerializer, StorySerializer, UserStoriesSerializer,
    FeedPostSerializer, UserProfileSerializer, PostMediaSerializer
)
from .feed_algorithm import LocalFeedAlgorithm
from .media_processing import process_post_media


# ===================== FOLLOW VIEWS =====================

class FollowUserView(APIView):
    """Suivre un utilisateur"""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user_id = request.data.get('user_id')
        username = request.data.get('username')
        
        if not user_id and not username:
            return Response(
                {'error': 'user_id or username required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            if user_id:
                target_user = User.objects.get(id=user_id)
            else:
                target_user = User.objects.get(username=username)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        if target_user == request.user:
            return Response(
                {'error': 'Cannot follow yourself'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        follow, created = Follow.objects.get_or_create(
            follower=request.user,
            following=target_user
        )
        
        if not created:
            return Response(
                {'error': 'Already following this user'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        return Response({
            'success': True,
            'message': f'Now following {target_user.username}',
            'follow': FollowSerializer(follow, context={'request': request}).data
        }, status=status.HTTP_201_CREATED)


class UnfollowUserView(APIView):
    """Ne plus suivre un utilisateur"""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user_id = request.data.get('user_id')
        username = request.data.get('username')
        
        if not user_id and not username:
            return Response(
                {'error': 'user_id or username required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            if user_id:
                target_user = User.objects.get(id=user_id)
            else:
                target_user = User.objects.get(username=username)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        deleted, _ = Follow.objects.filter(
            follower=request.user,
            following=target_user
        ).delete()
        
        if not deleted:
            return Response(
                {'error': 'Not following this user'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        return Response({
            'success': True,
            'message': f'Unfollowed {target_user.username}'
        })


class FollowersListView(APIView):
    """Liste des followers d'un utilisateur"""
    permission_classes = [IsAuthenticated]

    def get(self, request, user_id=None):
        if user_id:
            user = get_object_or_404(User, id=user_id)
        else:
            user = request.user
        
        followers = Follow.objects.filter(following=user).select_related('follower__profile')
        
        users = [f.follower for f in followers]
        return Response({
            'count': len(users),
            'followers': UserMiniSerializer(users, many=True, context={'request': request}).data
        })


class FollowingListView(APIView):
    """Liste des utilisateurs suivis"""
    permission_classes = [IsAuthenticated]

    def get(self, request, user_id=None):
        if user_id:
            user = get_object_or_404(User, id=user_id)
        else:
            user = request.user
        
        following = Follow.objects.filter(follower=user).select_related('following__profile')
        
        users = [f.following for f in following]
        return Response({
            'count': len(users),
            'following': UserMiniSerializer(users, many=True, context={'request': request}).data
        })


# ===================== POST VIEWS =====================

class PublishPostView(APIView):
    """Publier un nouveau post"""
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        content = request.data.get('content', '')
        visibility = request.data.get('visibility', 'followers')
        tags = request.data.get('tags', [])
        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')
        location_name = request.data.get('location_name', '')
        
        # Parser les tags si c'est une string JSON
        if isinstance(tags, str):
            import json
            try:
                tags = json.loads(tags)
            except:
                tags = [t.strip() for t in tags.split(',') if t.strip()]
        
        # Créer le post
        post = Post.objects.create(
            author=request.user,
            content=content,
            visibility=visibility,
            tags=tags,
            latitude=float(latitude) if latitude else None,
            longitude=float(longitude) if longitude else None,
            location_name=location_name
        )
        
        # Traiter les médias
        media_files = request.FILES.getlist('media')
        if not media_files:
            # Support pour media[0], media[1], etc.
            i = 0
            while f'media[{i}]' in request.FILES:
                media_files.append(request.FILES[f'media[{i}]'])
                i += 1
        
        for i, media_file in enumerate(media_files):
            # Déterminer le type de média
            mime_type, _ = mimetypes.guess_type(media_file.name)
            if mime_type:
                if mime_type.startswith('image'):
                    media_type = 'image'
                elif mime_type.startswith('video'):
                    media_type = 'video'
                else:
                    continue  # Type non supporté
            else:
                continue
            
            # Créer le PostMedia
            post_media = PostMedia.objects.create(
                post=post,
                original_file=media_file,
                media_type=media_type,
                order=i
            )
            
            # Lancer le traitement en arrière-plan (compression/HLS)
            # Note: En production, utiliser Celery ou Django-Q
            try:
                process_post_media(post_media)
            except Exception as e:
                print(f"Media processing error: {e}")
        
        return Response({
            'success': True,
            'message': 'Post published',
            'post': PostSerializer(post, context={'request': request}).data
        }, status=status.HTTP_201_CREATED)


class GetFeedView(APIView):
    """Récupérer le feed personnalisé"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        limit = int(request.query_params.get('limit', 50))
        offset = int(request.query_params.get('offset', 0))
        feed_type = request.query_params.get('type', 'main')  # main, discover, video
        
        algorithm = LocalFeedAlgorithm(request.user)
        
        if feed_type == 'discover':
            posts = algorithm.get_discover_feed(limit=limit, offset=offset)
        elif feed_type == 'video':
            posts = algorithm.get_video_feed(limit=limit, offset=offset)
        else:
            posts = algorithm.get_feed(limit=limit, offset=offset)
        
        return Response({
            'count': len(posts),
            'offset': offset,
            'posts': FeedPostSerializer(posts, many=True, context={'request': request}).data
        })


class GetPostView(APIView):
    """Récupérer un post spécifique"""
    permission_classes = [AllowAny]

    def get(self, request, post_uuid):
        post = get_object_or_404(Post, uuid=post_uuid, is_deleted=False)
        
        # Vérifier la visibilité
        if post.visibility == 'private' and post.author != request.user:
            return Response(
                {'error': 'Post not accessible'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        if post.visibility == 'followers':
            if not request.user.is_authenticated:
                return Response(
                    {'error': 'Authentication required'},
                    status=status.HTTP_401_UNAUTHORIZED
                )
            is_follower = Follow.objects.filter(
                follower=request.user, following=post.author
            ).exists()
            if not is_follower and post.author != request.user:
                return Response(
                    {'error': 'Post not accessible'},
                    status=status.HTTP_403_FORBIDDEN
                )
        
        # Incrémenter les vues
        post.increment_views()
        
        return Response(PostSerializer(post, context={'request': request}).data)


class DeletePostView(APIView):
    """Supprimer un post"""
    permission_classes = [IsAuthenticated]

    def delete(self, request, post_uuid):
        post = get_object_or_404(Post, uuid=post_uuid, author=request.user)
        
        # Get the post folder path before deleting
        post_folder = os.path.join(
            settings.MEDIA_ROOT,
            'posts',
            str(post.author.id),
            str(post.uuid)
        )
        
        # Hard delete the post and related data (cascades to media)
        post.delete()
        
        # Delete the entire post folder
        if os.path.exists(post_folder) and os.path.isdir(post_folder):
            try:
                shutil.rmtree(post_folder)
                print(f"Deleted post folder: {post_folder}")
            except Exception as e:
                print(f"Error deleting post folder: {e}")
        
        return Response({'success': True, 'message': 'Post deleted'})


class UserPostsView(APIView):
    """Récupérer les posts d'un utilisateur"""
    permission_classes = [AllowAny]

    def get(self, request, user_id):
        user = get_object_or_404(User, id=user_id)
        limit = int(request.query_params.get('limit', 30))
        offset = int(request.query_params.get('offset', 0))
        
        posts = Post.objects.filter(author=user, is_deleted=False)
        
        # Filtrer selon la visibilité
        if request.user.is_authenticated:
            if request.user == user:
                pass  # Voir tous ses posts
            elif Follow.objects.filter(follower=request.user, following=user).exists():
                posts = posts.filter(visibility__in=['public', 'followers'])
            else:
                posts = posts.filter(visibility='public')
        else:
            posts = posts.filter(visibility='public')
        
        posts = posts.select_related('author__profile').prefetch_related('media')[offset:offset+limit]
        
        return Response({
            'count': len(posts),
            'posts': PostSerializer(posts, many=True, context={'request': request}).data
        })


# ===================== LIKE VIEWS =====================

class LikePostView(APIView):
    """Liker un post"""
    permission_classes = [IsAuthenticated]

    def post(self, request, post_uuid):
        post = get_object_or_404(Post, uuid=post_uuid, is_deleted=False)
        
        like, created = PostLike.objects.get_or_create(
            user=request.user,
            post=post
        )
        
        if created:
            post.likes_count += 1
            post.save(update_fields=['likes_count'])
        
        return Response({
            'success': True,
            'liked': True,
            'likes_count': post.likes_count
        })


class UnlikePostView(APIView):
    """Retirer un like"""
    permission_classes = [IsAuthenticated]

    def post(self, request, post_uuid):
        post = get_object_or_404(Post, uuid=post_uuid, is_deleted=False)
        
        deleted, _ = PostLike.objects.filter(
            user=request.user,
            post=post
        ).delete()
        
        if deleted:
            post.likes_count = max(0, post.likes_count - 1)
            post.save(update_fields=['likes_count'])
        
        return Response({
            'success': True,
            'liked': False,
            'likes_count': post.likes_count
        })


class PostLikersView(APIView):
    """Liste des utilisateurs qui ont liké un post"""
    permission_classes = [AllowAny]

    def get(self, request, post_uuid):
        post = get_object_or_404(Post, uuid=post_uuid, is_deleted=False)
        likes = PostLike.objects.filter(post=post).select_related('user__profile')
        
        users = [like.user for like in likes]
        return Response({
            'count': len(users),
            'users': UserMiniSerializer(users, many=True, context={'request': request}).data
        })


# ===================== COMMENT VIEWS =====================

class AddCommentView(APIView):
    """Ajouter un commentaire"""
    permission_classes = [IsAuthenticated]

    def post(self, request, post_uuid):
        post = get_object_or_404(Post, uuid=post_uuid, is_deleted=False)
        content = request.data.get('content', '').strip()
        parent_uuid = request.data.get('parent_uuid')
        
        if not content:
            return Response(
                {'error': 'Content is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        parent = None
        if parent_uuid:
            parent = get_object_or_404(PostComment, uuid=parent_uuid, is_deleted=False)
        
        comment = PostComment.objects.create(
            user=request.user,
            post=post,
            content=content,
            parent=parent
        )
        
        post.comments_count += 1
        post.save(update_fields=['comments_count'])
        
        return Response({
            'success': True,
            'comment': PostCommentSerializer(comment, context={'request': request}).data
        }, status=status.HTTP_201_CREATED)


class GetCommentsView(APIView):
    """Récupérer les commentaires d'un post"""
    permission_classes = [AllowAny]

    def get(self, request, post_uuid):
        post = get_object_or_404(Post, uuid=post_uuid, is_deleted=False)
        limit = int(request.query_params.get('limit', 50))
        offset = int(request.query_params.get('offset', 0))
        
        comments = PostComment.objects.filter(
            post=post,
            is_deleted=False,
            parent__isnull=True  # Seulement les commentaires racines
        ).select_related('user__profile')[offset:offset+limit]
        
        return Response({
            'count': post.comments_count,
            'comments': PostCommentSerializer(comments, many=True, context={'request': request}).data
        })


class GetCommentRepliesView(APIView):
    """Récupérer les réponses à un commentaire"""
    permission_classes = [AllowAny]

    def get(self, request, comment_uuid):
        comment = get_object_or_404(PostComment, uuid=comment_uuid, is_deleted=False)
        
        replies = comment.replies.filter(is_deleted=False).select_related('user__profile')
        
        return Response({
            'count': replies.count(),
            'replies': PostCommentSerializer(replies, many=True, context={'request': request}).data
        })


class DeleteCommentView(APIView):
    """Supprimer un commentaire"""
    permission_classes = [IsAuthenticated]

    def delete(self, request, comment_uuid):
        comment = get_object_or_404(
            PostComment,
            uuid=comment_uuid,
            user=request.user,
            is_deleted=False
        )
        
        comment.is_deleted = True
        comment.save(update_fields=['is_deleted'])
        
        comment.post.comments_count = max(0, comment.post.comments_count - 1)
        comment.post.save(update_fields=['comments_count'])
        
        return Response({'success': True})


class LikeCommentView(APIView):
    """Liker un commentaire"""
    permission_classes = [IsAuthenticated]

    def post(self, request, comment_uuid):
        comment = get_object_or_404(PostComment, uuid=comment_uuid, is_deleted=False)
        
        like, created = CommentLike.objects.get_or_create(
            user=request.user,
            comment=comment
        )
        
        if created:
            comment.likes_count += 1
            comment.save(update_fields=['likes_count'])
        
        return Response({
            'success': True,
            'liked': True,
            'likes_count': comment.likes_count
        })


# ===================== BOOKMARK VIEWS =====================

class BookmarkPostView(APIView):
    """Sauvegarder un post"""
    permission_classes = [IsAuthenticated]

    def post(self, request, post_uuid):
        post = get_object_or_404(Post, uuid=post_uuid, is_deleted=False)
        
        bookmark, created = Bookmark.objects.get_or_create(
            user=request.user,
            post=post
        )
        
        return Response({
            'success': True,
            'bookmarked': True
        })


class UnbookmarkPostView(APIView):
    """Retirer un post des favoris"""
    permission_classes = [IsAuthenticated]

    def post(self, request, post_uuid):
        post = get_object_or_404(Post, uuid=post_uuid, is_deleted=False)
        
        Bookmark.objects.filter(user=request.user, post=post).delete()
        
        return Response({
            'success': True,
            'bookmarked': False
        })


class BookmarksListView(APIView):
    """Liste des posts sauvegardés"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        limit = int(request.query_params.get('limit', 50))
        offset = int(request.query_params.get('offset', 0))
        
        bookmarks = Bookmark.objects.filter(
            user=request.user
        ).select_related('post__author__profile').prefetch_related('post__media')[offset:offset+limit]
        
        posts = [b.post for b in bookmarks if not b.post.is_deleted]
        
        return Response({
            'count': len(posts),
            'posts': PostSerializer(posts, many=True, context={'request': request}).data
        })


# ===================== STORY VIEWS =====================

class CreateStoryView(APIView):
    """Créer une story"""
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        media_file = request.FILES.get('media')
        duration = float(request.data.get('duration', 5.0))
        
        if not media_file:
            return Response(
                {'error': 'Media file required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        mime_type, _ = mimetypes.guess_type(media_file.name)
        if mime_type and mime_type.startswith('image'):
            media_type = 'image'
        elif mime_type and mime_type.startswith('video'):
            media_type = 'video'
        else:
            return Response(
                {'error': 'Invalid media type'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        story = Story.objects.create(
            author=request.user,
            media=media_file,
            media_type=media_type,
            duration=min(duration, 60.0)  # Max 60 secondes
        )
        
        # Traitement HLS pour les vidéos en arrière-plan
        if media_type == 'video':
            from threading import Thread
            from .media_processing import process_story_media
            Thread(target=process_story_media, args=(story,), daemon=True).start()
        
        return Response({
            'success': True,
            'story': StorySerializer(story, context={'request': request}).data
        }, status=status.HTTP_201_CREATED)


class GetStoriesView(APIView):
    """Récupérer les stories des utilisateurs suivis"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        now = timezone.now()
        
        # Récupérer les IDs des utilisateurs suivis + amis
        from friends.models import Friendship
        
        following_ids = set(
            Follow.objects.filter(follower=request.user)
            .values_list('following_id', flat=True)
        )
        
        friendships = Friendship.objects.filter(
            Q(from_user=request.user) | Q(to_user=request.user),
            status='accepted'
        )
        friends_ids = set()
        for f in friendships:
            friends_ids.add(f.from_user_id if f.from_user_id != request.user.id else f.to_user_id)
        
        # Inclure ses propres stories
        user_ids = following_ids | friends_ids | {request.user.id}
        
        # Stories non expirées
        stories = Story.objects.filter(
            author_id__in=user_ids,
            expires_at__gt=now
        ).select_related('author__profile').order_by('author', '-created_at')
        
        # Grouper par utilisateur
        user_stories = {}
        for story in stories:
            if story.author_id not in user_stories:
                user_stories[story.author_id] = {
                    'user': story.author,
                    'stories': [],
                    'has_unviewed': False
                }
            user_stories[story.author_id]['stories'].append(story)
            
            # Vérifier si non vue
            if not StoryView.objects.filter(user=request.user, story=story).exists():
                user_stories[story.author_id]['has_unviewed'] = True
        
        # Trier: non vues en premier, puis les propres stories
        result = []
        for data in user_stories.values():
            result.append({
                'user': UserMiniSerializer(data['user'], context={'request': request}).data,
                'stories': StorySerializer(data['stories'], many=True, context={'request': request}).data,
                'has_unviewed': data['has_unviewed']
            })
        
        # Trier: non vues en premier
        result.sort(key=lambda x: (not x['has_unviewed'], x['user']['id'] != request.user.id))
        
        return Response({'stories': result})


class ViewStoryView(APIView):
    """Marquer une story comme vue"""
    permission_classes = [IsAuthenticated]

    def post(self, request, story_uuid):
        story = get_object_or_404(Story, uuid=story_uuid)
        
        if story.is_expired:
            return Response(
                {'error': 'Story expired'},
                status=status.HTTP_410_GONE
            )
        
        view, created = StoryView.objects.get_or_create(
            user=request.user,
            story=story
        )
        
        if created:
            story.views_count += 1
            story.save(update_fields=['views_count'])
        
        return Response({'success': True, 'views_count': story.views_count})


class DeleteStoryView(APIView):
    """Supprimer une story"""
    permission_classes = [IsAuthenticated]

    def delete(self, request, story_uuid):
        story = get_object_or_404(Story, uuid=story_uuid, author=request.user)
        
        # Delete media file from disk
        if story.media:
            try:
                if os.path.exists(story.media.path):
                    os.remove(story.media.path)
            except Exception as e:
                print(f"Error deleting story media file: {e}")
        
        # Delete HLS files if exists
        if story.hls_playlist:
            try:
                hls_path = story.hls_playlist.path
                if os.path.exists(hls_path):
                    os.remove(hls_path)
                # Delete HLS directory
                hls_dir = os.path.dirname(hls_path)
                if os.path.exists(hls_dir) and os.path.isdir(hls_dir):
                    shutil.rmtree(hls_dir)
            except Exception as e:
                print(f"Error deleting story HLS files: {e}")
        
        story.delete()
        
        return Response({'success': True})


# ===================== PROFILE VIEWS =====================

class UserProfileView(APIView):
    """Profil social d'un utilisateur"""
    permission_classes = [AllowAny]

    def get(self, request, user_id=None, username=None):
        if user_id:
            user = get_object_or_404(User, id=user_id)
        elif username:
            user = get_object_or_404(User, username=username)
        elif request.user.is_authenticated:
            user = request.user
        else:
            return Response(
                {'error': 'User identifier required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        return Response(UserProfileSerializer(user, context={'request': request}).data)


class SearchUsersView(APIView):
    """Rechercher des utilisateurs"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        query = request.query_params.get('q', '').strip()
        
        if len(query) < 2:
            return Response(
                {'error': 'Query must be at least 2 characters'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        users = User.objects.filter(
            Q(username__icontains=query) |
            Q(profile__bio__icontains=query)
        ).exclude(id=request.user.id).select_related('profile')[:20]
        
        return Response({
            'count': len(users),
            'users': UserMiniSerializer(users, many=True, context={'request': request}).data
        })
