import '../../../data/local/app_database.dart';
import '../../../data/local/daos/app_metadata_dao.dart';
import '../../../data/local/daos/sync_conflict_dao.dart';
import '../../../data/local/daos/sync_entity_head_dao.dart';
import '../../../data/local/daos/sync_operation_dao.dart';
import '../../../data/local/tables/app_metadata.dart';
import '../../../domain/entities/audit_event.dart';
import '../../../domain/entities/sync_conflict.dart';
import '../../../domain/entities/sync_operation.dart';
import '../../../domain/entities/sync_operation_status.dart';
import '../../../domain/entities/sync_status.dart';
import '../../audit/data/audit_repository.dart';
import '../crdt/crdt_engine.dart';
import '../data/entity_applier.dart';

class SyncStatistics {
  const SyncStatistics({
    required this.deviceId,
    required this.pending,
    required this.inFlight,
    required this.acknowledged,
    required this.failed,
    required this.conflicts,
    required this.localRecordCount,
    this.lastSyncAt,
    this.lastSyncKind,
  });

  final String deviceId;
  final int pending;
  final int inFlight;
  final int acknowledged;
  final int failed;
  final int conflicts;
  final int localRecordCount;
  final DateTime? lastSyncAt;
  final String? lastSyncKind;
}

/// Transport-independent synchronisation. BLE / Wi-Fi Direct / LoRa later
/// feed the same [applyRemoteOperations] entry point.
class SyncService {
  SyncService({
    required this.database,
    required this.metadata,
    required this.operations,
    required this.conflicts,
    required this.heads,
    required this.engine,
    required this.applier,
    required this.audit,
    required this.actorId,
  });

  final AppDatabase database;

  final AppMetadataDao metadata;
  final SyncOperationDao operations;
  final SyncConflictDao conflicts;
  final SyncEntityHeadDao heads;
  final CrdtEngine engine;
  final EntityApplier applier;
  final AuditRepository audit;
  final String actorId;

  Future<List<SyncOperation>> getPendingOperations() => operations.readPending();

  Future<List<SyncOperation>> prepareSync() async {
    final pending = await operations.readPending();
    final now = DateTime.now().toUtc();
    final inflight = [
      for (final operation in pending)
        operation.copyWith(
          queueStatus: SyncOperationStatus.inFlight,
          updatedAt: now,
        ),
    ];
    await operations.markMany(inflight);
    await audit.record(
      eventType: AuditEventType.syncStarted,
      entityType: AuditEntityType.sync,
      entityId: 'queue',
      actorId: actorId,
      metadata: {'count': inflight.length, 'kind': 'SIMULATED'},
      now: now,
    );
    return inflight;
  }

  Future<MergeResult> applyRemoteOperations(
    List<SyncOperation> incoming, {
    String kind = 'SIMULATED',
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return database.transaction(() async {
    final local = await operations.readAll();
    final result = engine.merge(
      local: local,
      incoming: incoming,
      now: timestamp,
    );

    for (final operation in incoming) {
      final reason = result.rejected[operation.operationId];
      if (reason != null) {
        await operations.insert(operation.asFailed(reason, timestamp));
        continue;
      }
      final existing =
          await operations.readByOperationId(operation.operationId);
      if (existing == null) {
        await operations.insert(
          operation.copyWith(
            queueStatus: SyncOperationStatus.acknowledged,
            syncStatus: SyncStatus.acknowledged,
            updatedAt: timestamp,
          ),
        );
      }
    }

    for (final conflict in result.conflicts) {
      await conflicts.insert(conflict);
      await audit.record(
        eventType: AuditEventType.conflictDetected,
        entityType: AuditEntityType.sync,
        entityId: conflict.entityId,
        actorId: actorId,
        metadata: {
          'winner': conflict.winnerOperation.operationId,
          'loser': conflict.loserOperation.operationId,
          'resolution': conflict.resolution.wireValue,
        },
        now: timestamp,
      );
      await audit.record(
        eventType: AuditEventType.conflictResolved,
        entityType: AuditEntityType.sync,
        entityId: conflict.entityId,
        actorId: actorId,
        metadata: {'resolution': conflict.resolution.wireValue},
        now: timestamp,
      );
    }

    for (final winner in result.winners.values) {
      await applier.apply(winner);
      await audit.record(
        eventType: AuditEventType.entityConverged,
        entityType: AuditEntityType.sync,
        entityId: winner.entityId,
        actorId: actorId,
        metadata: {
          'operationId': winner.operationId,
          'deviceId': winner.deviceId,
        },
        now: timestamp,
      );
    }

    await operations.markMany([
      for (final operation in local)
        if (result.conflicts.any(
              (conflict) =>
                  conflict.loserOperation.operationId == operation.operationId,
            ))
          operation.asConflict(timestamp)
        else if (incoming.any((remote) => remote.operationId == operation.operationId) ||
            result.winners.values.any((winner) => winner.entityId == operation.entityId))
          operation.asAcknowledged(timestamp),
    ]);

    await metadata.write(
      AppMetadataKeys.lastSyncAt,
      timestamp.toIso8601String(),
    );
    await metadata.write(AppMetadataKeys.lastSyncKind, kind);
    await audit.record(
      eventType: AuditEventType.syncCompleted,
      entityType: AuditEntityType.sync,
      entityId: 'queue',
      actorId: actorId,
      metadata: {
        'kind': kind,
        'conflicts': result.conflicts.length,
        'rejected': result.rejected.length,
      },
      now: timestamp,
    );

    return result;
    });
  }

  Future<void> markAcknowledged(Iterable<String> operationIds) async {
    final now = DateTime.now().toUtc();
    final ops = <SyncOperation>[];
    for (final id in operationIds) {
      final existing = await operations.readByOperationId(id);
      if (existing != null) ops.add(existing.asAcknowledged(now));
    }
    await operations.markMany(ops);
  }

  Future<List<SyncConflict>> resolveConflicts() async {
    final rows = await conflicts.readRows();
    return hydrateConflicts(
      rows: rows,
      readOperation: operations.readByOperationId,
    );
  }

  Future<SyncStatistics> getSyncStatistics() async {
    final deviceId = await metadata.read(AppMetadataKeys.deviceId) ?? 'unknown';
    final last = await metadata.read(AppMetadataKeys.lastSyncAt);
    return SyncStatistics(
      deviceId: deviceId,
      pending: await operations.countStatus(SyncOperationStatus.pending),
      inFlight: await operations.countStatus(SyncOperationStatus.inFlight),
      acknowledged:
          await operations.countStatus(SyncOperationStatus.acknowledged),
      failed: await operations.countStatus(SyncOperationStatus.failed),
      conflicts: (await conflicts.readRows()).length,
      localRecordCount: await operations.countAll(),
      lastSyncAt: last == null ? null : DateTime.tryParse(last)?.toUtc(),
      lastSyncKind: await metadata.read(AppMetadataKeys.lastSyncKind),
    );
  }
}

/// In-memory pipe used until Slice 5 supplies a real transport.
class SimulatedTransport {
  const SimulatedTransport();

  List<SyncOperation> exchange({
    required List<SyncOperation> fromA,
    required List<SyncOperation> fromB,
  }) =>
      [...fromA, ...fromB];
}
