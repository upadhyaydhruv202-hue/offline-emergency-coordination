import 'location_fix.dart';
import 'sos_priority.dart';
import 'sos_status.dart';
import 'sync_status.dart';

/// A distress call raised on this device.
///
/// It is written to local storage and nowhere else. There is no transport in
/// this slice — no SMS, no call, no mesh — so the record's whole purpose is to
/// exist, be timestamped, carry a position, and be visible to the responder who
/// raised it. Anything that suggested it had been transmitted would be a lie a
/// responder might stake their life on.
class SosEvent {
  const SosEvent({
    required this.id,
    required this.sosCode,
    required this.createdBy,
    required this.priority,
    required this.status,
    required this.raisedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.incidentId,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.message,
  });

  final String id;

  /// Short label for the radio, e.g. `SOS-8C1F-004`.
  final String sosCode;

  /// Session id of the responder in trouble.
  final String createdBy;

  final String? incidentId;

  final double? latitude;
  final double? longitude;
  final double? accuracy;

  /// When the responder pressed the button. The product specification calls
  /// this field `timestamp`; it is named for what it records so it cannot be
  /// confused with [createdAt].
  final DateTime raisedAt;

  final SosPriority priority;
  final String? message;
  final SosStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  bool get hasPosition => latitude != null && longitude != null;

  /// The attached coordinates as a reading, so screens reuse the degree and
  /// accuracy formatting rather than restating it.
  LocationFix? get position => hasPosition
      ? LocationFix(
          latitude: latitude!,
          longitude: longitude!,
          accuracy: accuracy,
          timestamp: raisedAt,
        )
      : null;

  SosEvent copyWith({
    SosStatus? status,
    SosPriority? priority,
    String? message,
    bool clearMessage = false,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) =>
      SosEvent(
        id: id,
        sosCode: sosCode,
        createdBy: createdBy,
        incidentId: incidentId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        raisedAt: raisedAt,
        priority: priority ?? this.priority,
        message: clearMessage ? null : (message ?? this.message),
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SosEvent &&
          other.id == id &&
          other.sosCode == sosCode &&
          other.createdBy == createdBy &&
          other.incidentId == incidentId &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.priority == priority &&
          other.message == message &&
          other.status == status &&
          other.updatedAt == updatedAt &&
          other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(
        id,
        sosCode,
        createdBy,
        incidentId,
        latitude,
        longitude,
        priority,
        message,
        status,
        updatedAt,
        syncStatus,
      );
}
