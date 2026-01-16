from django.urls import path
from .views import (
    # Follow
    FollowUserView, UnfollowUserView, FollowersListView, FollowingListView,
    # Posts
    PublishPostView, GetFeedView, GetPostView, DeletePostView, UserPostsView,
    # Likes
    LikePostView, UnlikePostView, PostLikersView,
    # Comments
    AddCommentView, GetCommentsView, GetCommentRepliesView, DeleteCommentView, LikeCommentView,
    # Bookmarks
    BookmarkPostView, UnbookmarkPostView, BookmarksListView,
    # Stories
    CreateStoryView, GetStoriesView, ViewStoryView, DeleteStoryView,
    # Profile
    UserProfileView, SearchUsersView,
)

app_name = 'social'

urlpatterns = [
    # ========== FOLLOW ==========
    path('follow/', FollowUserView.as_view(), name='follow'),
    path('unfollow/', UnfollowUserView.as_view(), name='unfollow'),
    path('followers/', FollowersListView.as_view(), name='my_followers'),
    path('followers/<int:user_id>/', FollowersListView.as_view(), name='user_followers'),
    path('following/', FollowingListView.as_view(), name='my_following'),
    path('following/<int:user_id>/', FollowingListView.as_view(), name='user_following'),
    
    # ========== POSTS ==========
    path('publish/', PublishPostView.as_view(), name='publish'),
    path('feed/', GetFeedView.as_view(), name='feed'),
    path('posts/<uuid:post_uuid>/', GetPostView.as_view(), name='post_detail'),
    path('posts/<uuid:post_uuid>/delete/', DeletePostView.as_view(), name='post_delete'),
    path('users/<int:user_id>/posts/', UserPostsView.as_view(), name='user_posts'),
    
    # ========== LIKES ==========
    path('posts/<uuid:post_uuid>/like/', LikePostView.as_view(), name='like_post'),
    path('posts/<uuid:post_uuid>/unlike/', UnlikePostView.as_view(), name='unlike_post'),
    path('posts/<uuid:post_uuid>/likers/', PostLikersView.as_view(), name='post_likers'),
    
    # ========== COMMENTS ==========
    path('posts/<uuid:post_uuid>/comments/', GetCommentsView.as_view(), name='post_comments'),
    path('posts/<uuid:post_uuid>/comments/add/', AddCommentView.as_view(), name='add_comment'),
    path('comments/<uuid:comment_uuid>/replies/', GetCommentRepliesView.as_view(), name='comment_replies'),
    path('comments/<uuid:comment_uuid>/delete/', DeleteCommentView.as_view(), name='delete_comment'),
    path('comments/<uuid:comment_uuid>/like/', LikeCommentView.as_view(), name='like_comment'),
    
    # ========== BOOKMARKS ==========
    path('bookmarks/', BookmarksListView.as_view(), name='bookmarks'),
    path('posts/<uuid:post_uuid>/bookmark/', BookmarkPostView.as_view(), name='bookmark_post'),
    path('posts/<uuid:post_uuid>/unbookmark/', UnbookmarkPostView.as_view(), name='unbookmark_post'),
    
    # ========== STORIES ==========
    path('stories/', GetStoriesView.as_view(), name='stories'),
    path('stories/create/', CreateStoryView.as_view(), name='create_story'),
    path('stories/<uuid:story_uuid>/view/', ViewStoryView.as_view(), name='view_story'),
    path('stories/<uuid:story_uuid>/delete/', DeleteStoryView.as_view(), name='delete_story'),
    
    # ========== PROFILE ==========
    path('profile/', UserProfileView.as_view(), name='my_profile'),
    path('profile/<int:user_id>/', UserProfileView.as_view(), name='user_profile'),
    path('profile/username/<str:username>/', UserProfileView.as_view(), name='user_profile_by_username'),
    path('search/', SearchUsersView.as_view(), name='search_users'),
]
