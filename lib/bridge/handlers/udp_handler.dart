import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'base_handler.dart';

/// Handler for Ondes.UDP namespace
/// Manages UDP socket communications for mini-apps (discovery, broadcast, etc.)
class UdpHandler extends BaseHandler {
  UdpHandler(BuildContext context) : super(context);

  /// Active UDP sockets
  final Map<String, _UdpSocket> _sockets = {};

  /// Counter for generating unique socket IDs
  int _socketCounter = 0;

  @override
  void registerHandlers() {
    _registerBind();
    _registerSend();
    _registerBroadcast();
    _registerClose();
    _registerGetInfo();
    _registerList();
    _registerCloseAll();
  }

  /// Generate a unique socket ID
  String _generateSocketId() {
    _socketCounter++;
    return 'udp_${DateTime.now().millisecondsSinceEpoch}_$_socketCounter';
  }

  /// Bind to a UDP port and start listening
  void _registerBind() {
    addHandler('Ondes.UDP.bind', (args) async {
      final options = args.isNotEmpty && args[0] is Map
          ? Map<String, dynamic>.from(args[0] as Map)
          : <String, dynamic>{};

      final port = options['port'] as int? ?? 0; // 0 = random port
      final broadcast = options['broadcast'] as bool? ?? true;
      final reuseAddress = options['reuseAddress'] as bool? ?? true;

      final socketId = _generateSocketId();

      try {
        final socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          port,
          reuseAddress: reuseAddress,
        );

        socket.broadcastEnabled = broadcast;

        final udpSocket = _UdpSocket(
          id: socketId,
          socket: socket,
          port: socket.port,
          broadcast: broadcast,
          createdAt: DateTime.now(),
        );

        _sockets[socketId] = udpSocket;

        // Set up message listener
        udpSocket.subscription = socket.listen((event) {
          if (event == RawSocketEvent.read) {
            final datagram = socket.receive();
            if (datagram != null) {
              _handleMessage(socketId, datagram);
            }
          }
        });

        debugPrint('[UdpHandler] Socket bound: $socketId on port ${socket.port}');

        return {
          'id': socketId,
          'port': socket.port,
          'broadcast': broadcast,
          'status': 'bound',
        };
      } catch (e) {
        debugPrint('[UdpHandler] Bind failed: $e');
        throw Exception('Failed to bind UDP socket: $e');
      }
    });
  }

  /// Send a UDP message to a specific address and port
  void _registerSend() {
    addHandler('Ondes.UDP.send', (args) async {
      if (args.isEmpty) {
        throw Exception('Socket ID is required');
      }

      final socketId = args[0] as String;
      final message = args.length > 1 ? args[1] : null;
      final address = args.length > 2 ? args[2] as String : null;
      final port = args.length > 3 ? args[3] as int : null;

      if (message == null || address == null || port == null) {
        throw Exception('Message, address, and port are required');
      }

      final udpSocket = _sockets[socketId];
      if (udpSocket == null) {
        throw Exception('Socket not found: $socketId');
      }

      try {
        final data = message is String
            ? utf8.encode(message)
            : (message is List<int> ? message : utf8.encode(message.toString()));

        final bytesSent = udpSocket.socket.send(
          data,
          InternetAddress(address),
          port,
        );

        debugPrint('[UdpHandler] Sent $bytesSent bytes to $address:$port');

        return {
          'success': true,
          'bytesSent': bytesSent,
          'address': address,
          'port': port,
        };
      } catch (e) {
        debugPrint('[UdpHandler] Send failed: $e');
        // Return success false instead of throwing to handle network unreachable
        return {
          'success': false,
          'error': e.toString(),
          'address': address,
          'port': port,
        };
      }
    });
  }

  /// Broadcast a UDP message to multiple addresses
  void _registerBroadcast() {
    addHandler('Ondes.UDP.broadcast', (args) async {
      if (args.isEmpty) {
        throw Exception('Socket ID is required');
      }

      final socketId = args[0] as String;
      final message = args.length > 1 ? args[1] : null;
      final addresses = args.length > 2 && args[2] is List
          ? List<String>.from(args[2] as List)
          : <String>[];
      final port = args.length > 3 ? args[3] as int : 12345;

      if (message == null) {
        throw Exception('Message is required');
      }

      final udpSocket = _sockets[socketId];
      if (udpSocket == null) {
        throw Exception('Socket not found: $socketId');
      }

      final data = message is String
          ? utf8.encode(message)
          : (message is List<int> ? message : utf8.encode(message.toString()));

      final results = <Map<String, dynamic>>[];

      for (final address in addresses) {
        try {
          final bytesSent = udpSocket.socket.send(
            data,
            InternetAddress(address),
            port,
          );
          results.add({
            'address': address,
            'success': true,
            'bytesSent': bytesSent,
          });
        } catch (e) {
          results.add({
            'address': address,
            'success': false,
            'error': e.toString(),
          });
        }
      }

      debugPrint('[UdpHandler] Broadcast to ${addresses.length} addresses');

      return {
        'socketId': socketId,
        'messageLength': data.length,
        'port': port,
        'results': results,
      };
    });
  }

  /// Close a UDP socket
  void _registerClose() {
    addHandler('Ondes.UDP.close', (args) async {
      if (args.isEmpty) {
        throw Exception('Socket ID is required');
      }

      final socketId = args[0] as String;
      final udpSocket = _sockets[socketId];

      if (udpSocket == null) {
        throw Exception('Socket not found: $socketId');
      }

      await _closeSocket(socketId);

      return {
        'id': socketId,
        'status': 'closed',
      };
    });
  }

  /// Get info about a UDP socket
  void _registerGetInfo() {
    addHandler('Ondes.UDP.getInfo', (args) async {
      if (args.isEmpty) {
        throw Exception('Socket ID is required');
      }

      final socketId = args[0] as String;
      final udpSocket = _sockets[socketId];

      if (udpSocket == null) {
        throw Exception('Socket not found: $socketId');
      }

      return {
        'id': socketId,
        'port': udpSocket.port,
        'broadcast': udpSocket.broadcast,
        'createdAt': udpSocket.createdAt.millisecondsSinceEpoch,
        'messagesReceived': udpSocket.messagesReceived,
      };
    });
  }

  /// List all active UDP sockets
  void _registerList() {
    addHandler('Ondes.UDP.list', (args) async {
      return _sockets.values.map((socket) => {
        'id': socket.id,
        'port': socket.port,
        'broadcast': socket.broadcast,
        'createdAt': socket.createdAt.millisecondsSinceEpoch,
        'messagesReceived': socket.messagesReceived,
      }).toList();
    });
  }

  /// Close all UDP sockets
  void _registerCloseAll() {
    addHandler('Ondes.UDP.closeAll', (args) async {
      final count = _sockets.length;
      final ids = _sockets.keys.toList();

      for (final id in ids) {
        await _closeSocket(id);
      }

      debugPrint('[UdpHandler] Closed all sockets ($count)');

      return {
        'closedCount': count,
      };
    });
  }

  /// Handle incoming UDP message
  void _handleMessage(String socketId, Datagram datagram) {
    final udpSocket = _sockets[socketId];
    if (udpSocket == null) return;

    udpSocket.messagesReceived++;

    final message = utf8.decode(datagram.data, allowMalformed: true);
    final senderAddress = datagram.address.address;
    final senderPort = datagram.port;

    debugPrint('[UdpHandler] Received from $senderAddress:$senderPort: $message');

    // Escape message for JavaScript
    final escapedMessage = message
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');

    // Push message event to JavaScript via evaluateJavascript
    webViewController?.evaluateJavascript(source: '''
      (function() {
        if (window.Ondes && window.Ondes.UDP && window.Ondes.UDP._onMessage) {
          window.Ondes.UDP._onMessage({
            socketId: "$socketId",
            message: "$escapedMessage",
            address: "$senderAddress",
            port: $senderPort,
            timestamp: ${DateTime.now().millisecondsSinceEpoch}
          });
        }
      })();
    ''');
  }

  /// Close a socket and clean up
  Future<void> _closeSocket(String socketId) async {
    final udpSocket = _sockets[socketId];
    if (udpSocket == null) return;

    await udpSocket.subscription?.cancel();
    udpSocket.socket.close();
    _sockets.remove(socketId);

    debugPrint('[UdpHandler] Socket closed: $socketId');

    // Push close event to JavaScript via evaluateJavascript
    webViewController?.evaluateJavascript(source: '''
      (function() {
        if (window.Ondes && window.Ondes.UDP && window.Ondes.UDP._onClose) {
          window.Ondes.UDP._onClose({
            socketId: "$socketId",
            timestamp: ${DateTime.now().millisecondsSinceEpoch}
          });
        }
      })();
    ''');
  }

  /// Clean up all sockets when handler is destroyed
  void disposeHandler() {
    for (final id in _sockets.keys.toList()) {
      _closeSocket(id);
    }
  }
}

/// Internal class to track UDP socket state
class _UdpSocket {
  final String id;
  final RawDatagramSocket socket;
  final int port;
  final bool broadcast;
  final DateTime createdAt;
  StreamSubscription<RawSocketEvent>? subscription;
  int messagesReceived = 0;

  _UdpSocket({
    required this.id,
    required this.socket,
    required this.port,
    required this.broadcast,
    required this.createdAt,
  });
}
