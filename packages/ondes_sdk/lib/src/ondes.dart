import 'modules/ui.dart';
import 'modules/user.dart';
import 'modules/device.dart';
import 'modules/storage.dart';
import 'modules/app.dart';
import 'modules/friends.dart';
import 'modules/social.dart';
import 'modules/websocket.dart';
import 'bridge/js_bridge.dart';

/// Main entry point for the Ondes SDK.
///
/// Provides access to all Ondes modules for communicating with
/// the native host application.
///
/// ## Example
/// ```dart
/// await Ondes.ensureReady();
///
/// await Ondes.ui.showToast(message: "Hello!");
/// final profile = await Ondes.user.getProfile();
/// ```
class Ondes {
  Ondes._();

  static final OndesJsBridge _bridge = OndesJsBridge.instance;

  // Module instances (lazy singletons)
  static OndesUI? _ui;
  static OndesUser? _user;
  static OndesDevice? _device;
  static OndesStorage? _storage;
  static OndesApp? _app;
  static OndesFriends? _friends;
  static OndesSocial? _social;
  static OndesWebsocket? _websocket;

  /// Whether the Ondes bridge is ready to use.
  static bool get isReady => _bridge.isReady;

  /// Ensures the bridge is ready before making any calls.
  ///
  /// This should be called at app startup before using any Ondes features.
  /// It waits for the `OndesReady` event from the host application.
  ///
  /// ```dart
  /// void main() async {
  ///   await Ondes.ensureReady();
  ///   // Now safe to use Ondes modules
  /// }
  /// ```
  static Future<void> ensureReady() => _bridge.ensureReady();

  /// UI module for native interface controls.
  ///
  /// Provides toasts, alerts, confirmations, bottom sheets, and app bar configuration.
  static OndesUI get ui => _ui ??= OndesUI(_bridge);

  /// User module for authentication and profile.
  ///
  /// Get current user info, auth token, and authentication status.
  static OndesUser get user => _user ??= OndesUser(_bridge);

  /// Device module for hardware access.
  ///
  /// Provides haptic feedback, vibration, QR scanner, GPS, and device info.
  static OndesDevice get device => _device ??= OndesDevice(_bridge);

  /// Storage module for persistent data.
  ///
  /// Key-value storage scoped to the mini-app.
  static OndesStorage get storage => _storage ??= OndesStorage(_bridge);

  /// App module for mini-app lifecycle.
  ///
  /// Get app info, manifest, and close the mini-app.
  static OndesApp get app => _app ??= OndesApp(_bridge);

  /// Friends module for social relationships.
  ///
  /// Manage friend lists, requests, blocks, and search users.
  static OndesFriends get friends => _friends ??= OndesFriends(_bridge);

  /// Social module for feed and posts.
  ///
  /// Posts, likes, comments, stories, follows, and more.
  static OndesSocial get social => _social ??= OndesSocial(_bridge);

  /// WebSocket module for real-time communication.
  ///
  /// Manage WebSocket connections for real-time data exchange.
  static OndesWebsocket get websocket => _websocket ??= OndesWebsocket(_bridge);
}
