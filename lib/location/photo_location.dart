/// A device fix captured with a shutter press, independent of later settings.
class PhotoLocation {
  const PhotoLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.time,
    this.altitude,
    this.approximate = false,
  });

  static const preciseAccuracyLimitMeters = 100.0;
  static const approximateAccuracyLimitMeters = 5000.0;
  static const preciseMaxFixAge = Duration(minutes: 2);
  static const approximateMaxFixAge = Duration(minutes: 10);

  final double latitude;
  final double longitude;
  final double? altitude;
  final double accuracy;
  final DateTime time;

  /// Whether the fix was obtained with only approximate location permission.
  final bool approximate;

  bool isUsableAt(DateTime shutter) {
    final age = shutter.difference(time);
    return latitude.isFinite &&
        latitude.abs() <= 90 &&
        longitude.isFinite &&
        longitude.abs() <= 180 &&
        accuracy.isFinite &&
        accuracy >= 0 &&
        (approximate
            ? accuracy <= approximateAccuracyLimitMeters
            : accuracy < preciseAccuracyLimitMeters) &&
        (altitude == null || altitude!.isFinite) &&
        !age.isNegative &&
        age <= (approximate ? approximateMaxFixAge : preciseMaxFixAge);
  }

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (altitude != null) 'altitude': altitude,
    'accuracy': accuracy,
    'time': time.millisecondsSinceEpoch,
    'approximate': approximate,
  };

  static PhotoLocation? fromJson(Object? value) {
    if (value is! Map) return null;
    final lat = value['latitude'];
    final lon = value['longitude'];
    final accuracy = value['accuracy'];
    final time = value['time'];
    final altitude = value['altitude'];
    final approximate = value['approximate'];
    if (lat is! num ||
        lon is! num ||
        accuracy is! num ||
        time is! int ||
        (altitude != null && altitude is! num) ||
        (approximate != null && approximate is! bool)) {
      return null;
    }
    return PhotoLocation(
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      accuracy: accuracy.toDouble(),
      altitude: (altitude as num?)?.toDouble(),
      time: DateTime.fromMillisecondsSinceEpoch(time, isUtc: true),
      approximate: approximate == true,
    );
  }
}
