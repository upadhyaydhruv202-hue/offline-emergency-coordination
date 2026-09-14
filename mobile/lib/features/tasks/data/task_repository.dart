import '../../../core/utils/identifiers.dart';
import '../../../data/local/daos/app_metadata_dao.dart';
import '../../../data/local/daos/task_dao.dart';
import '../../../data/local/field_code_minter.dart';
import '../../../data/local/tables/app_metadata.dart';
import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/field_task.dart';
import '../../../domain/entities/sync_status.dart';
import '../../../domain/entities/task_draft.dart';
import '../../../domain/entities/task_query.dart';
import '../../../domain/entities/task_status.dart';

/// How a task comes into existence and moves through its lifecycle.
///
/// Tasks will normally arrive from the command centre once synchronisation
/// exists. Until then a responder raises one locally, which is the honest
/// version of the same thing: work agreed over the radio that now needs
/// tracking. Either way the transitions are recorded on the device first.
class TaskRepository {
  TaskRepository({required this.tasks, required this.metadata})
      : _codes = FieldCodeMinter(metadata);

  final TaskDao tasks;
  final AppMetadataDao metadata;
  final FieldCodeMinter _codes;

  Stream<List<FieldTask>> watchTasks(TaskQuery query) => tasks.watchTasks(query);

  Future<List<FieldTask>> readTasks([TaskQuery query = const TaskQuery()]) =>
      tasks.readTasks(query);

  Stream<FieldTask?> watchTask(String id) => tasks.watchTask(id);

  Future<FieldTask?> readTask(String id) => tasks.readTask(id);

  Stream<List<FieldTask>> watchActiveFor(String responderId) =>
      tasks.watchActiveFor(responderId);

  Stream<TaskBoard> watchBoard() => tasks.watchBoard();

  /// Writes a new task to the device and returns the stored record.
  Future<FieldTask> create({
    required TaskDraft draft,
    required String createdBy,
    String? incidentId,
    String? assignedTo,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();

    final task = FieldTask(
      id: generateUuidV4(),
      taskCode: await _nextCode(),
      incidentId: incidentId,
      // A task a responder raised for themselves is theirs by default; asking
      // who it belongs to would be a question with one possible answer.
      assignedTo: assignedTo ?? createdBy,
      title: draft.title.trim(),
      description: _clean(draft.description),
      priority: draft.priority,
      rank: draft.priority.rank,
      status: draft.status,
      location: _clean(draft.location),
      createdAt: timestamp,
      updatedAt: timestamp,
      // Nothing has been synchronised, because nothing can be yet.
      syncStatus: SyncStatus.pending,
    );

    await tasks.insertTask(task);
    return task;
  }

  Future<FieldTask> update({
    required FieldTask task,
    required TaskDraft draft,
    DateTime? now,
  }) async {
    final description = _clean(draft.description);
    final location = _clean(draft.location);

    final updated = task.copyWith(
      title: draft.title.trim(),
      description: description,
      clearDescription: description == null,
      priority: draft.priority,
      status: draft.status,
      location: location,
      clearLocation: location == null,
      updatedAt: (now ?? DateTime.now()).toUtc(),
      syncStatus: SyncStatus.pending,
    );

    await tasks.updateTask(updated);
    return updated;
  }

  /// Accept, start, complete or cancel, which are one tap each in the field.
  ///
  /// Accepting also claims the task for [claimedBy] when it was unassigned, so
  /// a responder who takes work off a shared list is recorded as holding it.
  Future<FieldTask> changeStatus({
    required FieldTask task,
    required TaskStatus status,
    String? claimedBy,
    DateTime? now,
  }) async {
    final updated = task.copyWith(
      status: status,
      assignedTo: task.assignedTo ?? claimedBy,
      updatedAt: (now ?? DateTime.now()).toUtc(),
      syncStatus: SyncStatus.pending,
    );

    await tasks.updateTask(updated);
    return updated;
  }

  Future<String> _nextCode() => _codes.next(
        prefix: 'TASK',
        sequenceKey: AppMetadataKeys.taskSequence,
        isTaken: (candidate) async => await tasks.readByCode(candidate) != null,
      );

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
