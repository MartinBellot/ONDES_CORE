/// Friend request information.
class FriendRequest {
  /// Unique request identifier.
  final int id;

  /// User who sent the request (for incoming requests).
  final Map<String, dynamic>? fromUser;

  /// User who received the request (for outgoing requests).
  final Map<String, dynamic>? toUser;

  /// Request status (pending, accepted, rejected).
  final String status;

  /// When the request was created.
  final DateTime createdAt;

  /// When the request was accepted (if applicable).
  final DateTime? acceptedAt;

  const FriendRequest({
    required this.id,
    this.fromUser,
    this.toUser,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
  });

  /// Create from JSON map.
  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as int? ?? 0,
      fromUser: json['fromUser'] as Map<String, dynamic>?,
      toUser: json['toUser'] as Map<String, dynamic>?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.tryParse(json['acceptedAt'] as String)
          : null,
    );
  }

  /// Whether this is a pending request.
  bool get isPending => status == 'pending';

  /// Whether this request was accepted.
  bool get isAccepted => status == 'accepted';

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (fromUser != null) 'fromUser': fromUser,
      if (toUser != null) 'toUser': toUser,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
    };
  }

  @override
  String toString() => 'FriendRequest($id, $status)';
}
