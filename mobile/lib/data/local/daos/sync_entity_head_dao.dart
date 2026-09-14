import 'package:drift/drift.dart';

import '../../../domain/entities/sync_entity_type.dart';
import '../app_database.dart';

class EntityHead {
  const EntityHead({
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.logicalTimestamp,
    required this.deleted,
    this.lastModifiedBy,
    this.lastModifiedDevice,
    this.lastModifiedAt,
    this.winnerOperationId,
    this.deletedAt,
    this.deletedBy,
  });

  final SyncEntityType entityType;
  final String entityId;
  final int version;
  final int logicalTimestamp;
  final bool deleted;
  final String? lastModifiedBy;
  final String? lastModifiedDevice;
  final DateTime? lastModifiedAt;
  final String? winnerOperationId;
  final DateTime? deletedAt;
  final String? deletedBy;
}

class SyncEntityHeadDao {
  const SyncEntityHeadDao(this._db);

  final AppDatabase _db;

  Future<EntityHead?> read(SyncEntityType type, String id) async {
    final row = await (_db.select(_db.syncEntityHeads)
          ..where(
            (head) => head.entityType.equalsValue(type) & head.entityId.equals(id),
          ))
        .getSingleOrNull();
    return row == null ? null : _toHead(row);
  }

  Future<void> upsert(EntityHead head) =>
      _db.into(_db.syncEntityHeads).insertOnConflictUpdate(
            SyncEntityHeadsCompanion.insert(
              entityType: head.entityType,
              entityId: head.entityId,
              version: Value(head.version),
              logicalTimestamp: Value(head.logicalTimestamp),
              lastModifiedBy: Value(head.lastModifiedBy),
              lastModifiedDevice: Value(head.lastModifiedDevice),
              lastModifiedAt: Value(head.lastModifiedAt),
              winnerOperationId: Value(head.winnerOperationId),
              deleted: Value(head.deleted),
              deletedAt: Value(head.deletedAt),
              deletedBy: Value(head.deletedBy),
            ),
          );

  Future<int> countNotDeleted() async {
    final count = _db.syncEntityHeads.entityId.count(
      filter: _db.syncEntityHeads.deleted.equals(false),
    );
    final query = _db.selectOnly(_db.syncEntityHeads)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<void> deleteAll() => _db.delete(_db.syncEntityHeads).go();

  static EntityHead _toHead(SyncEntityHeadRow row) => EntityHead(
        entityType: row.entityType,
        entityId: row.entityId,
        version: row.version,
        logicalTimestamp: row.logicalTimestamp,
        lastModifiedBy: row.lastModifiedBy,
        lastModifiedDevice: row.lastModifiedDevice,
        lastModifiedAt: row.lastModifiedAt,
        winnerOperationId: row.winnerOperationId,
        deleted: row.deleted,
        deletedAt: row.deletedAt,
        deletedBy: row.deletedBy,
      );
}
