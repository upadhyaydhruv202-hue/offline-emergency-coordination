import 'package:drift/drift.dart';

import '../../../domain/entities/sync_entity_type.dart';

/// Per-entity CRDT head: version, last writer, tombstone.
///
/// Tombstones live here rather than as physical deletes. Garbage collection of
/// old tombstones is future work (Slice 5+).
@DataClassName('SyncEntityHeadRow')
class SyncEntityHeads extends Table {
  TextColumn get entityType => textEnum<SyncEntityType>()();

  TextColumn get entityId => text()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  IntColumn get logicalTimestamp => integer().withDefault(const Constant(0))();

  TextColumn get lastModifiedBy => text().nullable()();

  TextColumn get lastModifiedDevice => text().nullable()();

  DateTimeColumn get lastModifiedAt => dateTime().nullable()();

  TextColumn get winnerOperationId => text().nullable()();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  TextColumn get deletedBy => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {entityType, entityId};
}
