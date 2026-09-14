import 'package:drift/drift.dart';

import '../../../domain/entities/conflict_resolution.dart';
import '../../../domain/entities/sync_entity_type.dart';
import '../../../domain/entities/sync_status.dart';

@TableIndex(name: 'idx_sync_conflicts_entity_id', columns: {#entityId})
@DataClassName('SyncConflictRow')
class SyncConflicts extends Table {
  TextColumn get id => text()();

  TextColumn get entityType => textEnum<SyncEntityType>()();

  TextColumn get entityId => text()();

  TextColumn get operationAId => text()();

  TextColumn get operationBId => text()();

  DateTimeColumn get detectedAt => dateTime()();

  TextColumn get resolution => textEnum<ConflictResolution>()();

  TextColumn get winnerOperationId => text()();

  TextColumn get loserOperationId => text()();

  TextColumn get reason => text()();

  DateTimeColumn get resolvedAt => dateTime().nullable()();

  TextColumn get syncStatus => textEnum<SyncStatus>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
