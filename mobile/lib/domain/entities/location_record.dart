import 'location_fix.dart';
import 'sync_status.dart';

/// A [LocationFix] committed to the device's own storage.
class LocationRecord {
  const LocationRecord({
    required this.id,
    required this.responderId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.createdAt,
    required this.syncStatus,
    this.incidentId,
    this.accuracy,
    this.source = 'unknown',
    this.isMocked = false,
  });

  final String id;
  final String responderId;
  final String? incidentId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final String source;
  final bool isMocked;

  LocationFix get fix => LocationFix(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        timestamp: timestamp,
        source: source,
        isMocked: isMocked,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationRecord &&
          other.id == id &&
          other.responderId == responderId &&
          other.incidentId == incidentId &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.accuracy == accuracy &&
          other.timestamp == timestamp &&
          other.syncStatus == syncStatus &&
          other.source == source &&
          other.isMocked == isMocked;

  @override
  int get hashCode => Object.hash(
        id,
        responderId,
        incidentId,
        latitude,
        longitude,
        accuracy,
        timestamp,
        syncStatus,
        source,
        isMocked,
      );
}
