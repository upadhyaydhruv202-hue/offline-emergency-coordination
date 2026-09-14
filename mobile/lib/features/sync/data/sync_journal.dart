import '../../../core/utils/identifiers.dart';
import '../../../data/local/daos/app_metadata_dao.dart';
import '../../../data/local/daos/sync_entity_head_dao.dart';
import '../../../data/local/daos/sync_operation_dao.dart';
import '../../../data/local/tables/app_metadata.dart';
import '../../../domain/entities/audit_event.dart';
import '../../../domain/entities/sync_entity_type.dart';
import '../../../domain/entities/sync_operation.dart';
import '../../../domain/entities/sync_operation_status.dart';
import '../../../domain/entities/sync_operation_type.dart';
import '../../../domain/entities/sync_status.dart';
import '../../audit/data/audit_repository.dart';

/// Turns a local mutation into a [SyncOperation] without each feature knowing
/// how the queue is stored.
class SyncJournal {
  SyncJournal({
    required this.metadata,
    required this.operations,
    required this.heads,
    required this.audit,
  });

  final AppMetadataDao metadata;
  final SyncOperationDao operations;
  final SyncEntityHeadDao heads;
  final AuditRepository audit;

  Future<String> deviceId() => metadata.readOrCreate(
        AppMetadataKeys.deviceId,
        generateDeviceId,
      );

  Future<SyncOperation> record({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperationType operationType,
    required Map<String, Object?> payload,
    required String actorId,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final origin = await deviceId();
    final head = await heads.read(entityType, entityId);

    final counter = await metadata.nextSequence(AppMetadataKeys.logicalClock);
    final operationId = generateUuidV4();

    final operation = SyncOperation(
      id: operationId,
      operationId: operationId,
      deviceId: origin,
      actorId: actorId,
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      payload: payload,
      createdAt: timestamp,
      updatedAt: timestamp,
      syncStatus: SyncStatus.pending,
      queueStatus: SyncOperationStatus.pending,
      version: counter,
      logicalTimestamp: counter,
      parentVersion: head?.version,
    );

    await operations.insert(operation);
    await heads.upsert(
      EntityHead(
        entityType: entityType,
        entityId: entityId,
        version: counter,
        logicalTimestamp: counter,
        lastModifiedBy: actorId,
        lastModifiedDevice: origin,
        lastModifiedAt: timestamp,
        winnerOperationId: operationId,
        deleted: operationType == SyncOperationType.delete,
        deletedAt:
            operationType == SyncOperationType.delete ? timestamp : null,
        deletedBy: operationType == SyncOperationType.delete ? actorId : null,
      ),
    );

    await audit.record(
      eventType: AuditEventType.syncOperationCreated,
      entityType: AuditEntityType.sync,
      entityId: entityId,
      actorId: actorId,
      metadata: {
        'operationId': operationId,
        'entityType': entityType.wireValue,
        'operationType': operationType.wireValue,
        'logicalTimestamp': counter,
      },
      now: timestamp,
    );

    return operation;
  }
}
