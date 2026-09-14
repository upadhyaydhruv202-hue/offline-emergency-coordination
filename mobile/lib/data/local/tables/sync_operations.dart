import 'package:drift/drift.dart';

import '../../../domain/entities/sync_entity_type.dart';
import '../../../domain/entities/sync_operation_status.dart';
import '../../../domain/entities/sync_operation_type.dart';
import '../../../domain/entities/sync_status.dart';

@TableIndex(name: 'idx_sync_operations_entity_id', columns: {#entityId})
@TableIndex(name: 'idx_sync_operations_logical_timestamp', columns: {#logicalTimestamp})
@DataClassName('SyncOperationRow')
class SyncOperations extends Table {
  TextColumn get id => text()();

  TextColumn get operationId => text().unique()();

  TextColumn get deviceId => text().withLength(min: 3, max: 64)();

  TextColumn get actorId => text().withLength(min: 1, max: 128)();

  TextColumn get entityType => textEnum<SyncEntityType>()();

  TextColumn get entityId => text()();

  TextColumn get operationType => textEnum<SyncOperationType>()();

  /// JSON object. Validated on ingest; never executed.
  TextColumn get payloadJson => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  TextColumn get syncStatus => textEnum<SyncStatus>()();

  TextColumn get queueStatus => textEnum<SyncOperationStatus>()();

  IntColumn get version => integer()();

  IntColumn get logicalTimestamp => integer()();

  IntColumn get parentVersion => integer().nullable()();

  TextColumn get failureReason => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
