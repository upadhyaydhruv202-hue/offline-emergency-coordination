import 'task_priority.dart';
import 'task_status.dart';

/// What the responder is currently looking for in the task list.
class TaskQuery {
  const TaskQuery({this.search = '', this.priority, this.status});

  /// Matched against the task code, title, description and location.
  final String search;

  /// Null means every priority.
  final TaskPriority? priority;

  /// Null means every status.
  final TaskStatus? status;

  String get normalisedSearch => search.trim().toLowerCase();

  bool get hasSearch => normalisedSearch.isNotEmpty;

  bool get isFiltered => hasSearch || priority != null || status != null;

  TaskQuery copyWith({
    String? search,
    TaskPriority? priority,
    bool clearPriority = false,
    TaskStatus? status,
    bool clearStatus = false,
  }) =>
      TaskQuery(
        search: search ?? this.search,
        priority: clearPriority ? null : (priority ?? this.priority),
        status: clearStatus ? null : (status ?? this.status),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskQuery &&
          other.search == search &&
          other.priority == priority &&
          other.status == status;

  @override
  int get hashCode => Object.hash(search, priority, status);
}
