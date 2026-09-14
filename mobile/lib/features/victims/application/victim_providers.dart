import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../domain/entities/audit_event.dart';
import '../../../domain/entities/triage_category.dart';
import '../../../domain/entities/victim.dart';
import '../../../domain/entities/victim_board.dart';
import '../../../domain/entities/victim_draft.dart';
import '../../../domain/entities/victim_query.dart';
import '../../../domain/entities/victim_status.dart';
import '../../audit/application/audit_providers.dart';
import '../../audit/data/audit_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../field_ops/application/operating_context.dart';
import '../../location/application/location_providers.dart';
import '../../location/data/location_repository.dart';
import '../../sync/application/sync_providers.dart';
import '../data/victim_repository.dart';

final victimRepositoryProvider = Provider<VictimRepository>(
  (ref) => VictimRepository(
    victims: ref.watch(victimDaoProvider),
    metadata: ref.watch(appMetadataDaoProvider),
    journal: ref.watch(syncJournalProvider),
  ),
);

/// Search text and the two filters, held in one place so the list, the empty
/// state and the filter bar can never disagree about what is being shown.
final victimQueryProvider =
    NotifierProvider<VictimQueryController, VictimQuery>(
  VictimQueryController.new,
);

class VictimQueryController extends Notifier<VictimQuery> {
  @override
  VictimQuery build() => const VictimQuery();

  void search(String value) => state = state.copyWith(search: value);

  /// Null selects every category.
  void filterByTriage(TriageCategory? category) => state = category == null
      ? state.copyWith(clearTriage: true)
      : state.copyWith(triage: category);

  /// Null selects every status.
  void filterByStatus(VictimStatus? status) => state = status == null
      ? state.copyWith(clearStatus: true)
      : state.copyWith(status: status);

  void clear() => state = const VictimQuery();
}

/// The filtered, triage-ordered list. Backed by a database stream, so a write
/// anywhere in the app is reflected here without a manual refresh.
final victimListProvider = StreamProvider<List<Victim>>(
  (ref) => ref
      .watch(victimRepositoryProvider)
      .watchVictims(ref.watch(victimQueryProvider)),
);

/// Counts across every record on the device, ignoring the active filter.
final victimBoardProvider = StreamProvider<VictimBoard>(
  (ref) => ref.watch(victimRepositoryProvider).watchBoard(),
);

final victimProvider = StreamProvider.family<Victim?, String>(
  (ref, id) => ref.watch(victimRepositoryProvider).watchVictim(id),
);

final victimEditorProvider = Provider<VictimEditor>(
  (ref) => VictimEditor(
    repository: ref.watch(victimRepositoryProvider),
    locations: ref.watch(locationRepositoryProvider),
    audit: ref.watch(auditRepositoryProvider),
    context: ref.watch(operatingContextProvider),
    currentResponderId: () =>
        ref.read(authControllerProvider).responderOrNull?.id,
  ),
);

/// The write side of the victim module.
///
/// Screens call this; they never touch the repository or the database
/// directly. It exists mainly to attach the context the device already holds —
/// who authored the record, which incident it belongs to, and where the
/// responder was standing — without every form having to know about
/// authentication, incident selection or the receiver.
class VictimEditor {
  const VictimEditor({
    required this.repository,
    required this.locations,
    required this.audit,
    required this.context,
    required this.currentResponderId,
  });

  final VictimRepository repository;
  final LocationRepository locations;
  final AuditRepository audit;
  final OperatingContext context;
  final String? Function() currentResponderId;

  Future<Victim> register(VictimDraft draft) async {
    final responderId = currentResponderId();
    if (responderId == null) {
      throw StateError('A victim cannot be registered without a session');
    }

    final known = await locations.readLatestFor(responderId);

    final victim = await repository.register(
      draft: draft,
      createdBy: responderId,
      incidentId: await context.currentIncidentId(),
      position: known?.fix,
    );

    await audit.record(
      eventType: AuditEventType.victimCreated,
      entityType: AuditEntityType.victim,
      entityId: victim.id,
      actorId: responderId,
      metadata: {
        'tag': victim.temporaryId,
        'triage': victim.triageCategory.wireValue,
        'incident': victim.incidentId,
        'positioned': victim.hasPosition,
      },
    );

    return victim;
  }

  Future<Victim> update(Victim victim, VictimDraft draft) async {
    final updated = await repository.update(victim: victim, draft: draft);
    await _record(AuditEventType.victimUpdated, updated);
    return updated;
  }

  Future<Victim> reassess(Victim victim, TriageCategory category) async {
    final updated = await repository.reassess(
      victim: victim,
      category: category,
    );
    await _record(AuditEventType.triageUpdated, updated);
    return updated;
  }

  Future<Victim> changeStatus(Victim victim, VictimStatus status) async {
    final updated = await repository.changeStatus(
      victim: victim,
      status: status,
    );
    await _record(AuditEventType.victimUpdated, updated);
    return updated;
  }

  Future<void> _record(AuditEventType eventType, Victim victim) async {
    final responderId = currentResponderId();
    if (responderId == null) return;

    await audit.record(
      eventType: eventType,
      entityType: AuditEntityType.victim,
      entityId: victim.id,
      actorId: responderId,
      metadata: {
        'tag': victim.temporaryId,
        'triage': victim.triageCategory.wireValue,
        'status': victim.status.wireValue,
      },
    );
  }
}
