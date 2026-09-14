import 'field_task.dart';
import 'task_priority.dart';
import 'task_status.dart';

/// What a responder types when raising or editing a task.
class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.priority,
    this.description,
    this.location,
    this.status = TaskStatus.pending,
  });

  factory TaskDraft.from(FieldTask task) => TaskDraft(
        title: task.title,
        priority: task.priority,
        description: task.description,
        location: task.location,
        status: task.status,
      );

  final String title;
  final TaskPriority priority;
  final String? description;
  final String? location;
  final TaskStatus status;

  bool get hasTitle => title.trim().isNotEmpty;

  TaskDraft copyWith({
    String? title,
    TaskPriority? priority,
    String? description,
    String? location,
    TaskStatus? status,
  }) =>
      TaskDraft(
        title: title ?? this.title,
        priority: priority ?? this.priority,
        description: description ?? this.description,
        location: location ?? this.location,
        status: status ?? this.status,
      );
}
