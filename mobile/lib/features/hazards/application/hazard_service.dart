import '../../../domain/entities/audit_event.dart';
import '../../../domain/entities/hazard.dart';
import '../../../domain/entities/hazard_draft.dart';
import '../../../domain/entities/hazard_status.dart';
import '../../audit/data/audit_repository.dart';
import '../../field_ops/application/operating_context.dart';
import '../data/hazard_repository.dart';

/// The write side of the hazard module.
///
/// Screens call this; they never touch the repository or the database directly.
class HazardService {
  const HazardService({
    required this.repository,
    required this.audit,
    required this.context,
  });

  final HazardRepository repository;
  final AuditRepository audit;
  final OperatingContext context;

  Future<Hazard> report(HazardDraft draft) async {
    final actorId = context.requireResponderId();

    final hazard = await repository.report(
      draft: draft,
      reportedBy: actorId,
      incidentId: await context.currentIncidentId(),
    );

    await audit.record(
      eventType: AuditEventType.hazardCreated,
      entityType: AuditEntityType.hazard,
      entityId: hazard.id,
      actorId: actorId,
      metadata: {
        'code': hazard.hazardCode,
        'type': hazard.type.wireValue,
        'severity': hazard.severity.wireValue,
        'positioned': hazard.hasPosition,
      },
    );

    return hazard;
  }

  Future<Hazard> update(Hazard hazard, HazardDraft draft) async {
    final actorId = context.requireResponderId();
    final updated = await repository.update(hazard: hazard, draft: draft);

    await audit.record(
      eventType: AuditEventType.hazardUpdated,
      entityType: AuditEntityType.hazard,
      entityId: updated.id,
      actorId: actorId,
      metadata: {
        'code': updated.hazardCode,
        'severity': updated.severity.wireValue,
        'status': updated.status.wireValue,
      },
    );

    return updated;
  }

  Future<Hazard> changeStatus(Hazard hazard, HazardStatus status) async {
    final actorId = context.requireResponderId();
    final updated = await repository.changeStatus(
      hazard: hazard,
      status: status,
    );

    await audit.record(
      eventType: AuditEventType.hazardUpdated,
      entityType: AuditEntityType.hazard,
      entityId: updated.id,
      actorId: actorId,
      metadata: {'code': updated.hazardCode, 'status': status.wireValue},
    );

    return updated;
  }
}
