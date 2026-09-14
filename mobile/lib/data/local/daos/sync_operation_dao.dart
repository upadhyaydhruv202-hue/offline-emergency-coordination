import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/entities/sync_operation.dart';
import '../../../domain/entities/sync_operation_status.dart';
import '../app_database.dart';

class SyncOperationDao {
  const SyncOperationDao(this._db);

  final AppDatabase _db;

  Future<void> insert(SyncOperation operation) =>
      _db.into(_db.syncOperations).insertOnConflictUpdate(_toRow(operation));

  Future<SyncOperation?> readByOperationId(String operationId) async {
    final row = await (_db.select(_db.syncOperations)
          ..where((op) => op.operationId.equals(operationId)))
        .getSingleOrNull();
    return row == null ? null : _toOperation(row);
  }

  Future<List<SyncOperation>> readPending() => (_db.select(_db.syncOperations)
        ..where(
          (op) =>
              op.queueStatus.equalsValue(SyncOperationStatus.pending) |
              op.queueStatus.equalsValue(SyncOperationStatus.failed),
        )
        ..orderBy([(op) => OrderingTerm.asc(op.logicalTimestamp)]))
      .get()
      .then(_map);

  Stream<List<SyncOperation>> watchPending() => (_db.select(_db.syncOperations)
        ..where(
          (op) => op.queueStatus.equalsValue(SyncOperationStatus.pending),
        )
        ..orderBy([(op) => OrderingTerm.desc(op.createdAt)]))
      .watch()
      .map(_map);

  Stream<List<SyncOperation>> watchAll({int limit = 100}) =>
      (_db.select(_db.syncOperations)
            ..orderBy([(op) => OrderingTerm.desc(op.createdAt)])
            ..limit(limit))
          .watch()
          .map(_map);

  Future<List<SyncOperation>> readAll() => (_db.select(_db.syncOperations)
        ..orderBy([(op) => OrderingTerm.asc(op.logicalTimestamp)]))
      .get()
      .then(_map);

  Future<List<SyncOperation>> readForEntity(String entityId) =>
      (_db.select(_db.syncOperations)
            ..where((op) => op.entityId.equals(entityId)))
          .get()
          .then(_map);

  Stream<int> watchCount(SyncOperationStatus status) {
    final count = _db.syncOperations.id.count(
      filter: _db.syncOperations.queueStatus.equalsValue(status),
    );
    final query = _db.selectOnly(_db.syncOperations)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<int> countStatus(SyncOperationStatus status) async {
    final count = _db.syncOperations.id.count(
      filter: _db.syncOperations.queueStatus.equalsValue(status),
    );
    final query = _db.selectOnly(_db.syncOperations)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<int> countAll() async {
    final count = _db.syncOperations.id.count();
    final query = _db.selectOnly(_db.syncOperations)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<void> markMany(Iterable<SyncOperation> operations) async {
    await _db.transaction(() async {
      for (final operation in operations) {
        await (_db.update(_db.syncOperations)
              ..where((op) => op.operationId.equals(operation.operationId)))
            .write(_toRow(operation));
      }
    });
  }

  Future<void> deleteAll() => _db.delete(_db.syncOperations).go();

  static List<SyncOperation> _map(List<SyncOperationRow> rows) =>
      rows.map(_toOperation).toList(growable: false);

  static SyncOperationsCompanion _toRow(SyncOperation operation) =>
      SyncOperationsCompanion.insert(
        id: operation.id,
        operationId: operation.operationId,
        deviceId: operation.deviceId,
        actorId: operation.actorId,
        entityType: operation.entityType,
        entityId: operation.entityId,
        operationType: operation.operationType,
        payloadJson: jsonEncode(operation.payload),
        createdAt: operation.createdAt,
        updatedAt: operation.updatedAt,
        syncStatus: operation.syncStatus,
        queueStatus: operation.queueStatus,
        version: operation.version,
        logicalTimestamp: operation.logicalTimestamp,
        parentVersion: Value(operation.parentVersion),
        failureReason: Value(operation.failureReason),
      );

  static SyncOperation _toOperation(SyncOperationRow row) {
    final decoded = jsonDecode(row.payloadJson);
    return SyncOperation(
      id: row.id,
      operationId: row.operationId,
      deviceId: row.deviceId,
      actorId: row.actorId,
      entityType: row.entityType,
      entityId: row.entityId,
      operationType: row.operationType,
      payload: decoded is Map<String, dynamic>
          ? Map<String, Object?>.from(decoded)
          : <String, Object?>{},
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      syncStatus: row.syncStatus,
      queueStatus: row.queueStatus,
      version: row.version,
      logicalTimestamp: row.logicalTimestamp,
      parentVersion: row.parentVersion,
      failureReason: row.failureReason,
    );
  }
}
