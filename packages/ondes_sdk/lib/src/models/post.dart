import 'social_user.dart';
import 'media.dart';
import 'comment.dart';

/// A social media post.
class Post {
  /// Unique post identifier.
  final String uuid;

  /// Author of the post.
  final SocialUser author;

  /// Text content of the post.
  final String content;

  /// Visibility setting.
  final String visibility;

  /// Tags/hashtags.
  final List<String> tags;

  /// Attached media.
  final List<PostMedia> media;

  /// Number of likes.
  final int likesCount;

  /// Number of comments.
  final int commentsCount;

  /// Number of shares.
  final int sharesCount;

  /// Number of views.
  final int viewsCount;

  /// Whether the current user has liked this post.
  final bool isLiked;

  /// Whether the current user has bookmarked this post.
  final bool isBookmarked;

  /// Preview of top comments.
  final List<PostComment> commentsPreview;

  /// Latitude of post location.
  final double? latitude;

  /// Longitude of post location.
  final double? longitude;

  /// Name of the location.
  final String? locationName;

  /// When the post was created.
  final DateTime createdAt;

  /// Algorithmic relevance score.
  final double? relevanceScore;

  const Post({
    required this.uuid,
    required this.author,
    required this.content,
    required this.visibility,
    this.tags = const [],
    this.media = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    this.commentsPreview = const [],
    this.latitude,
    this.longitude,
    this.locationName,
    required this.createdAt,
    this.relevanceScore,
  });

  /// Whether the post has any media.
  bool get hasMedia => media.isNotEmpty;

  /// Whether the post has a location.
  bool get hasLocation => latitude != null && longitude != null;

  /// Create from JSON map.
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      uuid: json['uuid'] as String? ?? '',
      author: SocialUser.fromJson(json['author'] as Map<String, dynamic>? ?? {}),
      content: json['content'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'followers',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      media: (json['media'] as List?)
              ?.map((e) => PostMedia.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      sharesCount: json['shares_count'] as int? ?? 0,
      viewsCount: json['views_count'] as int? ?? 0,
      isLiked: json['user_has_liked'] as bool? ?? false,
      isBookmarked: json['user_has_bookmarked'] as bool? ?? false,
      commentsPreview: (json['comments_preview'] as List?)
              ?.map((e) => PostComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationName: json['location_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      relevanceScore: (json['relevance_score'] as num?)?.toDouble(),
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'author': author.toJson(),
      'content': content,
      'visibility': visibility,
      'tags': tags,
      'media': media.map((m) => m.toJson()).toList(),
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'shares_count': sharesCount,
      'views_count': viewsCount,
      'user_has_liked': isLiked,
      'user_has_bookmarked': isBookmarked,
      'comments_preview': commentsPreview.map((c) => c.toJson()).toList(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationName != null) 'location_name': locationName,
      'created_at': createdAt.toIso8601String(),
      if (relevanceScore != null) 'relevance_score': relevanceScore,
    };
  }

  @override
  String toString() => 'Post($uuid by ${author.username})';
}
