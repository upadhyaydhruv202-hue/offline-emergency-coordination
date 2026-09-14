import 'sync_status.dart';

/// The kinds of action worth being able to reconstruct afterwards.
///
/// The list is deliberately about operational decisions, not user-interface
/// events: what a responder decided, not what they tapped.
enum AuditEventType {
  incidentSelected('INCIDENT_SELECTED'),
  incidentCreated('INCIDENT_CREATED'),
  incidentUpdated('INCIDENT_UPDATED'),
  victimCreated('VICTIM_CREATED'),
  victimUpdated('VICTIM_UPDATED'),
  triageUpdated('TRIAGE_UPDATED'),
  sosCreated('SOS_CREATED'),
  sosResolved('SOS_RESOLVED'),
  hazardCreated('HAZARD_CREATED'),
  hazardUpdated('HAZARD_UPDATED'),
  taskAccepted('TASK_ACCEPTED'),
  taskStarted('TASK_STARTED'),
  taskCompleted('TASK_COMPLETED'),
  responderStatusChanged('RESPONDER_STATUS_CHANGED'),
  locationCaptured('LOCATION_CAPTURED'),
  syncOperationCreated('SYNC_OPERATION_CREATED'),
  syncStarted('SYNC_STARTED'),
  syncCompleted('SYNC_COMPLETED'),
  conflictDetected('CONFLICT_DETECTED'),
  conflictResolved('CONFLICT_RESOLVED'),
  entityConverged('ENTITY_CONVERGED');

  const AuditEventType(this.wireValue);

  final String wireValue;

  static AuditEventType? tryFromWire(String? value) {
    if (value == null) return null;
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}

/// What kind of thing an [AuditEvent] is about.
enum AuditEntityType {
  incident('INCIDENT'),
  victim('VICTIM'),
  sos('SOS'),
  hazard('HAZARD'),
  task('TASK'),
  responder('RESPONDER'),
  location('LOCATION'),
  sync('SYNC');

  const AuditEntityType(this.wireValue);

  final String wireValue;

  static AuditEntityType? tryFromWire(String? value) {
    if (value == null) return null;
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}

/// One recorded action.
///
/// Deliberately lightweight: an append-only local trail, written on the same
/// SQLite transaction boundary as the change it describes, with no signing and
/// no hash chain. Tamper-evidence is a hardening-slice concern; being able to
/// answer "what did this device do, and in what order" is useful now.
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.actorId,
    required this.timestamp,
    required this.syncStatus,
    this.metadata,
  });

  final String id;
  final AuditEventType eventType;
  final AuditEntityType entityType;

  /// Identifier of the record the action was taken on.
  final String entityId;

  /// Session id of the responder who took it.
  final String actorId;

  final DateTime timestamp;

  /// Free-form detail, stored as a single string so the trail never depends on
  /// a schema that has to be migrated when a screen starts recording one more
  /// field. Typically `key=value` pairs joined by `; `.
  final String? metadata;

  final SyncStatus syncStatus;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditEvent &&
          other.id == id &&
          other.eventType == eventType &&
          other.entityType == entityType &&
          other.entityId == entityId &&
          other.actorId == actorId &&
          other.timestamp == timestamp &&
          other.metadata == metadata &&
          other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(
        id,
        eventType,
        entityType,
        entityId,
        actorId,
        timestamp,
        metadata,
        syncStatus,
      );
}
