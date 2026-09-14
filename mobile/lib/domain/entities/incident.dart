import 'disaster_type.dart';
import 'incident_status.dart';
import 'sync_status.dart';

/// The event this device is operating in.
///
/// An incident is declared on the device like everything else in this slice: a
/// responder arriving at a collapse with no signal must be able to open a
/// response and start recording against it. Reconciling two devices that each
/// declared the same event is Slice 4's problem, which is why the id is a
/// device-minted UUID rather than a server-assigned key.
class Incident {
  const Incident({
    required this.id,
    required this.incidentCode,
    required this.title,
    required this.disasterType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.syncStatus,
    this.description,
    this.assignedZone,
    this.latitude,
    this.longitude,
    this.lastModifiedBy,
  });

  final String id;

  /// Short label a commander says out loud, e.g. `INC-2026-001`.
  final String incidentCode;

  final String title;
  final DisasterType disasterType;
  final String? description;
  final IncidentStatus status;

  /// The sector this device is working, e.g. `AHMEDABAD ZONE 04`.
  final String? assignedZone;

  final double? latitude;
  final double? longitude;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Session id of the responder who declared it.
  final String createdBy;

  final String? lastModifiedBy;
  final SyncStatus syncStatus;

  bool get hasPosition => latitude != null && longitude != null;

  String get zoneLabel {
    final trimmed = assignedZone?.trim();
    return (trimmed == null || trimmed.isEmpty)
        ? 'No zone assigned'
        : trimmed.toUpperCase();
  }

  Incident copyWith({
    String? title,
    DisasterType? disasterType,
    String? description,
    bool clearDescription = false,
    IncidentStatus? status,
    String? assignedZone,
    bool clearAssignedZone = false,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
    String? lastModifiedBy,
    SyncStatus? syncStatus,
  }) =>
      Incident(
        id: id,
        incidentCode: incidentCode,
        title: title ?? this.title,
        disasterType: disasterType ?? this.disasterType,
        description:
            clearDescription ? null : (description ?? this.description),
        status: status ?? this.status,
        assignedZone:
            clearAssignedZone ? null : (assignedZone ?? this.assignedZone),
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy,
        lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Incident &&
          other.id == id &&
          other.incidentCode == incidentCode &&
          other.title == title &&
          other.disasterType == disasterType &&
          other.description == description &&
          other.status == status &&
          other.assignedZone == assignedZone &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.updatedAt == updatedAt &&
          other.lastModifiedBy == lastModifiedBy &&
          other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(
        id,
        incidentCode,
        title,
        disasterType,
        description,
        status,
        assignedZone,
        latitude,
        longitude,
        updatedAt,
        lastModifiedBy,
        syncStatus,
      );
}
