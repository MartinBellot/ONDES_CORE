import 'dart:async';
import '../bridge/js_bridge.dart';
import '../models/websocket_connection.dart';

/// WebSocket module for managing WebSocket connections.
///
/// Allows mini-apps to create and manage WebSocket connections
/// through the native Ondes bridge.
///
/// ## Example
/// ```dart
/// // Connect to a WebSocket server
/// final conn = await Ondes.websocket.connect(
///   'ws://192.168.1.42:8080',
///   options: WebsocketConnectOptions(reconnect: true),
/// );
///
/// // Listen for messages
/// Ondes.websocket.onMessage(conn.id).listen((message) {
///   print('Received: $message');
/// });
///
/// // Send a message
/// await Ondes.websocket.send(conn.id, '<100s50>');
///
/// // Disconnect
/// await Ondes.websocket.disconnect(conn.id);
/// ```
class OndesWebsocket {
  final OndesJsBridge _bridge;

  /// Stream controllers for message events per connection
  final Map<String, StreamController<dynamic>> _messageControllers = {};

  /// Stream controllers for status change events per connection
  final Map<String, StreamController<WebsocketStatusEvent>> _statusControllers = {};

  OndesWebsocket(this._bridge);

  /// Connect to a WebSocket server.
  ///
  /// [url] The WebSocket URL (ws:// or wss://)
  /// [options] Connection options (reconnect, timeout)
  ///
  /// Returns the connection info including the unique connection ID.
  ///
  /// Throws [OndesBridgeException] if connection fails.
  Future<WebsocketConnection> connect(
    String url, {
    WebsocketConnectOptions? options,
  }) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Websocket.connect',
      [url, options?.toJson() ?? {}],
    );

    if (result == null) {
      throw const OndesBridgeException(
        code: 'CONNECTION_FAILED',
        message: 'Failed to connect to WebSocket',
      );
    }

    final connection = WebsocketConnection.fromJson(result);

    // Initialize stream controllers for this connection
    _messageControllers[connection.id] = StreamController<dynamic>.broadcast();
    _statusControllers[connection.id] = StreamController<WebsocketStatusEvent>.broadcast();

    // Note: The native handler will push events via JS callbacks.
    // In a real implementation, we'd set up JS interop listeners here.
    // For Flutter Web, the JS bridge handles this via evaluateJavascript.

    return connection;
  }

  /// Disconnect from a WebSocket server.
  ///
  /// [connectionId] The connection ID from connect()
  Future<void> disconnect(String connectionId) async {
    await _bridge.call('Ondes.Websocket.disconnect', [connectionId]);

    // Clean up stream controllers
    await _messageControllers[connectionId]?.close();
    await _statusControllers[connectionId]?.close();
    _messageControllers.remove(connectionId);
    _statusControllers.remove(connectionId);
  }

  /// Send a message through a WebSocket connection.
  ///
  /// [connectionId] The connection ID
  /// [data] The data to send (String, Map, or List)
  ///
  /// Maps and Lists will be automatically JSON-encoded.
  Future<void> send(String connectionId, dynamic data) async {
    await _bridge.call('Ondes.Websocket.send', [connectionId, data]);
  }

  /// Get the status of a WebSocket connection.
  ///
  /// [connectionId] The connection ID
  ///
  /// Returns connection info or null if not found.
  Future<WebsocketConnectionStatus?> getStatus(String connectionId) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Websocket.getStatus',
      [connectionId],
    );

    if (result == null || result['exists'] == false) {
      return null;
    }

    return WebsocketConnectionStatus.fromJson(result);
  }

  /// List all active WebSocket connections.
  ///
  /// Returns a list of all managed connections.
  Future<List<WebsocketConnection>> list() async {
    final result = await _bridge.call<List<dynamic>>('Ondes.Websocket.list');

    if (result == null) {
      return [];
    }

    return result
        .map((item) => WebsocketConnection.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Disconnect all WebSocket connections.
  ///
  /// Returns the number of connections that were closed.
  Future<int> disconnectAll() async {
    final result = await _bridge.call<Map<String, dynamic>>('Ondes.Websocket.disconnectAll');

    // Clean up all stream controllers
    for (final controller in _messageControllers.values) {
      await controller.close();
    }
    for (final controller in _statusControllers.values) {
      await controller.close();
    }
    _messageControllers.clear();
    _statusControllers.clear();

    return result?['disconnected'] as int? ?? 0;
  }

  /// Get a stream of messages for a connection.
  ///
  /// [connectionId] The connection ID
  ///
  /// Note: In Flutter Web, messages are pushed from the native side
  /// via JavaScript callbacks. This stream will receive those messages.
  ///
  /// Returns a broadcast stream of incoming messages.
  Stream<dynamic> onMessage(String connectionId) {
    _messageControllers[connectionId] ??= StreamController<dynamic>.broadcast();
    return _messageControllers[connectionId]!.stream;
  }

  /// Get a stream of status changes for a connection.
  ///
  /// [connectionId] The connection ID
  ///
  /// Returns a broadcast stream of status change events.
  Stream<WebsocketStatusEvent> onStatusChange(String connectionId) {
    _statusControllers[connectionId] ??= StreamController<WebsocketStatusEvent>.broadcast();
    return _statusControllers[connectionId]!.stream;
  }

  /// Internal method to push a message to the stream.
  /// Called from JavaScript via the bridge.
  void pushMessage(String connectionId, dynamic message) {
    _messageControllers[connectionId]?.add(message);
  }

  /// Internal method to push a status change to the stream.
  /// Called from JavaScript via the bridge.
  void pushStatusChange(String connectionId, WebsocketStatus status, String? error) {
    _statusControllers[connectionId]?.add(
      WebsocketStatusEvent(status: status, error: error),
    );
  }
}

/// Extended connection status with additional info
class WebsocketConnectionStatus {
  final String id;
  final String url;
  final WebsocketStatus status;
  final bool exists;
  final DateTime? connectedAt;
  final bool reconnect;

  const WebsocketConnectionStatus({
    required this.id,
    required this.url,
    required this.status,
    required this.exists,
    this.connectedAt,
    this.reconnect = false,
  });

  factory WebsocketConnectionStatus.fromJson(Map<String, dynamic> json) {
    return WebsocketConnectionStatus(
      id: json['id'] as String,
      url: json['url'] as String? ?? '',
      status: WebsocketStatus.fromString(json['status'] as String),
      exists: json['exists'] as bool? ?? false,
      connectedAt: json['connectedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['connectedAt'] as int)
          : null,
      reconnect: json['reconnect'] as bool? ?? false,
    );
  }
}

/// WebSocket status change event
class WebsocketStatusEvent {
  final WebsocketStatus status;
  final String? error;

  const WebsocketStatusEvent({
    required this.status,
    this.error,
  });

  @override
  String toString() {
    return 'WebsocketStatusEvent(status: ${status.name}, error: $error)';
  }
}
