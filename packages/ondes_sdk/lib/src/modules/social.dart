import '../bridge/js_bridge.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/story.dart';
import '../models/social_user.dart';
import '../models/media.dart';
import '../models/enums.dart';

/// Social module for feed and posts.
///
/// Posts, likes, comments, stories, follows, and more.
///
/// ## Example
/// ```dart
/// // Get feed
/// final posts = await Ondes.social.getFeed(limit: 20);
///
/// // Like a post
/// await Ondes.social.likePost(posts.first.uuid);
///
/// // Create a post
/// await Ondes.social.publish(
///   content: "Hello world!",
///   visibility: PostVisibility.followers,
/// );
///
/// // Follow a user
/// await Ondes.social.follow(username: 'john_doe');
/// ```
class OndesSocial {
  final OndesJsBridge _bridge;

  OndesSocial(this._bridge);

  // ==================== FOLLOW ====================

  /// Follows a user.
  ///
  /// Provide either [username] or [userId].
  Future<Map<String, dynamic>> follow({
    String? username,
    int? userId,
  }) async {
    final options = _buildUserOptions(username: username, userId: userId);
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.follow',
      [options],
    );
    return result ?? {};
  }

  /// Unfollows a user.
  ///
  /// Provide either [username] or [userId].
  Future<Map<String, dynamic>> unfollow({
    String? username,
    int? userId,
  }) async {
    final options = _buildUserOptions(username: username, userId: userId);
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.unfollow',
      [options],
    );
    return result ?? {};
  }

  /// Gets followers of a user.
  ///
  /// [userId] Optional user ID (defaults to current user).
  Future<List<SocialUser>> getFollowers({int? userId}) async {
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Social.getFollowers',
      [userId],
    );
    return _parseUserList(result);
  }

  /// Gets users being followed.
  ///
  /// [userId] Optional user ID (defaults to current user).
  Future<List<SocialUser>> getFollowing({int? userId}) async {
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Social.getFollowing',
      [userId],
    );
    return _parseUserList(result);
  }

  // ==================== POSTS ====================

  /// Publishes a new post.
  ///
  /// [content] Text content of the post.
  /// [media] List of media file paths.
  /// [visibility] Post visibility (public, followers, friends, private).
  /// [tags] List of hashtags.
  /// [latitude] Location latitude.
  /// [longitude] Location longitude.
  /// [locationName] Human-readable location name.
  Future<Post> publish({
    String content = '',
    List<String>? media,
    PostVisibility visibility = PostVisibility.followers,
    List<String>? tags,
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    final options = <String, dynamic>{
      'content': content,
      'visibility': visibility.name,
    };
    if (media != null && media.isNotEmpty) options['media'] = media;
    if (tags != null && tags.isNotEmpty) options['tags'] = tags;
    if (latitude != null) options['latitude'] = latitude;
    if (longitude != null) options['longitude'] = longitude;
    if (locationName != null) options['locationName'] = locationName;

    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.publish',
      [options],
    );
    return Post.fromJson(result ?? {});
  }

  /// Gets the personalized feed.
  ///
  /// [limit] Maximum number of posts to return.
  /// [offset] Pagination offset.
  /// [type] Feed type (main, discover, video).
  Future<List<Post>> getFeed({
    int limit = 50,
    int offset = 0,
    FeedType type = FeedType.main,
  }) async {
    final result = await _bridge.call<List<dynamic>>('Ondes.Social.getFeed', [
      {
        'limit': limit,
        'offset': offset,
        'type': type.name,
      }
    ]);
    return _parsePostList(result);
  }

  /// Gets a specific post by UUID.
  Future<Post> getPost(String postUuid) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.getPost',
      [postUuid],
    );
    return Post.fromJson(result ?? {});
  }

  /// Deletes a post.
  Future<bool> deletePost(String postUuid) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.deletePost',
      [postUuid],
    );
    return result?['success'] == true;
  }

  /// Gets posts by a specific user.
  ///
  /// [userId] The user's ID.
  /// [limit] Maximum number of posts.
  /// [offset] Pagination offset.
  Future<List<Post>> getUserPosts(
    int userId, {
    int limit = 30,
    int offset = 0,
  }) async {
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Social.getUserPosts',
      [
        userId,
        {'limit': limit, 'offset': offset}
      ],
    );
    return _parsePostList(result);
  }

  // ==================== LIKES ====================

  /// Likes a post.
  ///
  /// Returns like status and updated count.
  Future<Map<String, dynamic>> likePost(String postUuid) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.likePost',
      [postUuid],
    );
    return result ?? {};
  }

  /// Unlikes a post.
  ///
  /// Returns like status and updated count.
  Future<Map<String, dynamic>> unlikePost(String postUuid) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.unlikePost',
      [postUuid],
    );
    return result ?? {};
  }

  /// Gets users who liked a post.
  Future<List<SocialUser>> getPostLikers(String postUuid) async {
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Social.getPostLikers',
      [postUuid],
    );
    return _parseUserList(result);
  }

  // ==================== COMMENTS ====================

  /// Adds a comment to a post.
  ///
  /// [postUuid] The post's UUID.
  /// [content] Comment text.
  /// [parentUuid] Parent comment UUID for replies.
  Future<PostComment> addComment(
    String postUuid,
    String content, {
    String? parentUuid,
  }) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.addComment',
      [postUuid, content, parentUuid],
    );
    return PostComment.fromJson(result ?? {});
  }

  /// Gets comments for a post.
  ///
  /// [postUuid] The post's UUID.
  /// [limit] Maximum number of comments.
  /// [offset] Pagination offset.
  Future<List<PostComment>> getComments(
    String postUuid, {
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Social.getComments',
      [
        postUuid,
        {'limit': limit, 'offset': offset}
      ],
    );
    return _parseCommentList(result);
  }

  /// Gets replies to a comment.
  Future<List<PostComment>> getCommentReplies(String commentUuid) async {
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Social.getCommentReplies',
      [commentUuid],
    );
    return _parseCommentList(result);
  }

  /// Deletes a comment.
  Future<bool> deleteComment(String commentUuid) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.deleteComment',
      [commentUuid],
    );
    return result?['success'] == true;
  }

  /// Likes a comment.
  Future<Map<String, dynamic>> likeComment(String commentUuid) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.likeComment',
      [commentUuid],
    );
    return result ?? {};
  }

  // ==================== BOOKMARKS ====================

  /// Bookmarks a post.
  Future<bool> bookmarkPost(String postUuid) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.bookmarkPost',
      [postUuid],
    );
    return result?['bookmarked'] == true;
  }

  /// Removes a post from bookmarks.
  Future<bool> unbookmarkPost(String postUuid) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.unbookmarkPost',
      [postUuid],
    );
    return result?['success'] == true;
  }

  /// Gets bookmarked posts.
  ///
  /// [limit] Maximum number of posts.
  /// [offset] Pagination offset.
  Future<List<Post>> getBookmarks({
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Social.getBookmarks',
      [
        {'limit': limit, 'offset': offset}
      ],
    );
    return _parsePostList(result);
  }

  // ==================== STORIES ====================

  /// Creates a new story.
  ///
  /// [mediaPath] Path to the media file.
  /// [duration] Display duration in seconds.
  Future<Story> createStory(String mediaPath, {double duration = 5}) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.createStory',
      [mediaPath, duration],
    );
    return Story.fromJson(result ?? {});
  }

  /// Gets stories from followed users.
  Future<List<UserStories>> getStories() async {
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Social.getStories',
    );
    return result
            ?.map((e) => UserStories.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  /// Marks a story as viewed.
  ///
  /// Returns the updated view count.
  Future<int> viewStory(String storyUuid) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.viewStory',
      [storyUuid],
    );
    return result?['viewsCount'] as int? ?? 0;
  }

  /// Deletes a story.
  Future<bool> deleteStory(String storyUuid) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.deleteStory',
      [storyUuid],
    );
    return result?['success'] == true;
  }

  // ==================== PROFILE ====================

  /// Gets a user's social profile.
  ///
  /// Provide [userId] or [username], or neither for current user.
  Future<Map<String, dynamic>> getProfile({
    int? userId,
    String? username,
  }) async {
    final options = <String, dynamic>{};
    if (userId != null) options['userId'] = userId;
    if (username != null) options['username'] = username;

    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Social.getProfile',
      [options],
    );
    return result ?? {};
  }

  /// Searches for users.
  ///
  /// [query] Search term (minimum 2 characters).
  Future<List<SocialUser>> searchUsers(String query) async {
    if (query.length < 2) {
      throw const OndesBridgeException(
        code: 'INVALID_ARGUMENT',
        message: 'Query must be at least 2 characters',
      );
    }

    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Social.searchUsers',
      [query],
    );
    return _parseUserList(result);
  }

  // ==================== MEDIA ====================

  /// Opens the native media picker.
  ///
  /// [allowVideo] Whether to allow video selection.
  /// [videoOnly] Whether to only allow video selection.
  /// [multiple] Whether to allow multiple selection.
  /// [maxFiles] Maximum number of files to select.
  Future<List<PickedMedia>> pickMedia({
    bool allowVideo = false,
    bool videoOnly = false,
    bool multiple = false,
    int maxFiles = 10,
  }) async {
    final result = await _bridge.call<List<dynamic>>('Ondes.Social.pickMedia', [
      {
        'allowVideo': allowVideo,
        'videoOnly': videoOnly,
        'multiple': multiple,
        'maxFiles': maxFiles,
      }
    ]);
    return result
            ?.map((e) => PickedMedia.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  // ==================== HELPERS ====================

  Map<String, dynamic> _buildUserOptions({String? username, int? userId}) {
    if (username == null && userId == null) {
      throw const OndesBridgeException(
        code: 'INVALID_ARGUMENT',
        message: 'Either username or userId is required',
      );
    }
    final options = <String, dynamic>{};
    if (username != null) options['username'] = username;
    if (userId != null) options['userId'] = userId;
    return options;
  }

  List<SocialUser> _parseUserList(List<dynamic>? result) {
    return result
            ?.map((e) => SocialUser.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  List<Post> _parsePostList(List<dynamic>? result) {
    return result
            ?.map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  List<PostComment> _parseCommentList(List<dynamic>? result) {
    return result
            ?.map((e) => PostComment.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }
}
