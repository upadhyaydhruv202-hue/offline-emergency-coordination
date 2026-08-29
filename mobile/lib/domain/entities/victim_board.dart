import 'triage_category.dart';

/// Counts across every victim held on this device.
///
/// Deliberately computed from local storage only: it is what this responder
/// can see from where they are standing, not the picture of the whole incident.
class VictimBoard {
  const VictimBoard({
    required this.total,
    required this.open,
    required this.pendingSync,
    required this.byTriage,
  });

  static const VictimBoard empty = VictimBoard(
    total: 0,
    open: 0,
    pendingSync: 0,
    byTriage: <TriageCategory, int>{},
  );

  final int total;

  /// Records that are neither evacuated nor deceased.
  final int open;

  /// Records that have never reached the coordination backend. In Slice 2
  /// that is all of them, because there is no synchronisation yet.
  final int pendingSync;

  final Map<TriageCategory, int> byTriage;

  int countOf(TriageCategory category) => byTriage[category] ?? 0;
}
