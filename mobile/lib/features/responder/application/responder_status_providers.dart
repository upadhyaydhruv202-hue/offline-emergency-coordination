import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../domain/entities/audit_event.dart';
import '../../../domain/entities/responder_status.dart';
import '../../../domain/entities/responder_status_record.dart';
import '../../audit/application/audit_providers.dart';
import '../../audit/data/audit_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../field_ops/application/operating_context.dart';
import '../../sync/application/sync_providers.dart';
import '../data/responder_status_repository.dart';

final responderStatusRepositoryProvider = Provider<ResponderStatusRepository>(
  (ref) => ResponderStatusRepository(
    ref.watch(responderStatusDaoProvider),
    journal: ref.watch(syncJournalProvider),
  ),
);

/// The signed-in responder's current operational status.
///
/// Defaults to [ResponderStatus.initial] rather than null: a responder who has
/// signed in and said nothing else is available, and "unknown" is not something
/// a commander can act on.
final responderStatusProvider = StreamProvider<ResponderStatus>((ref) {
  final responderId = ref.watch(authControllerProvider).responderOrNull?.id;
  if (responderId == null) {
    return Stream<ResponderStatus>.value(ResponderStatus.initial);
  }
  return ref
      .watch(responderStatusRepositoryProvider)
      .watchStatus(responderId);
});

final responderStatusRecordProvider =
    StreamProvider<ResponderStatusRecord?>((ref) {
  final responderId = ref.watch(authControllerProvider).responderOrNull?.id;
  if (responderId == null) return Stream<ResponderStatusRecord?>.value(null);
  return ref
      .watch(responderStatusRepositoryProvider)
      .watchRecord(responderId);
});

final responderStatusPendingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(responderStatusDaoProvider).watchPendingCount(),
);

final responderStatusServiceProvider = Provider<ResponderStatusService>(
  (ref) => ResponderStatusService(
    repository: ref.watch(responderStatusRepositoryProvider),
    audit: ref.watch(auditRepositoryProvider),
    context: ref.watch(operatingContextProvider),
  ),
);

/// The write side of the responder status module.
class ResponderStatusService {
  const ResponderStatusService({
    required this.repository,
    required this.audit,
    required this.context,
  });

  final ResponderStatusRepository repository;
  final AuditRepository audit;
  final OperatingContext context;

  Future<ResponderStatusRecord> setStatus(
    ResponderStatus status, {
    String? note,
  }) async {
    final actorId = context.requireResponderId();
    final previous = await repository.readStatus(actorId);

    final record = await repository.setStatus(
      responderId: actorId,
      status: status,
      incidentId: await context.currentIncidentId(),
      note: note,
    );

    await audit.record(
      eventType: AuditEventType.responderStatusChanged,
      entityType: AuditEntityType.responder,
      entityId: actorId,
      actorId: actorId,
      metadata: {'from': previous.wireValue, 'to': status.wireValue},
    );

    return record;
  }
}
