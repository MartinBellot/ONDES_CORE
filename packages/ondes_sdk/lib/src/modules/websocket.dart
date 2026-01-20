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

  /// Polling timers per connection (for macOS compatibility)
  final Map<String, Timer> _pollingTimers = {};

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

    // Start polling for messages and status changes (macOS compatibility)
    _startPolling(connection.id);

    return connection;
  }

  /// Disconnect from a WebSocket server.
  ///
  /// [connectionId] The connection ID from connect()
  Future<void> disconnect(String connectionId) async {
    // Stop polling first
    _stopPolling(connectionId);

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
    // Stop all polling
    for (final id in _pollingTimers.keys.toList()) {
      _stopPolling(id);
    }

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

  /// Start polling for messages and status changes (macOS compatibility)
  void _startPolling(String connectionId) {
    if (_pollingTimers.containsKey(connectionId)) return;

    _pollingTimers[connectionId] = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _pollConnection(connectionId),
    );
    // Also poll immediately
    _pollConnection(connectionId);
  }

  /// Stop polling for a connection
  void _stopPolling(String connectionId) {
    _pollingTimers[connectionId]?.cancel();
    _pollingTimers.remove(connectionId);
  }

  /// Poll for messages and status changes
  Future<void> _pollConnection(String connectionId) async {
    try {
      // Poll for messages
      final msgResult = await _bridge.call<Map<String, dynamic>>(
        'Ondes.Websocket.pollMessages',
        [connectionId],
      );

      if (msgResult != null && msgResult['messages'] is List) {
        final messages = msgResult['messages'] as List;
        for (final msg in messages) {
          final message = msg is Map ? msg['message'] : msg;
          _messageControllers[connectionId]?.add(message);
        }
      }

      // Poll for status changes
      final statusResult = await _bridge.call<Map<String, dynamic>>(
        'Ondes.Websocket.pollStatus',
        [connectionId],
      );

      if (statusResult != null && statusResult['statusChanges'] is List) {
        final changes = statusResult['statusChanges'] as List;
        for (final change in changes) {
          if (change is Map) {
            final status = WebsocketStatus.fromString(change['status'] as String? ?? 'unknown');
            final error = change['error'] as String?;
            _statusControllers[connectionId]?.add(
              WebsocketStatusEvent(status: status, error: error),
            );
          }
        }
      }
    } catch (e) {
      // Connection may have been closed, stop polling
      _stopPolling(connectionId);
    }
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
