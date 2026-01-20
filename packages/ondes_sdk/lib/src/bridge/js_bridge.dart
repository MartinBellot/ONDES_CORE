import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Low-level bridge to communicate with the native Ondes Core via JavaScript.
///
/// This class handles the communication between Flutter Web and the
/// injected `window.Ondes` JavaScript object from the host application.
class OndesJsBridge {
  OndesJsBridge._();

  static final OndesJsBridge instance = OndesJsBridge._();

  Completer<void>? _readyCompleter;
  bool _isReady = false;

  /// Whether the Ondes bridge is ready to use.
  bool get isReady => _isReady;

  /// Ensures the bridge is ready before making any calls.
  ///
  /// This waits for the `OndesReady` event dispatched by the host app.
  Future<void> ensureReady() async {
    if (_isReady) return;

    if (_readyCompleter != null) {
      return _readyCompleter!.future;
    }

    _readyCompleter = Completer<void>();

    // Check if Ondes is already available
    if (_isOndesAvailable()) {
      _isReady = true;
      _readyCompleter!.complete();
      return;
    }

    // Listen for the OndesReady event
    _listenForOndesReady();

    return _readyCompleter!.future;
  }

  /// Check if window.Ondes exists
  bool _isOndesAvailable() {
    return _getOndesObject() != null;
  }

  /// Listen for the OndesReady event
  void _listenForOndesReady() {
    final callback = ((JSObject event) {
      _isReady = true;
      _readyCompleter?.complete();
    }).toJS;

    _addEventListenerToDocument('OndesReady', callback);

    // Timeout after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (!_isReady && _readyCompleter != null && !_readyCompleter!.isCompleted) {
        _readyCompleter!.completeError(
          const OndesBridgeException(
            code: 'TIMEOUT',
            message: 'Ondes bridge not ready after 10 seconds. '
                'Make sure this app is running inside the Ondes Core host.',
          ),
        );
      }
    });
  }

  /// Calls a method on the Ondes bridge.
  ///
  /// [handlerName] is the full handler name (e.g., 'Ondes.UI.showToast').
  /// [args] are the arguments to pass to the handler.
  Future<T?> call<T>(String handlerName, [List<dynamic>? args]) async {
    if (!_isReady) {
      await ensureReady();
    }

    try {
      final result = await _callHandler(handlerName, args ?? []);
      return _convertFromJs<T>(result);
    } catch (e) {
      if (e is OndesBridgeException) rethrow;
      throw OndesBridgeException(
        code: 'CALL_FAILED',
        message: 'Failed to call $handlerName: $e',
      );
    }
  }

  /// Internal method to call a JavaScript handler
  Future<JSAny?> _callHandler(String handlerName, List<dynamic> args) async {
    final parts = handlerName.split('.');
    if (parts.length < 2) {
      throw const OndesBridgeException(
        code: 'INVALID_HANDLER',
        message: 'Invalid handler name',
      );
    }

    // Navigate to the correct module (e.g., Ondes.UI.showToast)
    final ondes = _getOndesObject();
    if (ondes == null) {
      throw const OndesBridgeException(
        code: 'NOT_AVAILABLE',
        message: 'Ondes bridge is not available',
      );
    }

    // Get the module (UI, User, Device, etc.)
    final moduleName = parts[1];
    final module = ondes[moduleName] as JSObject?;
    if (module == null) {
      throw OndesBridgeException(
        code: 'MODULE_NOT_FOUND',
        message: 'Module $moduleName not found',
      );
    }

    // Get the method
    final methodName = parts.length > 2 ? parts[2] : parts[1];
    final method = module[methodName] as JSFunction?;
    if (method == null) {
      throw OndesBridgeException(
        code: 'METHOD_NOT_FOUND',
        message: 'Method $methodName not found in module $moduleName',
      );
    }

    // Convert args to JS and call
    final jsArgs = args.map(_convertToJs).toList();
    final JSAny? result;

    switch (jsArgs.length) {
      case 0:
        result = method.callAsFunction(module);
      case 1:
        result = method.callAsFunction(module, jsArgs[0]);
      case 2:
        result = method.callAsFunction(module, jsArgs[0], jsArgs[1]);
      case 3:
        result = method.callAsFunction(module, jsArgs[0], jsArgs[1], jsArgs[2]);
      default:
        // For more args, we need a different approach
        result = method.callAsFunction(module, jsArgs[0], jsArgs[1], jsArgs[2], jsArgs[3]);
    }

    // If result is a Promise, await it
    if (result != null && result.isA<JSPromise>()) {
      return (result as JSPromise).toDart;
    }

    return result;
  }

  /// Get the window.Ondes object
  JSObject? _getOndesObject() {
    return globalContext['Ondes'] as JSObject?;
  }

  /// Convert a Dart value to JS
  JSAny? _convertToJs(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.toJS;
    if (value is int) return value.toJS;
    if (value is double) return value.toJS;
    if (value is bool) return value.toJS;
    if (value is List) {
      return value.map(_convertToJs).toList().toJS;
    }
    if (value is Map<String, dynamic>) {
      return _mapToJsObject(value);
    }
    return value.toString().toJS;
  }

  /// Convert a Map to a JSObject
  JSObject _mapToJsObject(Map<String, dynamic> map) {
    final obj = _createJsObject();
    for (final entry in map.entries) {
      obj[entry.key] = _convertToJs(entry.value);
    }
    return obj;
  }

  /// Convert a JS value to Dart
  T? _convertFromJs<T>(JSAny? value) {
    if (value == null) return null;

    if (value.isA<JSString>()) {
      return (value as JSString).toDart as T;
    }
    if (value.isA<JSNumber>()) {
      final num = (value as JSNumber).toDartDouble;
      if (T == int) return num.toInt() as T;
      return num as T;
    }
    if (value.isA<JSBoolean>()) {
      return (value as JSBoolean).toDart as T;
    }
    if (value.isA<JSArray>()) {
      return _jsArrayToList(value as JSArray) as T;
    }
    if (value.isA<JSObject>()) {
      return _jsObjectToMap(value as JSObject) as T;
    }

    return null;
  }

  /// Convert a JSArray to a Dart List
  List<dynamic> _jsArrayToList(JSArray array) {
    final result = <dynamic>[];
    final jsObj = array as JSObject;
    final length = (jsObj['length'] as JSNumber).toDartInt;
    for (var i = 0; i < length; i++) {
      final item = jsObj[i.toString()];
      result.add(_convertFromJs<dynamic>(item));
    }
    return result;
  }

  /// Convert a JSObject to a Dart Map
  Map<String, dynamic> _jsObjectToMap(JSObject obj) {
    final result = <String, dynamic>{};
    final keys = _getObjectKeys(obj);
    for (final key in keys) {
      final value = obj[key];
      result[key] = _convertFromJs<dynamic>(value);
    }
    return result;
  }

  /// Get object keys using Object.keys()
  List<String> _getObjectKeys(JSObject obj) {
    final objectConstructor = globalContext['Object'] as JSObject;
    final keysMethod = objectConstructor['keys'] as JSFunction;
    final keysArray = keysMethod.callAsFunction(objectConstructor, obj) as JSArray;
    return _jsArrayToList(keysArray).cast<String>();
  }

  /// Create an empty JS object
  JSObject _createJsObject() {
    final objectConstructor = globalContext['Object'] as JSFunction;
    return objectConstructor.callAsConstructor<JSObject>();
  }

  /// Add event listener to document
  void _addEventListenerToDocument(String event, JSFunction callback) {
    final document = globalContext['document'] as JSObject;
    final addEventListener = document['addEventListener'] as JSFunction;
    addEventListener.callAsFunction(document, event.toJS, callback);
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

/// Global context (window object)
@JS('globalThis')
external JSObject get globalContext;
