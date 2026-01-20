import 'dart:async';

/// Stub implementation of OndesJsBridge for non-web platforms.
/// 
/// This SDK is designed to work only on web platform inside the Ondes Core host.
/// On non-web platforms, all methods will throw [UnsupportedError].
class OndesJsBridge {
  OndesJsBridge._();

  static final OndesJsBridge instance = OndesJsBridge._();

  /// Whether the Ondes bridge is ready to use.
  /// Always returns false on non-web platforms.
  bool get isReady => false;

  /// Ensures the bridge is ready before making any calls.
  /// 
  /// On non-web platforms, this will always throw [UnsupportedError].
  Future<void> ensureReady() async {
    throw UnsupportedError(
      'Ondes SDK is only supported on web platform. '
      'This app must run inside the Ondes Core host.',
    );
  }

  /// Calls a method on the Ondes bridge.
  /// 
  /// On non-web platforms, this will always throw [UnsupportedError].
  Future<T?> call<T>(String handlerName, [List<dynamic>? args]) async {
    throw UnsupportedError(
      'Ondes SDK is only supported on web platform. '
      'This app must run inside the Ondes Core host.',
    );
  }
}

/// Exception thrown when bridge operations fail
class OndesBridgeException implements Exception {
  final String code;
  final String message;

  const OndesBridgeException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'OndesBridgeException($code): $message';
}
