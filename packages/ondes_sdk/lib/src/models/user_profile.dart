/// User profile information from the host application.
class UserProfile {
  /// Unique user identifier.
  final String id;

  /// Username/handle.
  final String username;

  /// Email address.
  final String? email;

  /// Avatar image URL.
  final String? avatar;

  /// User biography/description.
  final String? bio;

  const UserProfile({
    required this.id,
    required this.username,
    this.email,
    this.avatar,
    this.bio,
  });

  /// Create from JSON map.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      if (email != null) 'email': email,
      if (avatar != null) 'avatar': avatar,
      if (bio != null) 'bio': bio,
    };
  }

  @override
  String toString() => 'UserProfile($username)';
}
