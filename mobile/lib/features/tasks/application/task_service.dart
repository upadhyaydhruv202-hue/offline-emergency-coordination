import '../../../domain/entities/audit_event.dart';
import '../../../domain/entities/field_task.dart';
import '../../../domain/entities/task_draft.dart';
import '../../../domain/entities/task_status.dart';
import '../../audit/data/audit_repository.dart';
import '../../field_ops/application/operating_context.dart';
import '../data/task_repository.dart';

/// The write side of the task module.
///
/// The lifecycle is intentionally the only logic here: accept, start, complete,
/// cancel. There is no assignment engine, no scheduling and no reallocation —
/// those need a coordination layer this slice does not have, and a fake one
/// would produce work orders nobody agreed to.
class TaskService {
  const TaskService({
    required this.repository,
    required this.audit,
    required this.context,
  });

  final TaskRepository repository;
  final AuditRepository audit;
  final OperatingContext context;

  Future<FieldTask> create(TaskDraft draft) async {
    final actorId = context.requireResponderId();

    final task = await repository.create(
      draft: draft,
      createdBy: actorId,
      incidentId: await context.currentIncidentId(),
    );

    await audit.record(
      eventType: AuditEventType.taskAccepted,
      entityType: AuditEntityType.task,
      entityId: task.id,
      actorId: actorId,
      metadata: {
        'code': task.taskCode,
        'priority': task.priority.wireValue,
        'status': task.status.wireValue,
      },
    );

    return task;
  }

  Future<FieldTask> update(FieldTask task, TaskDraft draft) async {
    context.requireResponderId();
    return repository.update(task: task, draft: draft);
  }

  Future<FieldTask> changeStatus(FieldTask task, TaskStatus status) async {
    final actorId = context.requireResponderId();
    final updated = await repository.changeStatus(
      task: task,
      status: status,
      claimedBy: actorId,
    );

    final eventType = switch (status) {
      TaskStatus.accepted => AuditEventType.taskAccepted,
      TaskStatus.inProgress => AuditEventType.taskStarted,
      TaskStatus.completed => AuditEventType.taskCompleted,
      TaskStatus.pending || TaskStatus.cancelled => AuditEventType.taskAccepted,
    };

    await audit.record(
      eventType: eventType,
      entityType: AuditEntityType.task,
      entityId: updated.id,
      actorId: actorId,
      metadata: {'code': updated.taskCode, 'status': status.wireValue},
    );

    return updated;
  }

  /// Performs the single transition the task's current status allows.
  ///
  /// Returns the task unchanged when it is finished, so a screen cannot invent
  /// a step the domain does not offer.
  Future<FieldTask> advance(FieldTask task) async {
    final next = task.status.next;
    return next == null ? task : changeStatus(task, next);
  }
}
