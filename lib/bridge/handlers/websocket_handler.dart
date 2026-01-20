import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'base_handler.dart';

/// Handler for Ondes.Websocket namespace
/// Manages WebSocket connections for mini-apps
class WebsocketHandler extends BaseHandler {
  WebsocketHandler(BuildContext context) : super(context);

  /// Active WebSocket connections
  final Map<String, _WebsocketConnection> _connections = {};

  /// Counter for generating unique connection IDs
  int _connectionCounter = 0;

  /// Message queues for each connection (polling-based approach for macOS compatibility)
  final Map<String, List<Map<String, dynamic>>> _messageQueues = {};
  
  /// Status change queues for each connection
  final Map<String, List<Map<String, dynamic>>> _statusQueues = {};

  @override
  void registerHandlers() {
    _registerConnect();
    _registerDisconnect();
    _registerSend();
    _registerGetStatus();
    _registerList();
    _registerDisconnectAll();
    _registerPollMessages();
    _registerPollStatus();
  }

  /// Generate a unique connection ID
  String _generateConnectionId() {
    _connectionCounter++;
    return 'ws_${DateTime.now().millisecondsSinceEpoch}_$_connectionCounter';
  }

  /// Connect to a WebSocket server
  void _registerConnect() {
    addHandler('Ondes.Websocket.connect', (args) async {
      if (args.isEmpty) {
        throw Exception('URL is required');
      }

      final url = args[0] as String;
      final options = args.length > 1 && args[1] is Map
          ? Map<String, dynamic>.from(args[1] as Map)
          : <String, dynamic>{};

      final reconnect = options['reconnect'] as bool? ?? false;
      final timeout = options['timeout'] as int? ?? 10000;

      final connectionId = _generateConnectionId();

      try {
        final uri = Uri.parse(url);
        final channel = WebSocketChannel.connect(uri);

        // Wait for connection with timeout
        await channel.ready.timeout(
          Duration(milliseconds: timeout),
          onTimeout: () {
            throw TimeoutException('Connection timeout after ${timeout}ms');
          },
        );

        final connection = _WebsocketConnection(
          id: connectionId,
          url: url,
          channel: channel,
          status: WebsocketStatus.connecting,
          reconnect: reconnect,
          timeout: timeout,
        );

        _connections[connectionId] = connection;

        // Set up message listener
        connection.subscription = channel.stream.listen(
          (message) => _handleMessage(connectionId, message),
          onError: (error) => _handleError(connectionId, error),
          onDone: () => _handleClosed(connectionId),
        );

        connection.status = WebsocketStatus.connected;
        connection.connectedAt = DateTime.now();

        debugPrint('[WebsocketHandler] Connected: $connectionId to $url');

        return {
          'id': connectionId,
          'url': url,
          'status': 'connected',
          'connectedAt': connection.connectedAt?.millisecondsSinceEpoch,
        };
      } catch (e) {
        debugPrint('[WebsocketHandler] Connection failed: $e');
        throw Exception('Failed to connect: $e');
      }
    });
  }

  /// Disconnect from a WebSocket server
  void _registerDisconnect() {
    addHandler('Ondes.Websocket.disconnect', (args) async {
      if (args.isEmpty) {
        throw Exception('Connection ID is required');
      }

      final connectionId = args[0] as String;
      await _closeConnection(connectionId);

      return {'success': true, 'id': connectionId};
    });
  }

  /// Send a message through a WebSocket connection
  void _registerSend() {
    addHandler('Ondes.Websocket.send', (args) async {
      if (args.length < 2) {
        throw Exception('Connection ID and data are required');
      }

      final connectionId = args[0] as String;
      final data = args[1];

      final connection = _connections[connectionId];
      if (connection == null) {
        throw Exception('Connection not found: $connectionId');
      }

      if (connection.status != WebsocketStatus.connected) {
        throw Exception('Connection is not active: ${connection.status.name}');
      }

      try {
        // Convert data to string if it's a Map or List (JSON)
        final message = data is Map || data is List ? jsonEncode(data) : data.toString();
        connection.channel.sink.add(message);

        debugPrint('[WebsocketHandler] Sent to $connectionId: $message');

        return {'success': true, 'id': connectionId};
      } catch (e) {
        throw Exception('Failed to send message: $e');
      }
    });
  }

  /// Get the status of a WebSocket connection
  void _registerGetStatus() {
    addHandler('Ondes.Websocket.getStatus', (args) async {
      if (args.isEmpty) {
        throw Exception('Connection ID is required');
      }

      final connectionId = args[0] as String;
      final connection = _connections[connectionId];

      if (connection == null) {
        return {
          'id': connectionId,
          'status': 'not_found',
          'exists': false,
        };
      }

      return {
        'id': connectionId,
        'url': connection.url,
        'status': connection.status.name,
        'exists': true,
        'connectedAt': connection.connectedAt?.millisecondsSinceEpoch,
        'reconnect': connection.reconnect,
      };
    });
  }

  /// List all active WebSocket connections
  void _registerList() {
    addHandler('Ondes.Websocket.list', (args) async {
      return _connections.values.map((conn) => {
        'id': conn.id,
        'url': conn.url,
        'status': conn.status.name,
        'connectedAt': conn.connectedAt?.millisecondsSinceEpoch,
      }).toList();
    });
  }

  /// Disconnect all WebSocket connections
  void _registerDisconnectAll() {
    addHandler('Ondes.Websocket.disconnectAll', (args) async {
      final ids = _connections.keys.toList();
      for (final id in ids) {
        await _closeConnection(id);
      }
      _messageQueues.clear();
      _statusQueues.clear();
      return {'success': true, 'disconnected': ids.length};
    });
  }

  /// Poll for pending messages (macOS compatible approach)
  void _registerPollMessages() {
    addHandler('Ondes.Websocket.pollMessages', (args) async {
      if (args.isEmpty) {
        throw Exception('Connection ID is required');
      }
      
      final connectionId = args[0] as String;
      final queue = _messageQueues[connectionId];
      
      if (queue == null || queue.isEmpty) {
        return {'connectionId': connectionId, 'messages': []};
      }
      
      // Return and clear the queue
      final messages = List<Map<String, dynamic>>.from(queue);
      queue.clear();
      
      return {'connectionId': connectionId, 'messages': messages};
    });
  }

  /// Poll for pending status changes (macOS compatible approach)
  void _registerPollStatus() {
    addHandler('Ondes.Websocket.pollStatus', (args) async {
      if (args.isEmpty) {
        throw Exception('Connection ID is required');
      }
      
      final connectionId = args[0] as String;
      final queue = _statusQueues[connectionId];
      
      if (queue == null || queue.isEmpty) {
        return {'connectionId': connectionId, 'statusChanges': []};
      }
      
      // Return and clear the queue
      final statusChanges = List<Map<String, dynamic>>.from(queue);
      queue.clear();
      
      return {'connectionId': connectionId, 'statusChanges': statusChanges};
    });
  }

  /// Handle incoming messages
  void _handleMessage(String connectionId, dynamic message) {
    debugPrint('[WebsocketHandler] Message from $connectionId: $message');

    // Queue the message for polling (macOS compatible approach)
    _messageQueues.putIfAbsent(connectionId, () => []);
    _messageQueues[connectionId]!.add({
      'message': message.toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Handle connection errors
  void _handleError(String connectionId, dynamic error) {
    debugPrint('[WebsocketHandler] Error on $connectionId: $error');

    final connection = _connections[connectionId];
    if (connection != null) {
      connection.status = WebsocketStatus.error;
      _notifyStatusChange(connectionId, 'error', error.toString());

      // Attempt reconnection if enabled
      if (connection.reconnect) {
        _attemptReconnection(connectionId);
      }
    }
  }

  /// Handle connection closed
  void _handleClosed(String connectionId) {
    debugPrint('[WebsocketHandler] Connection closed: $connectionId');

    final connection = _connections[connectionId];
    if (connection != null) {
      final wasConnected = connection.status == WebsocketStatus.connected;
      connection.status = WebsocketStatus.disconnected;
      _notifyStatusChange(connectionId, 'disconnected', null);

      // Attempt reconnection if enabled and was previously connected
      if (connection.reconnect && wasConnected) {
        _attemptReconnection(connectionId);
      }
    }
  }

  /// Notify JavaScript of status changes (uses queue for macOS compatibility)
  void _notifyStatusChange(String connectionId, String status, String? error) {
    debugPrint('[WebsocketHandler] Status change for $connectionId: $status');
    
    // Queue the status change for polling
    _statusQueues.putIfAbsent(connectionId, () => []);
    _statusQueues[connectionId]!.add({
      'status': status,
      'error': error,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Attempt to reconnect
  void _attemptReconnection(String connectionId) async {
    final connection = _connections[connectionId];
    if (connection == null) return;

    connection.status = WebsocketStatus.reconnecting;
    _notifyStatusChange(connectionId, 'reconnecting', null);

    // Wait before reconnecting
    await Future.delayed(const Duration(seconds: 3));

    // Check if still should reconnect
    if (!_connections.containsKey(connectionId)) return;
    if (connection.status == WebsocketStatus.connected) return;

    try {
      debugPrint('[WebsocketHandler] Reconnecting: $connectionId');

      final uri = Uri.parse(connection.url);
      final channel = WebSocketChannel.connect(uri);

      await channel.ready.timeout(
        Duration(milliseconds: connection.timeout),
      );

      // Cancel old subscription
      await connection.subscription?.cancel();

      // Update connection
      connection.channel = channel;
      connection.status = WebsocketStatus.connected;
      connection.connectedAt = DateTime.now();

      // Set up new listener
      connection.subscription = channel.stream.listen(
        (message) => _handleMessage(connectionId, message),
        onError: (error) => _handleError(connectionId, error),
        onDone: () => _handleClosed(connectionId),
      );

      _notifyStatusChange(connectionId, 'connected', null);
      debugPrint('[WebsocketHandler] Reconnected: $connectionId');
    } catch (e) {
      debugPrint('[WebsocketHandler] Reconnection failed: $e');
      connection.status = WebsocketStatus.error;
      _notifyStatusChange(connectionId, 'error', e.toString());

      // Try again
      if (connection.reconnect) {
        _attemptReconnection(connectionId);
      }
    }
  }

  /// Close a connection
  Future<void> _closeConnection(String connectionId) async {
    final connection = _connections.remove(connectionId);
    if (connection != null) {
      connection.reconnect = false; // Prevent auto-reconnection
      await connection.subscription?.cancel();
      await connection.channel.sink.close();
      debugPrint('[WebsocketHandler] Disconnected: $connectionId');
    }
  }

  /// Clean up all connections when handler is disposed
  void dispose() {
    // Stop all message/status queues
    _messageQueues.clear();
    _statusQueues.clear();
    
    for (final id in _connections.keys.toList()) {
      _closeConnection(id);
    }
  }
}

/// Internal WebSocket connection state
class _WebsocketConnection {
  final String id;
  final String url;
  WebSocketChannel channel;
  WebsocketStatus status;
  DateTime? connectedAt;
  bool reconnect;
  final int timeout;
  StreamSubscription? subscription;

  _WebsocketConnection({
    required this.id,
    required this.url,
    required this.channel,
    required this.status,
    required this.reconnect,
    required this.timeout,
    this.connectedAt,
  });
}

/// WebSocket connection status
enum WebsocketStatus {
  connecting,
  connected,
  disconnected,
  reconnecting,
  error,
}
