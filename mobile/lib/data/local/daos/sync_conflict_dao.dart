import 'package:drift/drift.dart';

import '../../../domain/entities/sync_conflict.dart';
import '../../../domain/entities/sync_operation.dart';
import '../app_database.dart';

class SyncConflictDao {
  const SyncConflictDao(this._db);

  final AppDatabase _db;

  Future<void> insert(SyncConflict conflict) =>
      _db.into(_db.syncConflicts).insertOnConflictUpdate(_toRow(conflict));

  Stream<List<SyncConflictRow>> watchRows() => (_db.select(_db.syncConflicts)
        ..orderBy([(row) => OrderingTerm.desc(row.detectedAt)]))
      .watch();

  Future<List<SyncConflictRow>> readRows() => (_db.select(_db.syncConflicts)
        ..orderBy([(row) => OrderingTerm.desc(row.detectedAt)]))
      .get();

  Future<SyncConflictRow?> readRow(String id) =>
      (_db.select(_db.syncConflicts)..where((row) => row.id.equals(id)))
          .getSingleOrNull();

  Stream<int> watchCount() {
    final count = _db.syncConflicts.id.count();
    final query = _db.selectOnly(_db.syncConflicts)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<void> deleteAll() => _db.delete(_db.syncConflicts).go();

  static SyncConflictsCompanion _toRow(SyncConflict conflict) =>
      SyncConflictsCompanion.insert(
        id: conflict.id,
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        operationAId: conflict.operationA.operationId,
        operationBId: conflict.operationB.operationId,
        detectedAt: conflict.detectedAt,
        resolution: conflict.resolution,
        winnerOperationId: conflict.winnerOperation.operationId,
        loserOperationId: conflict.loserOperation.operationId,
        reason: conflict.reason,
        resolvedAt: Value(conflict.resolvedAt),
        syncStatus: conflict.syncStatus,
      );
}

/// Hydrate [SyncConflict] rows with the operations they name.
Future<List<SyncConflict>> hydrateConflicts({
  required List<SyncConflictRow> rows,
  required Future<SyncOperation?> Function(String id) readOperation,
}) async {
  final conflicts = <SyncConflict>[];
  for (final row in rows) {
    final a = await readOperation(row.operationAId);
    final b = await readOperation(row.operationBId);
    final winner = await readOperation(row.winnerOperationId);
    final loser = await readOperation(row.loserOperationId);
    if (a == null || b == null || winner == null || loser == null) continue;
    conflicts.add(
      SyncConflict(
        id: row.id,
        entityType: row.entityType,
        entityId: row.entityId,
        operationA: a,
        operationB: b,
        detectedAt: row.detectedAt,
        resolution: row.resolution,
        winnerOperation: winner,
        loserOperation: loser,
        reason: row.reason,
        resolvedAt: row.resolvedAt,
        syncStatus: row.syncStatus,
      ),
    );
  }
  return conflicts;
}
