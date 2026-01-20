import '../bridge/js_bridge.dart';
import '../models/app_info.dart';

/// App module for mini-app lifecycle and information.
///
/// Get app info, manifest, and control the mini-app lifecycle.
///
/// ## Example
/// ```dart
/// final info = await Ondes.app.getInfo();
/// print("Running ${info.name} v${info.version}");
///
/// // Close the mini-app
/// await Ondes.app.close();
/// ```
class OndesApp {
  final OndesJsBridge _bridge;

  OndesApp(this._bridge);

  /// Gets information about the current mini-app.
  ///
  /// Returns [AppInfo] with bundle ID, name, version, etc.
  Future<AppInfo> getInfo() async {
    final result = await _bridge.call<Map<String, dynamic>>('Ondes.App.getInfo');
    return AppInfo.fromJson(result ?? {});
  }

  /// Closes the mini-app and returns to the host app.
  Future<void> close() async {
    await _bridge.call('Ondes.App.close');
  }

  /// Gets the mini-app's manifest.
  ///
  /// Returns the parsed manifest.json as a map.
  Future<Map<String, dynamic>> getManifest() async {
    final result = await _bridge.call<Map<String, dynamic>>('Ondes.App.getManifest');
    return result ?? {};
  }
}
