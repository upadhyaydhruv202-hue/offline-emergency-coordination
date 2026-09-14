import 'package:drift/drift.dart';

import '../../../domain/entities/responder_status_record.dart';
import '../../../domain/entities/sync_status.dart';
import '../app_database.dart';

/// Every statement that touches the `responder_status` table.
class ResponderStatusDao {
  const ResponderStatusDao(this._db);

  final AppDatabase _db;

  Stream<ResponderStatusRecord?> watchFor(String responderId) =>
      (_db.select(_db.responderStatuses)
            ..where((row) => row.responderId.equals(responderId)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toRecord(row));

  Future<ResponderStatusRecord?> readFor(String responderId) async {
    final row = await (_db.select(_db.responderStatuses)
          ..where((entry) => entry.responderId.equals(responderId)))
        .getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  /// Writes the responder's current status, replacing whatever was there.
  ///
  /// One row per responder: a commander acts on the status now, and a history
  /// of it is only worth keeping once two devices' versions of it can be merged.
  Future<void> save(ResponderStatusRecord record) =>
      _db.into(_db.responderStatuses).insertOnConflictUpdate(
            _toCompanion(record),
          );

  Stream<int> watchPendingCount() {
    final table = _db.responderStatuses;
    final count = table.responderId.count(
      filter: table.syncStatus.equalsValue(SyncStatus.pending) |
          table.syncStatus.equalsValue(SyncStatus.sent),
    );
    final query = _db.selectOnly(table)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  static ResponderStatusRecord _toRecord(ResponderStatusRow row) =>
      ResponderStatusRecord(
        responderId: row.responderId,
        status: row.status,
        incidentId: row.incidentId,
        note: row.note,
        updatedAt: row.updatedAt,
        syncStatus: row.syncStatus,
      );

  static ResponderStatusesCompanion _toCompanion(
    ResponderStatusRecord record,
  ) =>
      ResponderStatusesCompanion.insert(
        responderId: record.responderId,
        status: record.status,
        incidentId: Value(record.incidentId),
        note: Value(record.note),
        updatedAt: record.updatedAt,
        syncStatus: record.syncStatus,
      );
}
