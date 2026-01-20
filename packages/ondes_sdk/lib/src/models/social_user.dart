import 'enums.dart';

/// User in the social context with follower information.
class SocialUser {
  /// Unique user identifier.
  final int id;

  /// Username/handle.
  final String username;

  /// Avatar image URL.
  final String? avatar;

  /// User biography/description.
  final String? bio;

  /// Number of followers.
  final int followersCount;

  /// Number of users being followed.
  final int followingCount;

  /// Whether the current user follows this user.
  final bool isFollowing;

  /// Friendship status with the current user.
  final FriendshipStatus? friendshipStatus;

  const SocialUser({
    required this.id,
    required this.username,
    this.avatar,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.friendshipStatus,
  });

  /// Create from JSON map.
  factory SocialUser.fromJson(Map<String, dynamic> json) {
    return SocialUser(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      avatar: json['avatar'] as String? ?? json['profile_picture'] as String?,
      bio: json['bio'] as String?,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      isFollowing: json['is_following'] as bool? ?? false,
      friendshipStatus: _parseFriendshipStatus(json['friendshipStatus'] as String?),
    );
  }

  static FriendshipStatus? _parseFriendshipStatus(String? status) {
    if (status == null) return null;
    switch (status) {
      case 'pending':
        return FriendshipStatus.pending;
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'blocked':
        return FriendshipStatus.blocked;
      default:
        return FriendshipStatus.none;
    }
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      if (avatar != null) 'avatar': avatar,
      if (bio != null) 'bio': bio,
      'followers_count': followersCount,
      'following_count': followingCount,
      'is_following': isFollowing,
    };
  }

  @override
  String toString() => 'SocialUser($username)';
}
