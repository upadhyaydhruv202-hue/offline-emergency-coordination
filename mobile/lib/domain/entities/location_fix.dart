import 'dart:math' as math;

/// A single position reading from the device's own receiver.
///
/// GPS is a satellite service, not an internet one. A responder in a basement
/// with no signal may still have a position, and one standing in the open with
/// full bars may not — so this is never derived from, or gated on,
/// connectivity.
///
/// Coordinates are only stored as the platform reported them. This type never
/// invents a latitude or longitude.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.source = 'unknown',
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;

  /// Radius of 68% confidence, in metres. Null when the platform declines to
  /// estimate it, which is not a reason to discard the reading.
  final double? accuracy;

  final DateTime timestamp;

  /// Platform provider: `gps`, `fused`, `network`, `mock`, or `unknown`.
  final String source;

  /// True when the platform marked the reading as a mock/test provider.
  final bool isMocked;

  /// Google's published Android emulator default (Mountain View). Detected so
  /// it is never labelled LIVE GPS. Never written as this application's own
  /// position and never used as a fallback.
  bool get isPublishedEmulatorDefault {
    const emulatorLat = 37.4219983;
    const emulatorLng = -122.084;
    return (latitude - emulatorLat).abs() < 0.005 &&
        (longitude - emulatorLng).abs() < 0.005;
  }

  /// Mocked by the OS, or the well-known emulator default.
  bool get isEffectivelyMocked => isMocked || isPublishedEmulatorDefault;

  String get latitudeLabel => _degrees(latitude, 'N', 'S');

  String get longitudeLabel => _degrees(longitude, 'E', 'W');

  /// `8 m`, or `unknown` when the platform gave no estimate.
  String get accuracyLabel =>
      accuracy == null ? 'unknown' : '${accuracy!.round()} m';

  /// `16:42:18` in local time.
  String get timeLabel {
    final local = timestamp.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
  }

  static String _degrees(double value, String positive, String negative) =>
      '${value.abs().toStringAsFixed(4)}° ${value >= 0 ? positive : negative}';

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// Rough ground distance in metres. Used to throttle stored updates, not for
  /// navigation.
  double distanceMetersTo(LocationFix other) {
    const earthMeters = 6371000.0;
    final lat1 = latitude * math.pi / 180;
    final lat2 = other.latitude * math.pi / 180;
    final dLat = lat2 - lat1;
    final dLng = (other.longitude - longitude) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final h = sinLat * sinLat +
        math.cos(lat1) * math.cos(lat2) * sinLng * sinLng;
    final clamped = h.clamp(0.0, 1.0);
    return earthMeters * 2 * math.atan2(math.sqrt(clamped), math.sqrt(1 - clamped));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationFix &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.accuracy == accuracy &&
          other.timestamp == timestamp &&
          other.source == source &&
          other.isMocked == isMocked;

  @override
  int get hashCode => Object.hash(
        latitude,
        longitude,
        accuracy,
        timestamp,
        source,
        isMocked,
      );
}
