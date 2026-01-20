import '../bridge/js_bridge.dart';
import '../models/device_info.dart';
import '../models/gps_position.dart';
import '../models/enums.dart';

/// Device module for hardware access.
///
/// Provides haptic feedback, vibration, QR scanner, GPS, and device info.
///
/// ## Example
/// ```dart
/// // Haptic feedback
/// await Ondes.device.hapticFeedback(HapticStyle.success);
///
/// // Scan QR code
/// final code = await Ondes.device.scanQRCode();
///
/// // Get GPS position
/// final position = await Ondes.device.getGPSPosition();
/// print("Location: ${position.latitude}, ${position.longitude}");
/// ```
class OndesDevice {
  final OndesJsBridge _bridge;

  OndesDevice(this._bridge);

  /// Triggers haptic feedback.
  ///
  /// [style] The type of haptic feedback (light, medium, heavy, success, etc.)
  Future<void> hapticFeedback([HapticStyle style = HapticStyle.light]) async {
    await _bridge.call('Ondes.Device.hapticFeedback', [style.name]);
  }

  /// Vibrates the device.
  ///
  /// [duration] Duration in milliseconds.
  Future<void> vibrate([int duration = 100]) async {
    await _bridge.call('Ondes.Device.vibrate', [duration]);
  }

  /// Opens the native QR code scanner.
  ///
  /// Returns the scanned content as a string.
  ///
  /// Throws if the user cancels or camera permission is denied.
  Future<String> scanQRCode() async {
    final result = await _bridge.call<String>('Ondes.Device.scanQRCode');
    if (result == null) {
      throw const OndesBridgeException(
        code: 'CANCELLED',
        message: 'QR code scan was cancelled',
      );
    }
    return result;
  }

  /// Gets the current GPS position.
  ///
  /// Requests location permission if not already granted.
  ///
  /// Throws if permission is denied or location services are disabled.
  Future<GpsPosition> getGPSPosition() async {
    final result = await _bridge.call<Map<String, dynamic>>('Ondes.Device.getGPSPosition');
    if (result == null) {
      throw const OndesBridgeException(
        code: 'NOT_AVAILABLE',
        message: 'Could not get GPS position',
      );
    }
    return GpsPosition.fromJson(result);
  }

  /// Gets device information.
  ///
  /// Returns platform, brightness, screen dimensions, etc.
  Future<DeviceInfo> getInfo() async {
    final result = await _bridge.call<Map<String, dynamic>>('Ondes.Device.getInfo');
    return DeviceInfo.fromJson(result ?? {});
  }
}
