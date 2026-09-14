import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/audit_event.dart';
import '../../../domain/entities/location_fix.dart';
import '../../../domain/entities/sos_event.dart';
import '../../../domain/entities/sos_priority.dart';
import '../../../domain/entities/sos_status.dart';
import '../../audit/data/audit_repository.dart';
import '../../field_ops/application/operating_context.dart';
import '../../location/data/location_repository.dart';
import '../data/sos_repository.dart';

/// The write side of the SOS module.
///
/// Raising a call must not be able to fail for any reason other than the
/// database refusing the write. In particular it must not fail because there is
/// no position: this attempts a fresh fix, falls back to the last one the device
/// recorded, and raises the call with no position at all rather than not
/// raising it.
class SosService {
  const SosService({
    required this.repository,
    required this.locations,
    required this.audit,
    required this.context,
  });

  final SosRepository repository;
  final LocationRepository locations;
  final AuditRepository audit;
  final OperatingContext context;

  Future<SosEvent> raise({
    required SosPriority priority,
    String? message,
  }) async {
    final actorId = context.requireResponderId();
    final incidentId = await context.currentIncidentId();

    final event = await repository.raise(
      createdBy: actorId,
      priority: priority,
      incidentId: incidentId,
      position: await _bestAvailablePosition(actorId, incidentId),
      message: message,
    );

    await audit.record(
      eventType: AuditEventType.sosCreated,
      entityType: AuditEntityType.sos,
      entityId: event.id,
      actorId: actorId,
      metadata: {
        'code': event.sosCode,
        'priority': priority.wireValue,
        'positioned': event.hasPosition,
      },
    );

    return event;
  }

  Future<SosEvent> changeStatus(SosEvent event, SosStatus status) async {
    final actorId = context.requireResponderId();
    final updated = await repository.changeStatus(event: event, status: status);

    await audit.record(
      eventType: status == SosStatus.resolved
          ? AuditEventType.sosResolved
          : AuditEventType.sosCreated,
      entityType: AuditEntityType.sos,
      entityId: updated.id,
      actorId: actorId,
      metadata: {'code': updated.sosCode, 'status': status.wireValue},
    );

    return updated;
  }

  /// A fresh fix if the receiver can manage one, otherwise the last one this
  /// device wrote down, otherwise nothing.
  Future<LocationFix?> _bestAvailablePosition(
    String responderId,
    String? incidentId,
  ) async {
    try {
      final captured = await locations.capture(
        responderId: responderId,
        incidentId: incidentId,
      );
      return captured.fix;
    } on LocationUnavailableException {
      final known = await locations.readLatestFor(responderId);
      return known?.fix;
    } on Exception {
      return null;
    }
  }
}
