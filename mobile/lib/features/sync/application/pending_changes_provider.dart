import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../hazards/application/hazard_providers.dart';
import '../../incidents/application/incident_providers.dart';
import '../../location/application/location_providers.dart';
import '../../responder/application/responder_status_providers.dart';
import '../../sos/application/sos_providers.dart';
import '../../tasks/application/task_providers.dart';
import '../../victims/application/victim_providers.dart';
import 'sync_providers.dart';

/// Outstanding local mutations.
///
/// Prefers the Slice 4 sync queue. If the queue is empty (tests that do not
/// journal, or a fresh device), falls back to counting records still marked
/// pending on each operational table.
final pendingChangesProvider = Provider<int>((ref) {
  final queued = ref.watch(pendingSyncOperationsCountProvider).value;
  if (queued != null && queued > 0) return queued;

  final counts = <int>[
    ref.watch(victimBoardProvider).value?.pendingSync ?? 0,
    ref.watch(hazardBoardProvider).value?.pendingSync ?? 0,
    ref.watch(sosBoardProvider).value?.pendingSync ?? 0,
    ref.watch(taskBoardProvider).value?.pendingSync ?? 0,
    ref.watch(incidentPendingCountProvider).value ?? 0,
    ref.watch(locationPendingCountProvider).value ?? 0,
    ref.watch(responderStatusPendingCountProvider).value ?? 0,
  ];

  return counts.fold(0, (total, count) => total + count);
});
