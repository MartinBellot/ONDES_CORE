/// Device information from the host application.
class DeviceInfo {
  /// Platform type (ios, android, macos, windows, linux, web).
  final String platform;

  /// System brightness mode (light, dark).
  final String brightness;

  /// Screen width in logical pixels.
  final double screenWidth;

  /// Screen height in logical pixels.
  final double screenHeight;

  /// Device pixel ratio.
  final double pixelRatio;

  const DeviceInfo({
    required this.platform,
    required this.brightness,
    required this.screenWidth,
    required this.screenHeight,
    required this.pixelRatio,
  });

  /// Whether the device is running iOS.
  bool get isIOS => platform == 'iOS';

  /// Whether the device is running Android.
  bool get isAndroid => platform == 'android';

  /// Whether the device is running macOS.
  bool get isMacOS => platform == 'macOS';

  /// Whether the device is running Windows.
  bool get isWindows => platform == 'windows';

  /// Whether the device is in dark mode.
  bool get isDarkMode => brightness == 'dark';

  /// Create from JSON map.
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      platform: json['platform'] as String? ?? 'unknown',
      brightness: json['brightness'] as String? ?? 'light',
      screenWidth: (json['screenWidth'] as num?)?.toDouble() ?? 0,
      screenHeight: (json['screenHeight'] as num?)?.toDouble() ?? 0,
      pixelRatio: (json['pixelRatio'] as num?)?.toDouble() ?? 1,
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'brightness': brightness,
      'screenWidth': screenWidth,
      'screenHeight': screenHeight,
      'pixelRatio': pixelRatio,
    };
  }

  @override
  String toString() => 'DeviceInfo($platform, ${screenWidth}x$screenHeight)';
}
