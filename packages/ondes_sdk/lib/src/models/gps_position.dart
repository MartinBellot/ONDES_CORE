/// GPS position data from the device.
class GpsPosition {
  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;

  /// Horizontal accuracy in meters.
  final double accuracy;

  /// Altitude in meters (above sea level).
  final double? altitude;

  /// Speed in meters per second.
  final double? speed;

  /// Timestamp of the position reading.
  final DateTime? timestamp;

  const GpsPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.speed,
    this.timestamp,
  });

  /// Create from JSON map.
  factory GpsPosition.fromJson(Map<String, dynamic> json) {
    return GpsPosition(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
      if (timestamp != null) 'timestamp': timestamp!.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() => 'GpsPosition($latitude, $longitude)';
}
