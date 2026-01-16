import 'package:dio/dio.dart';
import 'auth_service.dart';

// ==================== MODELS ====================

/// Représente un utilisateur dans le contexte social
class SocialUser {
  final int id;
  final String username;
  final String avatar;
  final String bio;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;

  SocialUser({
    required this.id,
    required this.username,
    required this.avatar,
    required this.bio,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
  });

  factory SocialUser.fromJson(Map<String, dynamic> json) {
    return SocialUser(
      id: json['id'],
      username: json['username'] ?? '',
      avatar: json['avatar'] ?? '',
      bio: json['bio'] ?? '',
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      isFollowing: json['is_following'] ?? false,
    );
  }
}

/// Représente un média de post
class PostMedia {
  final String uuid;
  final String mediaType;
  final String displayUrl;
  final String? thumbnailUrl;
  final String? hlsUrl;
  final int? width;
  final int? height;
  final double? duration;
  final String processingStatus;
  final bool hlsReady;
  final int order;

  PostMedia({
    required this.uuid,
    required this.mediaType,
    required this.displayUrl,
    this.thumbnailUrl,
    this.hlsUrl,
    this.width,
    this.height,
    this.duration,
    required this.processingStatus,
    required this.hlsReady,
    required this.order,
  });

  factory PostMedia.fromJson(Map<String, dynamic> json) {
    return PostMedia(
      uuid: json['uuid'],
      mediaType: json['media_type'],
      displayUrl: json['display_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      hlsUrl: json['hls_url'],
      width: json['width'],
      height: json['height'],
      duration: json['duration']?.toDouble(),
      processingStatus: json['processing_status'] ?? 'pending',
      hlsReady: json['hls_ready'] ?? false,
      order: json['order'] ?? 0,
    );
  }

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';
}

/// Représente un commentaire
class PostComment {
  final String uuid;
  final SocialUser user;
  final String content;
  final int likesCount;
  final bool isLiked;
  final int repliesCount;
  final String? parentUuid;
  final DateTime createdAt;

  PostComment({
    required this.uuid,
    required this.user,
    required this.content,
    required this.likesCount,
    required this.isLiked,
    required this.repliesCount,
    this.parentUuid,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      uuid: json['uuid'],
      user: SocialUser.fromJson(json['user']),
      content: json['content'] ?? '',
      likesCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      repliesCount: json['replies_count'] ?? 0,
      parentUuid: json['parent'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// Représente un post
class Post {
  final String uuid;
  final SocialUser author;
  final String content;
  final String visibility;
  final List<String> tags;
  final List<PostMedia> media;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final bool isLiked;
  final bool isBookmarked;
  final List<PostComment> commentsPreview;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final DateTime createdAt;
  final double? relevanceScore;

  Post({
    required this.uuid,
    required this.author,
    required this.content,
    required this.visibility,
    required this.tags,
    required this.media,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.viewsCount,
    required this.isLiked,
    required this.isBookmarked,
    required this.commentsPreview,
    this.latitude,
    this.longitude,
    this.locationName,
    required this.createdAt,
    this.relevanceScore,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      uuid: json['uuid'],
      author: SocialUser.fromJson(json['author']),
      content: json['content'] ?? '',
      visibility: json['visibility'] ?? 'followers',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      media: (json['media'] as List?)
              ?.map((e) => PostMedia.fromJson(e))
              .toList() ??
          [],
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      sharesCount: json['shares_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isBookmarked: json['is_bookmarked'] ?? false,
      commentsPreview: (json['comments_preview'] as List?)
              ?.map((e) => PostComment.fromJson(e))
              .toList() ??
          [],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      locationName: json['location_name'],
      createdAt: DateTime.parse(json['created_at']),
      relevanceScore: json['relevance_score']?.toDouble(),
    );
  }

  bool get hasMedia => media.isNotEmpty;
  bool get hasVideo => media.any((m) => m.isVideo);
  PostMedia? get firstMedia => media.isNotEmpty ? media.first : null;
}

/// Représente une story
class Story {
  final String uuid;
  final SocialUser author;
  final String mediaUrl;
  final String? hlsUrl;
  final String mediaType;
  final double duration;
  final int viewsCount;
  final bool isViewed;
  final DateTime createdAt;
  final DateTime expiresAt;

  Story({
    required this.uuid,
    required this.author,
    required this.mediaUrl,
    this.hlsUrl,
    required this.mediaType,
    required this.duration,
    required this.viewsCount,
    required this.isViewed,
    required this.createdAt,
    required this.expiresAt,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      uuid: json['uuid'],
      author: SocialUser.fromJson(json['author']),
      mediaUrl: json['media_url'] ?? '',
      hlsUrl: json['hls_url'],
      mediaType: json['media_type'] ?? 'image',
      duration: (json['duration'] ?? 5.0).toDouble(),
      viewsCount: json['views_count'] ?? 0,
      isViewed: json['is_viewed'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
    );
  }

  bool get isVideo => mediaType == 'video';
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Groupe de stories par utilisateur
class UserStories {
  final SocialUser user;
  final List<Story> stories;
  final bool hasUnviewed;

  UserStories({
    required this.user,
    required this.stories,
    required this.hasUnviewed,
  });

  factory UserStories.fromJson(Map<String, dynamic> json) {
    return UserStories(
      user: SocialUser.fromJson(json['user']),
      stories:
          (json['stories'] as List).map((e) => Story.fromJson(e)).toList(),
      hasUnviewed: json['has_unviewed'] ?? false,
    );
  }
}

/// Options pour publier un post
class PublishOptions {
  final String content;
  final List<String> mediaPaths;
  final String visibility;
  final List<String> tags;
  final double? latitude;
  final double? longitude;
  final String? locationName;

  PublishOptions({
    this.content = '',
    this.mediaPaths = const [],
    this.visibility = 'followers',
    this.tags = const [],
    this.latitude,
    this.longitude,
    this.locationName,
  });

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'visibility': visibility,
      'tags': tags,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationName != null) 'location_name': locationName,
    };
  }
}

// ==================== SERVICE ====================

/// Service pour gérer les fonctionnalités sociales via l'API
class SocialService {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;
  SocialService._internal();

  final Dio _dio = Dio();

  String get _baseUrl => AuthService().baseUrl;

  Options get _authOptions => Options(
        headers: {'Authorization': 'Token ${AuthService().token}'},
      );

  // ============ FOLLOW ============

  /// Suivre un utilisateur
  Future<Map<String, dynamic>> follow({String? username, int? userId}) async {
    try {
      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (userId != null) data['user_id'] = userId;

      final response = await _dio.post(
        '$_baseUrl/social/follow/',
        data: data,
        options: _authOptions,
      );
      return response.data;
    } catch (e) {
      print('SocialService.follow Error: $e');
      rethrow;
    }
  }

  /// Ne plus suivre un utilisateur
  Future<Map<String, dynamic>> unfollow({String? username, int? userId}) async {
    try {
      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (userId != null) data['user_id'] = userId;

      final response = await _dio.post(
        '$_baseUrl/social/unfollow/',
        data: data,
        options: _authOptions,
      );
      return response.data;
    } catch (e) {
      print('SocialService.unfollow Error: $e');
      rethrow;
    }
  }

  /// Récupérer les followers
  Future<List<SocialUser>> getFollowers({int? userId}) async {
    try {
      final url = userId != null
          ? '$_baseUrl/social/followers/$userId/'
          : '$_baseUrl/social/followers/';

      final response = await _dio.get(url, options: _authOptions);

      return (response.data['followers'] as List)
          .map((json) => SocialUser.fromJson(json))
          .toList();
    } catch (e) {
      print('SocialService.getFollowers Error: $e');
      rethrow;
    }
  }

  /// Récupérer les following
  Future<List<SocialUser>> getFollowing({int? userId}) async {
    try {
      final url = userId != null
          ? '$_baseUrl/social/following/$userId/'
          : '$_baseUrl/social/following/';

      final response = await _dio.get(url, options: _authOptions);

      return (response.data['following'] as List)
          .map((json) => SocialUser.fromJson(json))
          .toList();
    } catch (e) {
      print('SocialService.getFollowing Error: $e');
      rethrow;
    }
  }

  // ============ POSTS ============

  /// Publier un post avec médias
  Future<Post> publish(PublishOptions options) async {
    try {
      final formData = FormData.fromMap(options.toJson());

      // Ajouter les fichiers médias
      for (int i = 0; i < options.mediaPaths.length; i++) {
        final path = options.mediaPaths[i];
        formData.files.add(MapEntry(
          'media',
          await MultipartFile.fromFile(path),
        ));
      }

      final response = await _dio.post(
        '$_baseUrl/social/publish/',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Token ${AuthService().token}',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      return Post.fromJson(response.data['post']);
    } catch (e) {
      print('SocialService.publish Error: $e');
      rethrow;
    }
  }

  /// Récupérer le feed
  Future<List<Post>> getFeed({
    int limit = 50,
    int offset = 0,
    String type = 'main', // main, discover, video
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/social/feed/',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          'type': type,
        },
        options: _authOptions,
      );

      return (response.data['posts'] as List)
          .map((json) => Post.fromJson(json))
          .toList();
    } catch (e) {
      print('SocialService.getFeed Error: $e');
      rethrow;
    }
  }

  /// Récupérer un post spécifique
  Future<Post> getPost(String postUuid) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/social/posts/$postUuid/',
        options: _authOptions,
      );

      return Post.fromJson(response.data);
    } catch (e) {
      print('SocialService.getPost Error: $e');
      rethrow;
    }
  }

  /// Supprimer un post
  Future<bool> deletePost(String postUuid) async {
    try {
      await _dio.delete(
        '$_baseUrl/social/posts/$postUuid/delete/',
        options: _authOptions,
      );
      return true;
    } catch (e) {
      print('SocialService.deletePost Error: $e');
      rethrow;
    }
  }

  /// Récupérer les posts d'un utilisateur
  Future<List<Post>> getUserPosts(int userId,
      {int limit = 30, int offset = 0}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/social/users/$userId/posts/',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
        options: _authOptions,
      );

      return (response.data['posts'] as List)
          .map((json) => Post.fromJson(json))
          .toList();
    } catch (e) {
      print('SocialService.getUserPosts Error: $e');
      rethrow;
    }
  }

  // ============ LIKES ============

  /// Liker un post
  Future<Map<String, dynamic>> likePost(String postUuid) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/social/posts/$postUuid/like/',
        options: _authOptions,
      );
      return response.data;
    } catch (e) {
      print('SocialService.likePost Error: $e');
      rethrow;
    }
  }

  /// Retirer le like d'un post
  Future<Map<String, dynamic>> unlikePost(String postUuid) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/social/posts/$postUuid/unlike/',
        options: _authOptions,
      );
      return response.data;
    } catch (e) {
      print('SocialService.unlikePost Error: $e');
      rethrow;
    }
  }

  /// Récupérer les utilisateurs qui ont liké un post
  Future<List<SocialUser>> getPostLikers(String postUuid) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/social/posts/$postUuid/likers/',
        options: _authOptions,
      );

      return (response.data['users'] as List)
          .map((json) => SocialUser.fromJson(json))
          .toList();
    } catch (e) {
      print('SocialService.getPostLikers Error: $e');
      rethrow;
    }
  }

  // ============ COMMENTS ============

  /// Ajouter un commentaire
  Future<PostComment> addComment(String postUuid, String content,
      {String? parentUuid}) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/social/posts/$postUuid/comments/add/',
        data: {
          'content': content,
          if (parentUuid != null) 'parent_uuid': parentUuid,
        },
        options: _authOptions,
      );

      return PostComment.fromJson(response.data['comment']);
    } catch (e) {
      print('SocialService.addComment Error: $e');
      rethrow;
    }
  }

  /// Récupérer les commentaires d'un post
  Future<List<PostComment>> getComments(String postUuid,
      {int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/social/posts/$postUuid/comments/',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
        options: _authOptions,
      );

      return (response.data['comments'] as List)
          .map((json) => PostComment.fromJson(json))
          .toList();
    } catch (e) {
      print('SocialService.getComments Error: $e');
      rethrow;
    }
  }

  /// Récupérer les réponses à un commentaire
  Future<List<PostComment>> getCommentReplies(String commentUuid) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/social/comments/$commentUuid/replies/',
        options: _authOptions,
      );

      return (response.data['replies'] as List)
          .map((json) => PostComment.fromJson(json))
          .toList();
    } catch (e) {
      print('SocialService.getCommentReplies Error: $e');
      rethrow;
    }
  }

  /// Supprimer un commentaire
  Future<bool> deleteComment(String commentUuid) async {
    try {
      await _dio.delete(
        '$_baseUrl/social/comments/$commentUuid/delete/',
        options: _authOptions,
      );
      return true;
    } catch (e) {
      print('SocialService.deleteComment Error: $e');
      rethrow;
    }
  }

  /// Liker un commentaire
  Future<Map<String, dynamic>> likeComment(String commentUuid) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/social/comments/$commentUuid/like/',
        options: _authOptions,
      );
      return response.data;
    } catch (e) {
      print('SocialService.likeComment Error: $e');
      rethrow;
    }
  }

  // ============ BOOKMARKS ============

  /// Sauvegarder un post
  Future<bool> bookmarkPost(String postUuid) async {
    try {
      await _dio.post(
        '$_baseUrl/social/posts/$postUuid/bookmark/',
        options: _authOptions,
      );
      return true;
    } catch (e) {
      print('SocialService.bookmarkPost Error: $e');
      rethrow;
    }
  }

  /// Retirer un post des favoris
  Future<bool> unbookmarkPost(String postUuid) async {
    try {
      await _dio.post(
        '$_baseUrl/social/posts/$postUuid/unbookmark/',
        options: _authOptions,
      );
      return true;
    } catch (e) {
      print('SocialService.unbookmarkPost Error: $e');
      rethrow;
    }
  }

  /// Récupérer les posts sauvegardés
  Future<List<Post>> getBookmarks({int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/social/bookmarks/',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
        options: _authOptions,
      );

      return (response.data['posts'] as List)
          .map((json) => Post.fromJson(json))
          .toList();
    } catch (e) {
      print('SocialService.getBookmarks Error: $e');
      rethrow;
    }
  }

  // ============ STORIES ============

  /// Créer une story
  Future<Story> createStory(String mediaPath, {double duration = 5.0}) async {
    try {
      final formData = FormData.fromMap({
        'media': await MultipartFile.fromFile(mediaPath),
        'duration': duration,
      });

      final response = await _dio.post(
        '$_baseUrl/social/stories/create/',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Token ${AuthService().token}',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      return Story.fromJson(response.data['story']);
    } catch (e) {
      print('SocialService.createStory Error: $e');
      rethrow;
    }
  }

  /// Récupérer les stories
  Future<List<UserStories>> getStories() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/social/stories/',
        options: _authOptions,
      );

      return (response.data['stories'] as List)
          .map((json) => UserStories.fromJson(json))
          .toList();
    } catch (e) {
      print('SocialService.getStories Error: $e');
      rethrow;
    }
  }

  /// Marquer une story comme vue
  Future<int> viewStory(String storyUuid) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/social/stories/$storyUuid/view/',
        options: _authOptions,
      );
      return response.data['views_count'] ?? 0;
    } catch (e) {
      print('SocialService.viewStory Error: $e');
      rethrow;
    }
  }

  /// Supprimer une story
  Future<bool> deleteStory(String storyUuid) async {
    try {
      await _dio.delete(
        '$_baseUrl/social/stories/$storyUuid/delete/',
        options: _authOptions,
      );
      return true;
    } catch (e) {
      print('SocialService.deleteStory Error: $e');
      rethrow;
    }
  }

  // ============ PROFILE ============

  /// Récupérer le profil social d'un utilisateur
  Future<Map<String, dynamic>> getProfile({int? userId, String? username}) async {
    try {
      String url;
      if (userId != null) {
        url = '$_baseUrl/social/profile/$userId/';
      } else if (username != null) {
        url = '$_baseUrl/social/profile/username/$username/';
      } else {
        url = '$_baseUrl/social/profile/';
      }

      final response = await _dio.get(url, options: _authOptions);
      return response.data;
    } catch (e) {
      print('SocialService.getProfile Error: $e');
      rethrow;
    }
  }

  /// Rechercher des utilisateurs
  Future<List<SocialUser>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/social/search/',
        queryParameters: {'q': query},
        options: _authOptions,
      );

      return (response.data['users'] as List)
          .map((json) => SocialUser.fromJson(json))
          .toList();
    } catch (e) {
      print('SocialService.searchUsers Error: $e');
      rethrow;
    }
  }
}
