import 'sync_status.dart';
import 'task_priority.dart';
import 'task_status.dart';

/// A unit of work held on this device.
///
/// Named [FieldTask] rather than `Task` so it cannot be mistaken for
/// `dart:async`'s scheduling vocabulary anywhere in the codebase.
///
/// Tasks will normally arrive from the command centre once synchronisation
/// exists. Until then a responder can raise one locally, which is the honest
/// version of the same thing: work that has been agreed over the radio and now
/// needs tracking.
class FieldTask {
  const FieldTask({
    required this.id,
    required this.taskCode,
    required this.title,
    required this.priority,
    required this.rank,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.incidentId,
    this.assignedTo,
    this.description,
    this.location,
  });

  final String id;

  /// Short label for the radio, e.g. `TASK-8C1F-021`.
  final String taskCode;

  final String? incidentId;

  /// Session id of the responder holding the task. Null when it is unassigned.
  final String? assignedTo;

  final String title;
  final String? description;
  final TaskPriority priority;

  /// Mirrors [TaskPriority.rank]. Persisted so ordering is a database concern.
  final int rank;

  final TaskStatus status;

  /// Free text: `Block C, third floor`. A task's location is what a responder
  /// can be told over a radio, not a coordinate pair.
  final String? location;

  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  FieldTask copyWith({
    String? title,
    String? description,
    bool clearDescription = false,
    TaskPriority? priority,
    TaskStatus? status,
    String? location,
    bool clearLocation = false,
    String? assignedTo,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    final level = priority ?? this.priority;
    return FieldTask(
      id: id,
      taskCode: taskCode,
      incidentId: incidentId,
      assignedTo: assignedTo ?? this.assignedTo,
      title: title ?? this.title,
      description:
          clearDescription ? null : (description ?? this.description),
      priority: level,
      rank: level.rank,
      status: status ?? this.status,
      location: clearLocation ? null : (location ?? this.location),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldTask &&
          other.id == id &&
          other.taskCode == taskCode &&
          other.incidentId == incidentId &&
          other.assignedTo == assignedTo &&
          other.title == title &&
          other.description == description &&
          other.priority == priority &&
          other.rank == rank &&
          other.status == status &&
          other.location == location &&
          other.updatedAt == updatedAt &&
          other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(
        id,
        taskCode,
        incidentId,
        assignedTo,
        title,
        description,
        priority,
        rank,
        status,
        location,
        updatedAt,
        syncStatus,
      );
}
