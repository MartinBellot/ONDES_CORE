/// UDP module for network discovery and communication.
///
/// This file provides conditional exports for web vs non-web platforms.
/// On web, it uses dart:js_interop to communicate with the host app.
/// On non-web platforms, it provides stub implementations that throw errors.
library;

export 'udp_stub.dart'
    if (dart.library.js_interop) 'udp_web.dart';
