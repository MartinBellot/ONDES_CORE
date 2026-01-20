/// Mini-app information from the host application.
class AppInfo {
  /// Bundle identifier of the mini-app.
  final String bundleId;

  /// Display name of the mini-app.
  final String name;

  /// Version string of the mini-app.
  final String version;

  /// Platform the app is running on.
  final String platform;

  /// Ondes SDK version.
  final String sdkVersion;

  const AppInfo({
    required this.bundleId,
    required this.name,
    required this.version,
    required this.platform,
    required this.sdkVersion,
  });

  /// Create from JSON map.
  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      bundleId: json['bundleId'] as String? ?? 'unknown',
      name: json['name'] as String? ?? 'Unknown App',
      version: json['version'] as String? ?? '1.0.0',
      platform: json['platform'] as String? ?? 'unknown',
      sdkVersion: json['sdkVersion'] as String? ?? '1.0.0',
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'bundleId': bundleId,
      'name': name,
      'version': version,
      'platform': platform,
      'sdkVersion': sdkVersion,
    };
  }

  @override
  String toString() => 'AppInfo($name v$version)';
}
