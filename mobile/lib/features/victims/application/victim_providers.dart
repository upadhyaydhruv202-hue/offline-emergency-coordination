import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../domain/entities/triage_category.dart';
import '../../../domain/entities/victim.dart';
import '../../../domain/entities/victim_board.dart';
import '../../../domain/entities/victim_draft.dart';
import '../../../domain/entities/victim_query.dart';
import '../../../domain/entities/victim_status.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/victim_repository.dart';

final victimRepositoryProvider = Provider<VictimRepository>(
  (ref) => VictimRepository(
    victims: ref.watch(victimDaoProvider),
    metadata: ref.watch(appMetadataDaoProvider),
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
    currentResponderId: () =>
        ref.read(authControllerProvider).responderOrNull?.id,
  ),
);

/// The write side of the victim module.
///
/// Screens call this; they never touch the repository or the database
/// directly. It exists mainly to attach provenance — who authored the record —
/// without every form having to know about authentication.
class VictimEditor {
  const VictimEditor({
    required this.repository,
    required this.currentResponderId,
  });

  final VictimRepository repository;
  final String? Function() currentResponderId;

  Future<Victim> register(VictimDraft draft) {
    final responderId = currentResponderId();
    if (responderId == null) {
      throw StateError('A victim cannot be registered without a session');
    }
    return repository.register(draft: draft, createdBy: responderId);
  }

  Future<Victim> update(Victim victim, VictimDraft draft) =>
      repository.update(victim: victim, draft: draft);

  Future<Victim> reassess(Victim victim, TriageCategory category) =>
      repository.reassess(victim: victim, category: category);

  Future<Victim> changeStatus(Victim victim, VictimStatus status) =>
      repository.changeStatus(victim: victim, status: status);
}
