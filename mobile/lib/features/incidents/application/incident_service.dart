import '../../../domain/entities/audit_event.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/entities/incident_draft.dart';
import '../../../domain/entities/incident_status.dart';
import '../../audit/data/audit_repository.dart';
import '../data/incident_repository.dart';

/// The write side of the incident module.
///
/// Screens call this; they never touch the repository or the database directly.
/// It exists to attach provenance and to append the audit trail, so no form has
/// to know about authentication or about how decisions are recorded.
class IncidentService {
  const IncidentService({
    required this.repository,
    required this.audit,
    required this.currentResponderId,
  });

  final IncidentRepository repository;
  final AuditRepository audit;
  final String? Function() currentResponderId;

  Future<Incident> declare(IncidentDraft draft) async {
    final actorId = _requireActor();
    final incident = await repository.declare(
      draft: draft,
      createdBy: actorId,
    );

    await audit.record(
      eventType: AuditEventType.incidentCreated,
      entityType: AuditEntityType.incident,
      entityId: incident.id,
      actorId: actorId,
      metadata: {
        'code': incident.incidentCode,
        'type': incident.disasterType.wireValue,
        'zone': incident.assignedZone,
      },
    );

    return incident;
  }

  Future<Incident> update(Incident incident, IncidentDraft draft) async {
    final actorId = _requireActor();
    final updated = await repository.update(
      incident: incident,
      draft: draft,
      modifiedBy: actorId,
    );

    await audit.record(
      eventType: AuditEventType.incidentUpdated,
      entityType: AuditEntityType.incident,
      entityId: updated.id,
      actorId: actorId,
      metadata: {'code': updated.incidentCode, 'status': updated.status.wireValue},
    );

    return updated;
  }

  Future<Incident> changeStatus(
    Incident incident,
    IncidentStatus status,
  ) async {
    final actorId = _requireActor();
    final updated = await repository.changeStatus(
      incident: incident,
      status: status,
      modifiedBy: actorId,
    );

    await audit.record(
      eventType: AuditEventType.incidentUpdated,
      entityType: AuditEntityType.incident,
      entityId: updated.id,
      actorId: actorId,
      metadata: {'status': status.wireValue},
    );

    return updated;
  }

  /// Adopts [incident] as the device's current operation.
  Future<void> select(Incident incident) async {
    final actorId = _requireActor();
    await repository.selectCurrent(incident.id);

    await audit.record(
      eventType: AuditEventType.incidentSelected,
      entityType: AuditEntityType.incident,
      entityId: incident.id,
      actorId: actorId,
      metadata: {'code': incident.incidentCode, 'title': incident.title},
    );
  }

  Future<void> standDown() => repository.clearCurrent();

  String _requireActor() {
    final id = currentResponderId();
    if (id == null) {
      throw StateError('An incident cannot be changed without a session');
    }
    return id;
  }
}
