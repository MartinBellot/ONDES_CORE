import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import '../bridge/js_bridge.dart';
import '../models/udp_socket.dart';

/// UDP module for network discovery and communication.
///
/// Allows mini-apps to bind UDP sockets, send/broadcast messages,
/// and listen for incoming packets through the native Ondes bridge.
///
/// ## Example
/// ```dart
/// // Bind to a port
/// final socket = await Ondes.udp.bind(
///   options: UdpBindOptions(port: 12345, broadcast: true),
/// );
///
/// // Listen for messages
/// Ondes.udp.onMessage(socket.id).listen((message) {
///   print('Received from \${message.address}: \${message.message}');
/// });
///
/// // Send a message
/// await Ondes.udp.send(socket.id, 'DISCOVER_ROBOT', '192.168.1.255', 12345);
///
/// // Broadcast to multiple addresses
/// await Ondes.udp.broadcast(
///   socket.id,
///   'DISCOVER_ROBOT',
///   ['192.168.1.255', '192.168.4.255'],
///   12345,
/// );
///
/// // Close the socket
/// await Ondes.udp.close(socket.id);
/// ```
class OndesUdp {
  final OndesJsBridge _bridge;

  /// Stream controllers for message events per socket
  final Map<String, StreamController<UdpMessage>> _messageControllers = {};

  /// Stream controllers for close events per socket
  final Map<String, StreamController<String>> _closeControllers = {};
  
  /// JS callback unsubscribers per socket
  final Map<String, JSFunction?> _jsUnsubscribers = {};

  OndesUdp(this._bridge);

  /// Bind to a UDP port and start listening.
  ///
  /// [options] Bind configuration options
  ///
  /// Returns the created [UdpSocket] with its assigned ID and port.
  ///
  /// Throws [OndesBridgeException] if binding fails.
  Future<UdpSocket> bind({UdpBindOptions? options}) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.UDP.bind',
      [options?.toJson() ?? {}],
    );

    if (result == null) {
      throw const OndesBridgeException(
        code: 'BIND_FAILED',
        message: 'Failed to bind UDP socket',
      );
    }

    final socket = UdpSocket.fromJson(result);

    // Initialize stream controllers for this socket
    _messageControllers[socket.id] = StreamController<UdpMessage>.broadcast();
    _closeControllers[socket.id] = StreamController<String>.broadcast();

    // Register JS callback for messages
    _registerJsCallbacks(socket.id);

    return socket;
  }

  /// Register JavaScript callbacks to receive UDP messages
  void _registerJsCallbacks(String socketId) {
    // Create a Dart callback that will be called from JS
    final dartCallback = ((JSObject data) {
      try {
        final messageData = _jsObjectToMap(data);
        
        // Safely parse port (could be int or double from JS)
        int port = 0;
        final portValue = messageData['port'];
        if (portValue is num) {
          port = portValue.toInt();
        }
        
        // Safely parse timestamp
        DateTime timestamp = DateTime.now();
        final timestampValue = messageData['timestamp'];
        if (timestampValue is num) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue.toInt());
        }
        
        final message = UdpMessage(
          socketId: messageData['socketId'] as String? ?? socketId,
          message: messageData['message'] as String? ?? '',
          address: messageData['address'] as String? ?? '',
          port: port,
          timestamp: timestamp,
        );
        _messageControllers[socketId]?.add(message);
      } catch (e) {
        // ignore parse errors
      }
    }).toJS;

    // Get Ondes.UDP module and call onMessage to register
    final ondes = globalContext['Ondes'] as JSObject?;
    if (ondes == null) return;

    final udpModule = ondes['UDP'] as JSObject?;
    if (udpModule == null) return;

    final onMessageMethod = udpModule['onMessage'] as JSFunction?;
    if (onMessageMethod == null) return;

    // Register the callback and store unsubscriber
    final unsubscriber = onMessageMethod.callAsFunction(
      udpModule,
      socketId.toJS,
      dartCallback,
    );
    
    if (unsubscriber != null && unsubscriber.isA<JSFunction>()) {
      _jsUnsubscribers[socketId] = unsubscriber as JSFunction;
    }
  }

  /// Convert a JSObject to a Dart Map
  Map<String, dynamic> _jsObjectToMap(JSObject obj) {
    final result = <String, dynamic>{};
    final objectConstructor = globalContext['Object'] as JSObject;
    final keysMethod = objectConstructor['keys'] as JSFunction;
    final keysArray = keysMethod.callAsFunction(objectConstructor, obj) as JSArray;
    
    final length = ((keysArray as JSObject)['length'] as JSNumber).toDartInt;
    for (var i = 0; i < length; i++) {
      final key = ((keysArray as JSObject)[i.toString()] as JSString).toDart;
      final value = obj[key];
      if (value == null) {
        result[key] = null;
      } else if (value.isA<JSString>()) {
        result[key] = (value as JSString).toDart;
      } else if (value.isA<JSNumber>()) {
        result[key] = (value as JSNumber).toDartDouble;
      } else if (value.isA<JSBoolean>()) {
        result[key] = (value as JSBoolean).toDart;
      }
    }
    return result;
  }

  /// Send a UDP message to a specific address and port.
  ///
  /// [socketId] The socket ID returned by [bind]
  /// [message] The message to send
  /// [address] Target IP address
  /// [port] Target port
  ///
  /// Returns the send result with success status.
  Future<UdpSendResult> send(
    String socketId,
    String message,
    String address,
    int port,
  ) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.UDP.send',
      [socketId, message, address, port],
    );

    if (result == null) {
      return UdpSendResult(
        success: false,
        address: address,
        port: port,
        error: 'No result returned',
      );
    }

    return UdpSendResult.fromJson(result);
  }

  /// Broadcast a UDP message to multiple addresses.
  ///
  /// [socketId] The socket ID
  /// [message] The message to send
  /// [addresses] List of target IP addresses
  /// [port] Target port (default: 12345)
  ///
  /// Returns broadcast results for each address.
  Future<UdpBroadcastResult> broadcast(
    String socketId,
    String message,
    List<String> addresses, [
    int port = 12345,
  ]) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.UDP.broadcast',
      [socketId, message, addresses, port],
    );

    if (result == null) {
      throw const OndesBridgeException(
        code: 'BROADCAST_FAILED',
        message: 'Failed to broadcast UDP message',
      );
    }

    return UdpBroadcastResult.fromJson(result);
  }

  /// Close a UDP socket.
  ///
  /// [socketId] The socket ID to close
  Future<void> close(String socketId) async {
    // Call the JS unsubscriber if available
    final unsubscriber = _jsUnsubscribers[socketId];
    if (unsubscriber != null) {
      unsubscriber.callAsFunction(null);
    }
    _jsUnsubscribers.remove(socketId);

    await _bridge.call<Map<String, dynamic>>(
      'Ondes.UDP.close',
      [socketId],
    );

    // Clean up controllers
    _messageControllers[socketId]?.close();
    _messageControllers.remove(socketId);
    _closeControllers[socketId]?.close();
    _closeControllers.remove(socketId);
  }

  /// Get info about a UDP socket.
  ///
  /// [socketId] The socket ID
  ///
  /// Returns socket information.
  Future<UdpSocket> getInfo(String socketId) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.UDP.getInfo',
      [socketId],
    );

    if (result == null) {
      throw OndesBridgeException(
        code: 'SOCKET_NOT_FOUND',
        message: 'Socket not found: $socketId',
      );
    }

    return UdpSocket.fromJson(result);
  }

  /// List all active UDP sockets.
  ///
  /// Returns a list of all bound sockets.
  Future<List<UdpSocket>> list() async {
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.UDP.list',
      [],
    );

    if (result == null) return [];

    return result
        .map((item) => UdpSocket.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Close all UDP sockets.
  ///
  /// Returns the number of closed sockets.
  Future<int> closeAll() async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.UDP.closeAll',
      [],
    );

    // Clean up all controllers
    for (final controller in _messageControllers.values) {
      controller.close();
    }
    _messageControllers.clear();
    for (final controller in _closeControllers.values) {
      controller.close();
    }
    _closeControllers.clear();

    return (result?['closedCount'] as int?) ?? 0;
  }

  /// Stream of incoming UDP messages for a socket.
  ///
  /// [socketId] The socket ID
  ///
  /// Returns a stream of [UdpMessage] events.
  ///
  /// Note: Messages are pushed from the native side. Make sure to
  /// subscribe before expecting messages.
  Stream<UdpMessage> onMessage(String socketId) {
    if (!_messageControllers.containsKey(socketId)) {
      _messageControllers[socketId] = StreamController<UdpMessage>.broadcast();
    }
    return _messageControllers[socketId]!.stream;
  }

  /// Stream of socket close events.
  ///
  /// [socketId] The socket ID
  ///
  /// Returns a stream that emits the socket ID when closed.
  Stream<String> onClose(String socketId) {
    if (!_closeControllers.containsKey(socketId)) {
      _closeControllers[socketId] = StreamController<String>.broadcast();
    }
    return _closeControllers[socketId]!.stream;
  }

  /// Push a message event from native side.
  /// Called internally by the bridge.
  void pushMessage(UdpMessage message) {
    _messageControllers[message.socketId]?.add(message);
  }

  /// Push a close event from native side.
  /// Called internally by the bridge.
  void pushClose(String socketId) {
    _closeControllers[socketId]?.add(socketId);
    _messageControllers[socketId]?.close();
    _messageControllers.remove(socketId);
    _closeControllers[socketId]?.close();
    _closeControllers.remove(socketId);
  }
}

/// Exception thrown when UDP operations fail.
class OndesBridgeException implements Exception {
  final String code;
  final String message;

  const OndesBridgeException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'OndesBridgeException: [$code] $message';
}
