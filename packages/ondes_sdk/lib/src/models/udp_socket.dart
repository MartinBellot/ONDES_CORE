/// UDP socket model for Ondes SDK
///
/// Represents a UDP socket connection for network discovery
/// and communication.

/// Status of a UDP socket
enum UdpSocketStatus {
  /// Socket is bound and listening
  bound,
  /// Socket is closed
  closed,
}

/// Represents an active UDP socket
class UdpSocket {
  /// Unique identifier for this socket
  final String id;

  /// Local port the socket is bound to
  final int port;

  /// Whether broadcast is enabled
  final bool broadcast;

  /// When the socket was created
  final DateTime? createdAt;

  /// Number of messages received
  final int messagesReceived;

  UdpSocket({
    required this.id,
    required this.port,
    this.broadcast = true,
    this.createdAt,
    this.messagesReceived = 0,
  });

  factory UdpSocket.fromJson(Map<String, dynamic> json) {
    return UdpSocket(
      id: json['id'] as String,
      port: (json['port'] as num).toInt(),
      broadcast: json['broadcast'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num).toInt())
          : null,
      messagesReceived: (json['messagesReceived'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'port': port,
        'broadcast': broadcast,
        'createdAt': createdAt?.millisecondsSinceEpoch,
        'messagesReceived': messagesReceived,
      };
}

/// Options for binding a UDP socket
class UdpBindOptions {
  /// Port to bind to (0 for random available port)
  final int port;

  /// Whether to enable broadcast
  final bool broadcast;

  /// Whether to allow address reuse
  final bool reuseAddress;

  const UdpBindOptions({
    this.port = 0,
    this.broadcast = true,
    this.reuseAddress = true,
  });

  Map<String, dynamic> toJson() => {
        'port': port,
        'broadcast': broadcast,
        'reuseAddress': reuseAddress,
      };
}

/// Represents an incoming UDP message
class UdpMessage {
  /// The socket ID that received the message
  final String socketId;

  /// The message content as string
  final String message;

  /// The raw data bytes
  final List<int>? data;

  /// Sender's IP address
  final String address;

  /// Sender's port
  final int port;

  /// Timestamp of reception
  final DateTime timestamp;

  UdpMessage({
    required this.socketId,
    required this.message,
    this.data,
    required this.address,
    required this.port,
    required this.timestamp,
  });

  factory UdpMessage.fromJson(Map<String, dynamic> json) {
    return UdpMessage(
      socketId: json['socketId'] as String,
      message: json['message'] as String,
      data: json['data'] != null ? List<int>.from(json['data'] as List) : null,
      address: json['address'] as String,
      port: (json['port'] as num).toInt(),
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt())
          : DateTime.now(),
    );
  }
}

/// Result of a UDP send operation
class UdpSendResult {
  /// Whether the send was successful
  final bool success;

  /// Number of bytes sent
  final int? bytesSent;

  /// Target address
  final String address;

  /// Target port
  final int port;

  /// Error message if failed
  final String? error;

  UdpSendResult({
    required this.success,
    this.bytesSent,
    required this.address,
    required this.port,
    this.error,
  });

  factory UdpSendResult.fromJson(Map<String, dynamic> json) {
    return UdpSendResult(
      success: json['success'] as bool? ?? false,
      bytesSent: (json['bytesSent'] as num?)?.toInt(),
      address: json['address'] as String,
      port: (json['port'] as num).toInt(),
      error: json['error'] as String?,
    );
  }
}

/// Result of a UDP broadcast operation
class UdpBroadcastResult {
  /// The socket ID used
  final String socketId;

  /// Length of the message sent
  final int messageLength;

  /// Target port
  final int port;

  /// Individual results for each address
  final List<UdpSendResult> results;

  UdpBroadcastResult({
    required this.socketId,
    required this.messageLength,
    required this.port,
    required this.results,
  });

  factory UdpBroadcastResult.fromJson(Map<String, dynamic> json) {
    return UdpBroadcastResult(
      socketId: json['socketId'] as String,
      messageLength: (json['messageLength'] as num).toInt(),
      port: (json['port'] as num).toInt(),
      results: (json['results'] as List?)
              ?.map((r) => UdpSendResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
