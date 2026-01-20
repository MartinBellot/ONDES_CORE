/// Friend information from the friends list.
class Friend {
  /// Unique friend identifier.
  final int id;

  /// Username/handle.
  final String username;

  /// Avatar image URL.
  final String? avatar;

  /// User biography/description.
  final String? bio;

  /// Friendship record ID.
  final int? friendshipId;

  /// Date when friendship was established.
  final DateTime? friendsSince;

  const Friend({
    required this.id,
    required this.username,
    this.avatar,
    this.bio,
    this.friendshipId,
    this.friendsSince,
  });

  /// Create from JSON map.
  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      friendshipId: json['friendshipId'] as int?,
      friendsSince: json['friendsSince'] != null
          ? DateTime.tryParse(json['friendsSince'] as String)
          : null,
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      if (avatar != null) 'avatar': avatar,
      if (bio != null) 'bio': bio,
      if (friendshipId != null) 'friendshipId': friendshipId,
      if (friendsSince != null) 'friendsSince': friendsSince!.toIso8601String(),
    };
  }

  @override
  String toString() => 'Friend($username)';
}
