/// WebSocket connection model for Ondes SDK.
///
/// Represents a WebSocket connection managed by the Ondes bridge.
class WebsocketConnection {
  /// Unique identifier for the connection
  final String id;

  /// WebSocket URL
  final String url;

  /// Current connection status
  final WebsocketStatus status;

  /// When the connection was established
  final DateTime? connectedAt;

  /// Whether auto-reconnect is enabled
  final bool reconnect;

  const WebsocketConnection({
    required this.id,
    required this.url,
    required this.status,
    this.connectedAt,
    this.reconnect = false,
  });

  /// Create from JSON map
  factory WebsocketConnection.fromJson(Map<String, dynamic> json) {
    return WebsocketConnection(
      id: json['id'] as String,
      url: json['url'] as String,
      status: WebsocketStatus.fromString(json['status'] as String),
      connectedAt: json['connectedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['connectedAt'] as int)
          : null,
      reconnect: json['reconnect'] as bool? ?? false,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'status': status.name,
      'connectedAt': connectedAt?.millisecondsSinceEpoch,
      'reconnect': reconnect,
    };
  }

  @override
  String toString() {
    return 'WebsocketConnection(id: $id, url: $url, status: ${status.name})';
  }
}

/// WebSocket connection status
enum WebsocketStatus {
  /// Connection is being established
  connecting,

  /// Connection is active
  connected,

  /// Connection has been closed
  disconnected,

  /// Connection is attempting to reconnect
  reconnecting,

  /// Connection encountered an error
  error,

  /// Connection was not found
  notFound;

  /// Parse status from string
  static WebsocketStatus fromString(String value) {
    switch (value) {
      case 'connecting':
        return WebsocketStatus.connecting;
      case 'connected':
        return WebsocketStatus.connected;
      case 'disconnected':
        return WebsocketStatus.disconnected;
      case 'reconnecting':
        return WebsocketStatus.reconnecting;
      case 'error':
        return WebsocketStatus.error;
      case 'not_found':
        return WebsocketStatus.notFound;
      default:
        return WebsocketStatus.disconnected;
    }
  }
}

/// Options for WebSocket connection
class WebsocketConnectOptions {
  /// Whether to automatically reconnect on disconnect
  final bool reconnect;

  /// Connection timeout in milliseconds
  final int timeout;

  const WebsocketConnectOptions({
    this.reconnect = false,
    this.timeout = 10000,
  });

  /// Convert to JSON map for bridge call
  Map<String, dynamic> toJson() {
    return {
      'reconnect': reconnect,
      'timeout': timeout,
    };
  }
}
