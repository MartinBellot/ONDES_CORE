import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/social_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/logger.dart';
import 'base_handler.dart';

/// Handler for Ondes.Social namespace
/// Manages social features: following, posts, feed, stories
class SocialHandler extends BaseHandler {
  final SocialService _socialService = SocialService();
  final ImagePicker _imagePicker = ImagePicker();

  SocialHandler(BuildContext context) : super(context);

  @override
  void registerHandlers() {
    // Follow
    _registerFollow();
    _registerUnfollow();
    _registerGetFollowers();
    _registerGetFollowing();

    // Posts
    _registerPublish(); // requires social
    _registerGetFeed(); // requires social
    _registerGetPost();
    _registerDeletePost();
    _registerGetUserPosts();

    // Likes
    _registerLikePost();
    _registerUnlikePost();
    _registerGetPostLikers();

    // Comments
    _registerAddComment();
    _registerGetComments();
    _registerGetCommentReplies();
    _registerDeleteComment();
    _registerLikeComment();

    // Bookmarks
    _registerBookmarkPost();
    _registerUnbookmarkPost();
    _registerGetBookmarks();

    // Stories
    _registerCreateStory();
    _registerGetStories();
    _registerViewStory();
    _registerDeleteStory();

    // Profile
    _registerGetProfile();
    _registerSearchUsers();

    // Media picker
    _registerPickMedia();
  }

  // ==================== FOLLOW ====================

  /// Ondes.Social.follow(options)
  void _registerFollow() {
    addHandler('Ondes.Social.follow', (args) async {
      await requirePermission('social');
      _requireAuth();

      final options = args.isNotEmpty ? args[0] as Map<String, dynamic> : {};
      final username = options['username'] as String?;
      final userId = options['userId'] as int?;

      if (username == null && userId == null) {
        throw Exception('username or userId required');
      }

      final result = await _socialService.follow(
        username: username,
        userId: userId,
      );

      return result;
    });
  }

  /// Ondes.Social.unfollow(options)
  void _registerUnfollow() {
    addHandler('Ondes.Social.unfollow', (args) async {
      await requirePermission('social');
      _requireAuth();

      final options = args.isNotEmpty ? args[0] as Map<String, dynamic> : {};
      final username = options['username'] as String?;
      final userId = options['userId'] as int?;

      if (username == null && userId == null) {
        throw Exception('username or userId required');
      }

      final result = await _socialService.unfollow(
        username: username,
        userId: userId,
      );

      return result;
    });
  }

  /// Ondes.Social.getFollowers(userId?)
  void _registerGetFollowers() {
    addHandler('Ondes.Social.getFollowers', (args) async {
      _requireAuth();

      int? userId;
      if (args.isNotEmpty && args[0] != null) {
        userId = args[0] is int
            ? args[0] as int
            : int.parse(args[0].toString());
      }
      final followers = await _socialService.getFollowers(userId: userId);

      return followers.map((f) => _userToMap(f)).toList();
    });
  }

  /// Ondes.Social.getFollowing(userId?)
  void _registerGetFollowing() {
    addHandler('Ondes.Social.getFollowing', (args) async {
      _requireAuth();

      int? userId;
      if (args.isNotEmpty && args[0] != null) {
        userId = args[0] is int
            ? args[0] as int
            : int.parse(args[0].toString());
      }
      final following = await _socialService.getFollowing(userId: userId);

      return following.map((f) => _userToMap(f)).toList();
    });
  }

  // ==================== POSTS ====================

  /// Ondes.Social.publish(options)
  void _registerPublish() {
    addHandler('Ondes.Social.publish', (args) async {
      await requirePermission('social');
      _requireAuth();

      final options = args.isNotEmpty ? args[0] as Map<String, dynamic> : {};

      final publishOptions = PublishOptions(
        content: options['content'] as String? ?? '',
        mediaPaths:
            (options['media'] as List?)?.map((e) => e.toString()).toList() ??
            [],
        visibility: options['visibility'] as String? ?? 'followers',
        tags:
            (options['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        latitude: options['latitude'] as double?,
        longitude: options['longitude'] as double?,
        locationName: options['locationName'] as String?,
      );

      final post = await _socialService.publish(publishOptions);
      return _postToMap(post);
    });
  }

  /// Ondes.Social.getFeed(options?)
  void _registerGetFeed() {
    addHandler('Ondes.Social.getFeed', (args) async {
      await requirePermission('social');
      _requireAuth();

      final options = args.isNotEmpty ? args[0] as Map<String, dynamic> : {};
      final limit = options['limit'] as int? ?? 50;
      final offset = options['offset'] as int? ?? 0;
      final type = options['type'] as String? ?? 'main';

      final posts = await _socialService.getFeed(
        limit: limit,
        offset: offset,
        type: type,
      );

      return posts.map((p) => _postToMap(p)).toList();
    });
  }

  /// Ondes.Social.getPost(postUuid)
  void _registerGetPost() {
    addHandler('Ondes.Social.getPost', (args) async {
      if (args.isEmpty) {
        throw Exception('postUuid required');
      }

      final postUuid = args[0] as String;
      final post = await _socialService.getPost(postUuid);

      return _postToMap(post);
    });
  }

  /// Ondes.Social.deletePost(postUuid)
  void _registerDeletePost() {
    addHandler('Ondes.Social.deletePost', (args) async {
      _requireAuth();

      if (args.isEmpty) {
        throw Exception('postUuid required');
      }

      final postUuid = args[0] as String;
      await _socialService.deletePost(postUuid);

      return {'success': true};
    });
  }

  /// Ondes.Social.getUserPosts(userId, options?)
  void _registerGetUserPosts() {
    addHandler('Ondes.Social.getUserPosts', (args) async {
      if (args.isEmpty || args[0] == null) {
        throw Exception('userId required');
      }

      final userId = args[0] is int
          ? args[0] as int
          : int.parse(args[0].toString());
      final options = args.length > 1 && args[1] != null
          ? args[1] as Map<String, dynamic>
          : {};
      final limit = options['limit'] as int? ?? 30;
      final offset = options['offset'] as int? ?? 0;

      final posts = await _socialService.getUserPosts(
        userId,
        limit: limit,
        offset: offset,
      );

      return posts.map((p) => _postToMap(p)).toList();
    });
  }

  // ==================== LIKES ====================

  /// Ondes.Social.likePost(postUuid)
  void _registerLikePost() {
    addHandler('Ondes.Social.likePost', (args) async {
      _requireAuth();

      if (args.isEmpty) {
        throw Exception('postUuid required');
      }

      final postUuid = args[0] as String;
      return await _socialService.likePost(postUuid);
    });
  }

  /// Ondes.Social.unlikePost(postUuid)
  void _registerUnlikePost() {
    addHandler('Ondes.Social.unlikePost', (args) async {
      _requireAuth();

      if (args.isEmpty) {
        throw Exception('postUuid required');
      }

      final postUuid = args[0] as String;
      return await _socialService.unlikePost(postUuid);
    });
  }

  /// Ondes.Social.getPostLikers(postUuid)
  void _registerGetPostLikers() {
    addHandler('Ondes.Social.getPostLikers', (args) async {
      if (args.isEmpty) {
        throw Exception('postUuid required');
      }

      final postUuid = args[0] as String;
      final users = await _socialService.getPostLikers(postUuid);

      return users.map((u) => _userToMap(u)).toList();
    });
  }

  // ==================== COMMENTS ====================

  /// Ondes.Social.addComment(postUuid, content, parentUuid?)
  void _registerAddComment() {
    addHandler('Ondes.Social.addComment', (args) async {
      _requireAuth();

      if (args.length < 2) {
        throw Exception('postUuid and content required');
      }

      final postUuid = args[0] as String;
      final content = args[1] as String;
      final parentUuid = args.length > 2 ? args[2] as String? : null;

      final comment = await _socialService.addComment(
        postUuid,
        content,
        parentUuid: parentUuid,
      );

      return _commentToMap(comment);
    });
  }

  /// Ondes.Social.getComments(postUuid, options?)
  void _registerGetComments() {
    addHandler('Ondes.Social.getComments', (args) async {
      if (args.isEmpty) {
        throw Exception('postUuid required');
      }

      final postUuid = args[0] as String;
      final options = args.length > 1 ? args[1] as Map<String, dynamic> : {};
      final limit = options['limit'] as int? ?? 50;
      final offset = options['offset'] as int? ?? 0;

      final comments = await _socialService.getComments(
        postUuid,
        limit: limit,
        offset: offset,
      );

      return comments.map((c) => _commentToMap(c)).toList();
    });
  }

  /// Ondes.Social.getCommentReplies(commentUuid)
  void _registerGetCommentReplies() {
    addHandler('Ondes.Social.getCommentReplies', (args) async {
      if (args.isEmpty) {
        throw Exception('commentUuid required');
      }

      final commentUuid = args[0] as String;
      final replies = await _socialService.getCommentReplies(commentUuid);

      return replies.map((r) => _commentToMap(r)).toList();
    });
  }

  /// Ondes.Social.deleteComment(commentUuid)
  void _registerDeleteComment() {
    addHandler('Ondes.Social.deleteComment', (args) async {
      _requireAuth();

      if (args.isEmpty) {
        throw Exception('commentUuid required');
      }

      final commentUuid = args[0] as String;
      await _socialService.deleteComment(commentUuid);

      return {'success': true};
    });
  }

  /// Ondes.Social.likeComment(commentUuid)
  void _registerLikeComment() {
    addHandler('Ondes.Social.likeComment', (args) async {
      _requireAuth();

      if (args.isEmpty) {
        throw Exception('commentUuid required');
      }

      final commentUuid = args[0] as String;
      return await _socialService.likeComment(commentUuid);
    });
  }

  // ==================== BOOKMARKS ====================

  /// Ondes.Social.bookmarkPost(postUuid)
  void _registerBookmarkPost() {
    addHandler('Ondes.Social.bookmarkPost', (args) async {
      _requireAuth();

      if (args.isEmpty) {
        throw Exception('postUuid required');
      }

      final postUuid = args[0] as String;
      await _socialService.bookmarkPost(postUuid);

      return {'success': true, 'bookmarked': true};
    });
  }

  /// Ondes.Social.unbookmarkPost(postUuid)
  void _registerUnbookmarkPost() {
    addHandler('Ondes.Social.unbookmarkPost', (args) async {
      _requireAuth();

      if (args.isEmpty) {
        throw Exception('postUuid required');
      }

      final postUuid = args[0] as String;
      await _socialService.unbookmarkPost(postUuid);

      return {'success': true, 'bookmarked': false};
    });
  }

  /// Ondes.Social.getBookmarks(options?)
  void _registerGetBookmarks() {
    addHandler('Ondes.Social.getBookmarks', (args) async {
      _requireAuth();

      final options = args.isNotEmpty ? args[0] as Map<String, dynamic> : {};
      final limit = options['limit'] as int? ?? 50;
      final offset = options['offset'] as int? ?? 0;

      final posts = await _socialService.getBookmarks(
        limit: limit,
        offset: offset,
      );

      return posts.map((p) => _postToMap(p)).toList();
    });
  }

  // ==================== STORIES ====================

  /// Ondes.Social.createStory(mediaPath, duration?)
  void _registerCreateStory() {
    addHandler('Ondes.Social.createStory', (args) async {
      _requireAuth();

      if (args.isEmpty) {
        throw Exception('mediaPath required');
      }

      final mediaPath = args[0] as String;
      final duration = args.length > 1 ? (args[1] as num).toDouble() : 5.0;

      final story = await _socialService.createStory(
        mediaPath,
        duration: duration,
      );

      return _storyToMap(story);
    });
  }

  /// Ondes.Social.getStories()
  void _registerGetStories() {
    addHandler('Ondes.Social.getStories', (args) async {
      _requireAuth();

      final stories = await _socialService.getStories();

      return stories
          .map(
            (us) => {
              'user': _userToMap(us.user),
              'stories': us.stories.map((s) => _storyToMap(s)).toList(),
              'hasUnviewed': us.hasUnviewed,
            },
          )
          .toList();
    });
  }

  /// Ondes.Social.viewStory(storyUuid)
  void _registerViewStory() {
    addHandler('Ondes.Social.viewStory', (args) async {
      _requireAuth();

      if (args.isEmpty) {
        throw Exception('storyUuid required');
      }

      final storyUuid = args[0] as String;
      final viewsCount = await _socialService.viewStory(storyUuid);

      return {'success': true, 'viewsCount': viewsCount};
    });
  }

  /// Ondes.Social.deleteStory(storyUuid)
  void _registerDeleteStory() {
    addHandler('Ondes.Social.deleteStory', (args) async {
      _requireAuth();

      if (args.isEmpty) {
        throw Exception('storyUuid required');
      }

      final storyUuid = args[0] as String;
      await _socialService.deleteStory(storyUuid);

      return {'success': true};
    });
  }

  // ==================== PROFILE ====================

  /// Ondes.Social.getProfile(options?)
  void _registerGetProfile() {
    addHandler('Ondes.Social.getProfile', (args) async {
      final options = args.isNotEmpty ? args[0] as Map<String, dynamic> : {};
      final userId = options['userId'] as int?;
      final username = options['username'] as String?;

      return await _socialService.getProfile(
        userId: userId,
        username: username,
      );
    });
  }

  /// Ondes.Social.searchUsers(query)
  void _registerSearchUsers() {
    addHandler('Ondes.Social.searchUsers', (args) async {
      _requireAuth();

      if (args.isEmpty) {
        throw Exception('query required');
      }

      final query = args[0] as String;
      final users = await _socialService.searchUsers(query);

      return users.map((u) => _userToMap(u)).toList();
    });
  }

  // ==================== MEDIA PICKER ====================

  /// Ondes.Social.pickMedia(options?) - Ouvre le sélecteur de média natif
  void _registerPickMedia() {
    addHandler('Ondes.Social.pickMedia', (args) async {
      final options = args.isNotEmpty && args[0] != null
          ? args[0] as Map<String, dynamic>
          : {};
      final allowVideo = options['allowVideo'] as bool? ?? false;
      final videoOnly = options['videoOnly'] as bool? ?? false;
      final multiple = options['multiple'] as bool? ?? false;
      final maxFiles = options['maxFiles'] as int? ?? 10;

      List<Map<String, dynamic>> mediaList = [];

      Future<Map<String, dynamic>> buildMediaItem(
        XFile file,
        String type,
      ) async {
        String? previewUrl;

        // Generate base64 preview for images (for WebView display)
        if (type == 'image') {
          try {
            final bytes = await file.readAsBytes();
            final base64 = base64Encode(bytes);
            final mimeType = file.path.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg';
            previewUrl = 'data:$mimeType;base64,$base64';
          } catch (e) {
            AppLogger.error('SocialHandler', 'Error creating preview', e);
          }
        }

        return {
          'path': file.path,
          'type': type,
          'name': file.name,
          'previewUrl': previewUrl,
        };
      }

      if (videoOnly) {
        // Video only
        final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (video != null) {
          mediaList.add(await buildMediaItem(video, 'video'));
        }
      } else if (multiple || allowVideo) {
        // Multiple media (images and/or videos)
        final files = await _imagePicker.pickMultipleMedia(limit: maxFiles);
        for (final file in files) {
          final isVideo =
              file.path.toLowerCase().endsWith('.mp4') ||
              file.path.toLowerCase().endsWith('.mov') ||
              file.path.toLowerCase().endsWith('.avi') ||
              file.path.toLowerCase().endsWith('.mkv');
          mediaList.add(
            await buildMediaItem(file, isVideo ? 'video' : 'image'),
          );
        }
      } else {
        // Single image
        final image = await _imagePicker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          mediaList.add(await buildMediaItem(image, 'image'));
        }
      }

      // Return array directly for easier JS handling
      return mediaList;
    });
  }

  // ==================== HELPERS ====================

  void _requireAuth() {
    if (!AuthService().isAuthenticated) {
      throw Exception('User not authenticated');
    }
  }

  Map<String, dynamic> _userToMap(SocialUser user) {
    return {
      'id': user.id,
      'username': user.username,
      'avatar': user.avatar,
      'profile_picture': user.avatar,
      'bio': user.bio,
      'followers_count': user.followersCount,
      'following_count': user.followingCount,
      'is_following': user.isFollowing,
    };
  }

  Map<String, dynamic> _postToMap(Post post) {
    return {
      'uuid': post.uuid,
      'author': _userToMap(post.author),
      'content': post.content,
      'visibility': post.visibility,
      'tags': post.tags,
      'media': post.media.map((m) => _mediaToMap(m)).toList(),
      'likes_count': post.likesCount,
      'comments_count': post.commentsCount,
      'shares_count': post.sharesCount,
      'views_count': post.viewsCount,
      'user_has_liked': post.isLiked,
      'user_has_bookmarked': post.isBookmarked,
      'comments_preview': post.commentsPreview
          .map((c) => _commentToMap(c))
          .toList(),
      'latitude': post.latitude,
      'longitude': post.longitude,
      'location_name': post.locationName,
      'created_at': post.createdAt.toIso8601String(),
      'relevance_score': post.relevanceScore,
    };
  }

  Map<String, dynamic> _mediaToMap(PostMedia media) {
    return {
      'uuid': media.uuid,
      'media_type': media.mediaType,
      'display_url': media.displayUrl,
      'thumbnail_url': media.thumbnailUrl,
      'hls_url': media.hlsUrl,
      'width': media.width,
      'height': media.height,
      'duration': media.duration,
      'processing_status': media.processingStatus,
      'hls_ready': media.hlsReady,
      'order': media.order,
    };
  }

  Map<String, dynamic> _commentToMap(PostComment comment) {
    return {
      'uuid': comment.uuid,
      'user': _userToMap(comment.user),
      'content': comment.content,
      'likes_count': comment.likesCount,
      'is_liked': comment.isLiked,
      'replies_count': comment.repliesCount,
      'parent_uuid': comment.parentUuid,
      'created_at': comment.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _storyToMap(Story story) {
    return {
      'uuid': story.uuid,
      'author': _userToMap(story.author),
      'media_url': story.mediaUrl,
      'hls_url': story.hlsUrl,
      'media_type': story.mediaType,
      'duration': story.duration,
      'views_count': story.viewsCount,
      'is_viewed': story.isViewed,
      'created_at': story.createdAt.toIso8601String(),
      'expires_at': story.expiresAt.toIso8601String(),
    };
  }
}
