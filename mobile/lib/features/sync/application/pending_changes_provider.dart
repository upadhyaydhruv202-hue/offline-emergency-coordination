import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../hazards/application/hazard_providers.dart';
import '../../incidents/application/incident_providers.dart';
import '../../location/application/location_providers.dart';
import '../../responder/application/responder_status_providers.dart';
import '../../sos/application/sos_providers.dart';
import '../../tasks/application/task_providers.dart';
import '../../victims/application/victim_providers.dart';

/// How many records this device is holding that no peer has confirmed.
///
/// There is no synchronisation in this slice, so in practice this is everything
/// the responder has authored. Showing the number anyway is the point: a
/// responder must never be left guessing whether what they captured has left the
/// handset, and a truthful "14 changes pending" is far more use than a hopeful
/// spinner.
///
/// Counted per table from live database queries rather than tracked in a
/// counter, so it cannot drift away from what is actually stored.
final pendingChangesProvider = Provider<int>((ref) {
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
