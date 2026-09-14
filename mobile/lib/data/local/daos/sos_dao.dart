import 'package:drift/drift.dart';

import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/sos_event.dart';
import '../../../domain/entities/sos_priority.dart';
import '../../../domain/entities/sos_status.dart';
import '../../../domain/entities/sync_status.dart';
import '../app_database.dart';

/// Every statement that touches the `sos_events` table.
class SosDao {
  const SosDao(this._db);

  final AppDatabase _db;

  /// Live history, ordered the way it has to be read: calls still open first,
  /// most urgent first within that, most recent first within that.
  Stream<List<SosEvent>> watchEvents() => _ordered().watch().map(_toList);

  Future<List<SosEvent>> readEvents() async => _toList(await _ordered().get());

  Stream<SosEvent?> watchEvent(String id) =>
      (_db.select(_db.sosEvents)..where((row) => row.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toEvent(row));

  Future<SosEvent?> readEvent(String id) async {
    final row = await (_db.select(_db.sosEvents)
          ..where((event) => event.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEvent(row);
  }

  Future<SosEvent?> readByCode(String sosCode) async {
    final row = await (_db.select(_db.sosEvents)
          ..where((event) => event.sosCode.equals(sosCode)))
        .getSingleOrNull();
    return row == null ? null : _toEvent(row);
  }

  Future<void> insertEvent(SosEvent event) =>
      _db.into(_db.sosEvents).insert(_toCompanion(event));

  Future<void> updateEvent(SosEvent event) async {
    await _db.update(_db.sosEvents).replace(_toCompanion(event));
  }

  Future<int> countAll() async {
    final count = _db.sosEvents.id.count();
    final query = _db.selectOnly(_db.sosEvents)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Live counts for the summary strip above the history.
  Stream<SosBoard> watchBoard() {
    final events = _db.sosEvents;

    final total = events.id.count();
    final open = events.id.count(filter: _isResolved().not());
    final pending = events.id.count(filter: _outstanding());
    final perPriority = <SosPriority, Expression<int>>{
      for (final priority in SosPriority.values)
        priority: events.id.count(
          filter: events.priority.equalsValue(priority),
        ),
    };

    final query = _db.selectOnly(events)
      ..addColumns([total, open, pending, ...perPriority.values]);

    return query.watchSingle().map(
          (row) => SosBoard(
            total: row.read(total) ?? 0,
            open: row.read(open) ?? 0,
            pendingSync: row.read(pending) ?? 0,
            byPriority: {
              for (final entry in perPriority.entries)
                entry.key: row.read(entry.value) ?? 0,
            },
          ),
        );
  }

  Stream<int> watchPendingCount() {
    final count = _db.sosEvents.id.count(filter: _outstanding());
    final query = _db.selectOnly(_db.sosEvents)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  SimpleSelectStatement<$SosEventsTable, SosEventRow> _ordered() {
    final select = _db.select(_db.sosEvents);
    select.orderBy([
      (_) => OrderingTerm.asc(_isResolved()),
      (event) => OrderingTerm.asc(event.priorityRank),
      (event) => OrderingTerm.desc(event.raisedAt),
    ]);
    return select;
  }

  Expression<bool> _isResolved() =>
      _db.sosEvents.status.equalsValue(SosStatus.resolved);

  Expression<bool> _outstanding() {
    final syncStatus = _db.sosEvents.syncStatus;
    return syncStatus.equalsValue(SyncStatus.pending) |
        syncStatus.equalsValue(SyncStatus.sent);
  }

  static List<SosEvent> _toList(List<SosEventRow> rows) =>
      rows.map(_toEvent).toList(growable: false);

  static SosEvent _toEvent(SosEventRow row) => SosEvent(
        id: row.id,
        sosCode: row.sosCode,
        createdBy: row.createdBy,
        incidentId: row.incidentId,
        latitude: row.latitude,
        longitude: row.longitude,
        accuracy: row.accuracy,
        raisedAt: row.raisedAt,
        priority: row.priority,
        message: row.message,
        status: row.status,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        syncStatus: row.syncStatus,
      );

  static SosEventsCompanion _toCompanion(SosEvent event) =>
      SosEventsCompanion.insert(
        id: event.id,
        sosCode: event.sosCode,
        createdBy: event.createdBy,
        incidentId: Value(event.incidentId),
        latitude: Value(event.latitude),
        longitude: Value(event.longitude),
        accuracy: Value(event.accuracy),
        raisedAt: event.raisedAt,
        priority: event.priority,
        priorityRank: event.priority.priority,
        message: Value(event.message),
        status: event.status,
        createdAt: event.createdAt,
        updatedAt: event.updatedAt,
        syncStatus: event.syncStatus,
      );
}
