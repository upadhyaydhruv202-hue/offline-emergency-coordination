import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/hazard.dart';
import '../../../domain/entities/hazard_query.dart';
import '../../../domain/entities/hazard_severity.dart';
import '../../../domain/entities/hazard_status.dart';
import '../../../domain/entities/hazard_type.dart';
import '../../audit/application/audit_providers.dart';
import '../../field_ops/application/operating_context.dart';
import '../../sync/application/sync_providers.dart';
import '../data/hazard_repository.dart';
import 'hazard_service.dart';

final hazardRepositoryProvider = Provider<HazardRepository>(
  (ref) => HazardRepository(
    hazards: ref.watch(hazardDaoProvider),
    metadata: ref.watch(appMetadataDaoProvider),
    journal: ref.watch(syncJournalProvider),
  ),
);

/// Search text and the three filters, held in one place so the list, the empty
/// state and the filter bar can never disagree about what is being shown.
final hazardQueryProvider = NotifierProvider<HazardQueryController, HazardQuery>(
  HazardQueryController.new,
);

class HazardQueryController extends Notifier<HazardQuery> {
  @override
  HazardQuery build() => const HazardQuery();

  void search(String value) => state = state.copyWith(search: value);

  /// Null selects every type.
  void filterByType(HazardType? type) => state =
      type == null ? state.copyWith(clearType: true) : state.copyWith(type: type);

  /// Null selects every severity.
  void filterBySeverity(HazardSeverity? severity) => state = severity == null
      ? state.copyWith(clearSeverity: true)
      : state.copyWith(severity: severity);

  /// Null selects every status.
  void filterByStatus(HazardStatus? status) => state = status == null
      ? state.copyWith(clearStatus: true)
      : state.copyWith(status: status);

  void clear() => state = const HazardQuery();
}

/// The filtered, severity-ordered list. Backed by a database stream, so a report
/// filed anywhere in the app appears here without a manual refresh.
final hazardListProvider = StreamProvider<List<Hazard>>(
  (ref) => ref
      .watch(hazardRepositoryProvider)
      .watchHazards(ref.watch(hazardQueryProvider)),
);

/// Counts across every hazard on the device, ignoring the active filter.
final hazardBoardProvider = StreamProvider<HazardBoard>(
  (ref) => ref.watch(hazardRepositoryProvider).watchBoard(),
);

final hazardProvider = StreamProvider.family<Hazard?, String>(
  (ref, id) => ref.watch(hazardRepositoryProvider).watchHazard(id),
);

final hazardServiceProvider = Provider<HazardService>(
  (ref) => HazardService(
    repository: ref.watch(hazardRepositoryProvider),
    audit: ref.watch(auditRepositoryProvider),
    context: ref.watch(operatingContextProvider),
  ),
);
