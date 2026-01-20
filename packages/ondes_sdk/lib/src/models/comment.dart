import 'social_user.dart';

/// A comment on a post.
class PostComment {
  /// Unique comment identifier.
  final String uuid;

  /// Author of the comment.
  final SocialUser user;

  /// Text content of the comment.
  final String content;

  /// Number of likes.
  final int likesCount;

  /// Whether the current user has liked this comment.
  final bool isLiked;

  /// Number of replies.
  final int repliesCount;

  /// Parent comment UUID (for replies).
  final String? parentUuid;

  /// When the comment was created.
  final DateTime createdAt;

  const PostComment({
    required this.uuid,
    required this.user,
    required this.content,
    this.likesCount = 0,
    this.isLiked = false,
    this.repliesCount = 0,
    this.parentUuid,
    required this.createdAt,
  });

  /// Whether this is a reply to another comment.
  bool get isReply => parentUuid != null;

  /// Create from JSON map.
  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      uuid: json['uuid'] as String? ?? '',
      user: SocialUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      content: json['content'] as String? ?? '',
      likesCount: json['likes_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      repliesCount: json['replies_count'] as int? ?? 0,
      parentUuid: json['parent_uuid'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'user': user.toJson(),
      'content': content,
      'likes_count': likesCount,
      'is_liked': isLiked,
      'replies_count': repliesCount,
      if (parentUuid != null) 'parent_uuid': parentUuid,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'PostComment($uuid by ${user.username})';
}
