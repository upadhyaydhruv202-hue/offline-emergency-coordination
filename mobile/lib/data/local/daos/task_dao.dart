import 'package:drift/drift.dart';

import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/field_task.dart';
import '../../../domain/entities/sync_status.dart';
import '../../../domain/entities/task_query.dart';
import '../../../domain/entities/task_status.dart';
import '../app_database.dart';

/// Every statement that touches the `tasks` table.
class TaskDao {
  const TaskDao(this._db);

  final AppDatabase _db;

  /// Live task list for [query]: outstanding work first, most urgent first
  /// within that, most recently touched first within that.
  Stream<List<FieldTask>> watchTasks([TaskQuery query = const TaskQuery()]) =>
      _selectFor(query).watch().map(_toList);

  Future<List<FieldTask>> readTasks([
    TaskQuery query = const TaskQuery(),
  ]) async =>
      _toList(await _selectFor(query).get());

  Stream<FieldTask?> watchTask(String id) =>
      (_db.select(_db.tasks)..where((row) => row.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toTask(row));

  Future<FieldTask?> readTask(String id) async {
    final row =
        await (_db.select(_db.tasks)..where((task) => task.id.equals(id)))
            .getSingleOrNull();
    return row == null ? null : _toTask(row);
  }

  Future<FieldTask?> readByCode(String taskCode) async {
    final row = await (_db.select(_db.tasks)
          ..where((task) => task.taskCode.equals(taskCode)))
        .getSingleOrNull();
    return row == null ? null : _toTask(row);
  }

  /// The work the responder is holding right now, for the home dashboard.
  Stream<List<FieldTask>> watchActiveFor(String responderId) =>
      (_db.select(_db.tasks)
            ..where(
              (task) =>
                  task.assignedTo.equals(responderId) &
                  (task.status.equalsValue(TaskStatus.accepted) |
                      task.status.equalsValue(TaskStatus.inProgress)),
            )
            ..orderBy([
              (task) => OrderingTerm.asc(task.rank),
              (task) => OrderingTerm.desc(task.updatedAt),
            ]))
          .watch()
          .map(_toList);

  Future<void> insertTask(FieldTask task) =>
      _db.into(_db.tasks).insert(_toCompanion(task));

  Future<void> updateTask(FieldTask task) async {
    await _db.update(_db.tasks).replace(_toCompanion(task));
  }

  Future<int> countAll() async {
    final count = _db.tasks.id.count();
    final query = _db.selectOnly(_db.tasks)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Live counts across every task on the device, ignoring the active filter.
  Stream<TaskBoard> watchBoard() {
    final tasks = _db.tasks;

    final total = tasks.id.count();
    final active = tasks.id.count(
      filter: tasks.status.equalsValue(TaskStatus.accepted) |
          tasks.status.equalsValue(TaskStatus.inProgress),
    );
    final pending = tasks.id.count(filter: _outstanding());
    final perStatus = <TaskStatus, Expression<int>>{
      for (final status in TaskStatus.values)
        status: tasks.id.count(filter: tasks.status.equalsValue(status)),
    };

    final query = _db.selectOnly(tasks)
      ..addColumns([total, active, pending, ...perStatus.values]);

    return query.watchSingle().map(
          (row) => TaskBoard(
            total: row.read(total) ?? 0,
            active: row.read(active) ?? 0,
            pendingSync: row.read(pending) ?? 0,
            byStatus: {
              for (final entry in perStatus.entries)
                entry.key: row.read(entry.value) ?? 0,
            },
          ),
        );
  }

  Stream<int> watchPendingCount() {
    final count = _db.tasks.id.count(filter: _outstanding());
    final query = _db.selectOnly(_db.tasks)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  SimpleSelectStatement<$TasksTable, TaskRow> _selectFor(TaskQuery query) {
    final select = _db.select(_db.tasks);

    final priority = query.priority;
    if (priority != null) {
      select.where((task) => task.priority.equalsValue(priority));
    }

    final status = query.status;
    if (status != null) {
      select.where((task) => task.status.equalsValue(status));
    }

    if (query.hasSearch) {
      final term = '%${query.normalisedSearch}%';
      select.where(
        (task) =>
            task.taskCode.lower().like(term) |
            task.title.lower().like(term) |
            task.description.lower().like(term) |
            task.location.lower().like(term),
      );
    }

    select.orderBy([
      // false (0) before true (1): outstanding work above finished work.
      (_) => OrderingTerm.asc(_isClosed()),
      (task) => OrderingTerm.asc(task.rank),
      (task) => OrderingTerm.desc(task.updatedAt),
    ]);

    return select;
  }

  Expression<bool> _isClosed() {
    final status = _db.tasks.status;
    return status.equalsValue(TaskStatus.completed) |
        status.equalsValue(TaskStatus.cancelled);
  }

  Expression<bool> _outstanding() {
    final syncStatus = _db.tasks.syncStatus;
    return syncStatus.equalsValue(SyncStatus.pending) |
        syncStatus.equalsValue(SyncStatus.sent);
  }

  static List<FieldTask> _toList(List<TaskRow> rows) =>
      rows.map(_toTask).toList(growable: false);

  static FieldTask _toTask(TaskRow row) => FieldTask(
        id: row.id,
        taskCode: row.taskCode,
        incidentId: row.incidentId,
        assignedTo: row.assignedTo,
        title: row.title,
        description: row.description,
        priority: row.priority,
        rank: row.rank,
        status: row.status,
        location: row.location,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        syncStatus: row.syncStatus,
      );

  static TasksCompanion _toCompanion(FieldTask task) => TasksCompanion.insert(
        id: task.id,
        taskCode: task.taskCode,
        incidentId: Value(task.incidentId),
        assignedTo: Value(task.assignedTo),
        title: task.title,
        description: Value(task.description),
        priority: task.priority,
        rank: task.rank,
        status: task.status,
        location: Value(task.location),
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
        syncStatus: task.syncStatus,
      );
}
