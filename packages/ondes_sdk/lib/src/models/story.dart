import 'social_user.dart';

/// A temporary story that expires.
class Story {
  /// Unique story identifier.
  final String uuid;

  /// Author of the story.
  final SocialUser author;

  /// Media URL.
  final String mediaUrl;

  /// HLS streaming URL (for videos).
  final String? hlsUrl;

  /// Type of media (image, video).
  final String mediaType;

  /// Display duration in seconds.
  final double duration;

  /// Number of views.
  final int viewsCount;

  /// Whether the current user has viewed this story.
  final bool isViewed;

  /// When the story was created.
  final DateTime createdAt;

  /// When the story expires.
  final DateTime expiresAt;

  const Story({
    required this.uuid,
    required this.author,
    required this.mediaUrl,
    this.hlsUrl,
    required this.mediaType,
    this.duration = 5,
    this.viewsCount = 0,
    this.isViewed = false,
    required this.createdAt,
    required this.expiresAt,
  });

  /// Whether this is a video story.
  bool get isVideo => mediaType == 'video';

  /// Whether the story has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Create from JSON map.
  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      uuid: json['uuid'] as String? ?? '',
      author: SocialUser.fromJson(json['author'] as Map<String, dynamic>? ?? {}),
      mediaUrl: json['media_url'] as String? ?? '',
      hlsUrl: json['hls_url'] as String?,
      mediaType: json['media_type'] as String? ?? 'image',
      duration: (json['duration'] as num?)?.toDouble() ?? 5,
      viewsCount: json['views_count'] as int? ?? 0,
      isViewed: json['is_viewed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.now().add(const Duration(hours: 24)),
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'author': author.toJson(),
      'media_url': mediaUrl,
      if (hlsUrl != null) 'hls_url': hlsUrl,
      'media_type': mediaType,
      'duration': duration,
      'views_count': viewsCount,
      'is_viewed': isViewed,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'Story($uuid by ${author.username})';
}

/// Group of stories from a user.
class UserStories {
  /// User who posted the stories.
  final SocialUser user;

  /// List of stories.
  final List<Story> stories;

  /// Whether there are unviewed stories.
  final bool hasUnviewed;

  const UserStories({
    required this.user,
    required this.stories,
    this.hasUnviewed = false,
  });

  /// Create from JSON map.
  factory UserStories.fromJson(Map<String, dynamic> json) {
    return UserStories(
      user: SocialUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      stories: (json['stories'] as List?)
              ?.map((e) => Story.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hasUnviewed: json['hasUnviewed'] as bool? ?? false,
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'stories': stories.map((s) => s.toJson()).toList(),
      'hasUnviewed': hasUnviewed,
    };
  }

  @override
  String toString() => 'UserStories(${user.username}, ${stories.length} stories)';
}
