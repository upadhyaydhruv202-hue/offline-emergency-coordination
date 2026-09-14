import 'hazard_severity.dart';
import 'sos_priority.dart';
import 'task_status.dart';

/// Counts across every hazard held on this device.
///
/// Like [SosBoard] and [TaskBoard] below, this is what the responder can see
/// from where they are standing — not the picture of the whole incident.
class HazardBoard {
  const HazardBoard({
    required this.total,
    required this.open,
    required this.pendingSync,
    required this.bySeverity,
  });

  static const HazardBoard empty = HazardBoard(
    total: 0,
    open: 0,
    pendingSync: 0,
    bySeverity: <HazardSeverity, int>{},
  );

  final int total;

  /// Hazards that have not been resolved.
  final int open;

  final int pendingSync;
  final Map<HazardSeverity, int> bySeverity;

  int countOf(HazardSeverity severity) => bySeverity[severity] ?? 0;
}

/// Counts across every distress call raised on this device.
class SosBoard {
  const SosBoard({
    required this.total,
    required this.open,
    required this.pendingSync,
    required this.byPriority,
  });

  static const SosBoard empty = SosBoard(
    total: 0,
    open: 0,
    pendingSync: 0,
    byPriority: <SosPriority, int>{},
  );

  final int total;

  /// Calls that have not been resolved.
  final int open;

  final int pendingSync;
  final Map<SosPriority, int> byPriority;

  int countOf(SosPriority priority) => byPriority[priority] ?? 0;
}

/// Counts across every task held on this device.
class TaskBoard {
  const TaskBoard({
    required this.total,
    required this.active,
    required this.pendingSync,
    required this.byStatus,
  });

  static const TaskBoard empty = TaskBoard(
    total: 0,
    active: 0,
    pendingSync: 0,
    byStatus: <TaskStatus, int>{},
  );

  final int total;

  /// Tasks the responder is holding: accepted or in progress.
  final int active;

  final int pendingSync;
  final Map<TaskStatus, int> byStatus;

  int countOf(TaskStatus status) => byStatus[status] ?? 0;
}
