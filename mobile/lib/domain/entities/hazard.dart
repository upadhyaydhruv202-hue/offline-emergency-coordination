import 'hazard_severity.dart';
import 'hazard_status.dart';
import 'hazard_type.dart';
import 'location_fix.dart';
import 'sync_status.dart';

/// Something dangerous, written down where it was found.
///
/// The value of a hazard report is entirely in how early it exists. Making it
/// wait for a network would mean the team that needed the warning has already
/// walked into the thing being reported, so this — like every other record in
/// the field application — is complete the moment it reaches local storage.
class Hazard {
  const Hazard({
    required this.id,
    required this.hazardCode,
    required this.reportedBy,
    required this.type,
    required this.severity,
    required this.priority,
    required this.status,
    required this.observedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.incidentId,
    this.description,
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  final String id;

  /// Short label for the radio, e.g. `HZ-8C1F-003`.
  final String hazardCode;

  final String? incidentId;

  /// Session id of the responder who saw it.
  final String reportedBy;

  final HazardType type;
  final HazardSeverity severity;

  /// Mirrors [HazardSeverity.priority]. Persisted so the list can be ordered by
  /// the database rather than in memory.
  final int priority;

  final String? description;

  final double? latitude;
  final double? longitude;
  final double? accuracy;

  /// When the responder observed it. The product specification calls this
  /// `timestamp`; it is named for what it records so it cannot be confused
  /// with [createdAt].
  final DateTime observedAt;

  final HazardStatus status;

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
          timestamp: observedAt,
        )
      : null;

  Hazard copyWith({
    HazardType? type,
    HazardSeverity? severity,
    String? description,
    bool clearDescription = false,
    HazardStatus? status,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    final level = severity ?? this.severity;
    return Hazard(
      id: id,
      hazardCode: hazardCode,
      incidentId: incidentId,
      reportedBy: reportedBy,
      type: type ?? this.type,
      severity: level,
      priority: level.priority,
      description:
          clearDescription ? null : (description ?? this.description),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      observedAt: observedAt,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hazard &&
          other.id == id &&
          other.hazardCode == hazardCode &&
          other.incidentId == incidentId &&
          other.reportedBy == reportedBy &&
          other.type == type &&
          other.severity == severity &&
          other.priority == priority &&
          other.description == description &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.status == status &&
          other.updatedAt == updatedAt &&
          other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(
        id,
        hazardCode,
        incidentId,
        reportedBy,
        type,
        severity,
        priority,
        description,
        latitude,
        longitude,
        status,
        updatedAt,
        syncStatus,
      );
}
