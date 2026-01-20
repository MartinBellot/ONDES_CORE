import 'dart:async';
import '../bridge/js_bridge.dart';
import '../models/udp_socket.dart';

/// Stub implementation of UDP module for non-web platforms.
/// 
/// This SDK is designed to work only on web platform inside the Ondes Core host.
/// On non-web platforms, all methods will throw [UnsupportedError].
class OndesUdp {
  // ignore: unused_field - required for API compatibility
  final OndesJsBridge _bridge;

  /// Stream controllers for message events per socket
  final Map<String, StreamController<UdpMessage>> _messageControllers = {};

  /// Stream controllers for close events per socket
  final Map<String, StreamController<String>> _closeControllers = {};

  OndesUdp(this._bridge);

  /// Bind to a UDP port and start listening.
  /// 
  /// On non-web platforms, this will always throw [UnsupportedError].
  Future<UdpSocket> bind({UdpBindOptions? options}) async {
    throw UnsupportedError(
      'Ondes SDK UDP is only supported on web platform. '
      'This app must run inside the Ondes Core host.',
    );
  }

  /// Send a UDP message to a specific address and port.
  /// 
  /// On non-web platforms, this will always throw [UnsupportedError].
  Future<UdpSendResult> send(
    String socketId,
    String message,
    String address,
    int port,
  ) async {
    throw UnsupportedError(
      'Ondes SDK UDP is only supported on web platform. '
      'This app must run inside the Ondes Core host.',
    );
  }

  /// Broadcast a UDP message to multiple addresses.
  /// 
  /// On non-web platforms, this will always throw [UnsupportedError].
  Future<UdpBroadcastResult> broadcast(
    String socketId,
    String message,
    List<String> addresses, [
    int port = 12345,
  ]) async {
    throw UnsupportedError(
      'Ondes SDK UDP is only supported on web platform. '
      'This app must run inside the Ondes Core host.',
    );
  }

  /// Close a UDP socket.
  /// 
  /// On non-web platforms, this will always throw [UnsupportedError].
  Future<void> close(String socketId) async {
    throw UnsupportedError(
      'Ondes SDK UDP is only supported on web platform. '
      'This app must run inside the Ondes Core host.',
    );
  }

  /// Get info about a UDP socket.
  /// 
  /// On non-web platforms, this will always throw [UnsupportedError].
  Future<UdpSocket> getInfo(String socketId) async {
    throw UnsupportedError(
      'Ondes SDK UDP is only supported on web platform. '
      'This app must run inside the Ondes Core host.',
    );
  }

  /// List all active UDP sockets.
  /// 
  /// On non-web platforms, this will always throw [UnsupportedError].
  Future<List<UdpSocket>> list() async {
    throw UnsupportedError(
      'Ondes SDK UDP is only supported on web platform. '
      'This app must run inside the Ondes Core host.',
    );
  }

  /// Close all UDP sockets.
  /// 
  /// On non-web platforms, this will always throw [UnsupportedError].
  Future<int> closeAll() async {
    throw UnsupportedError(
      'Ondes SDK UDP is only supported on web platform. '
      'This app must run inside the Ondes Core host.',
    );
  }

  /// Stream of incoming UDP messages for a socket.
  Stream<UdpMessage> onMessage(String socketId) {
    if (!_messageControllers.containsKey(socketId)) {
      _messageControllers[socketId] = StreamController<UdpMessage>.broadcast();
    }
    return _messageControllers[socketId]!.stream;
  }

  /// Stream of socket close events.
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
