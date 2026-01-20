/// Low-level bridge to communicate with the native Ondes Core via JavaScript.
///
/// This file provides conditional exports for web vs non-web platforms.
/// On web, it uses dart:js_interop to communicate with the host app.
/// On non-web platforms, it provides stub implementations that throw errors.
library;

export 'js_bridge_stub.dart'
    if (dart.library.js_interop) 'js_bridge_web.dart';
