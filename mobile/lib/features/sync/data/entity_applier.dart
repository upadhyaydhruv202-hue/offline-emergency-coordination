import '../../../data/local/daos/hazard_dao.dart';
import '../../../data/local/daos/incident_dao.dart';
import '../../../data/local/daos/responder_status_dao.dart';
import '../../../data/local/daos/sos_dao.dart';
import '../../../data/local/daos/sync_entity_head_dao.dart';
import '../../../data/local/daos/task_dao.dart';
import '../../../data/local/daos/victim_dao.dart';
import '../../../domain/entities/sync_entity_type.dart';
import '../../../domain/entities/sync_operation.dart';
import '../../../domain/entities/sync_operation_type.dart';
import '../../../domain/entities/incident_status.dart';
import '../../../domain/entities/responder_status.dart';
import '../../../domain/entities/sos_priority.dart';
import '../../../domain/entities/sos_status.dart';
import '../../../domain/entities/sync_status.dart';
import '../../../domain/entities/task_priority.dart';
import '../../../domain/entities/task_status.dart';
import '../../../domain/entities/triage_category.dart';
import '../../../domain/entities/victim_status.dart';
import 'entity_payloads.dart';

/// Writes a winning CRDT snapshot back into the operational tables.
class EntityApplier {
  EntityApplier({
    required this.hazards,
    required this.victims,
    required this.incidents,
    required this.tasks,
    required this.sos,
    required this.responderStatuses,
    required this.heads,
  });

  final HazardDao hazards;
  final VictimDao victims;
  final IncidentDao incidents;
  final TaskDao tasks;
  final SosDao sos;
  final ResponderStatusDao responderStatuses;
  final SyncEntityHeadDao heads;

  Future<void> apply(SyncOperation winner) async {
    final deleted = winner.operationType == SyncOperationType.delete;
    await heads.upsert(
      EntityHead(
        entityType: winner.entityType,
        entityId: winner.entityId,
        version: winner.version,
        logicalTimestamp: winner.logicalTimestamp,
        lastModifiedBy: winner.actorId,
        lastModifiedDevice: winner.deviceId,
        lastModifiedAt: winner.updatedAt,
        winnerOperationId: winner.operationId,
        deleted: deleted,
        deletedAt: deleted ? winner.updatedAt : null,
        deletedBy: deleted ? winner.actorId : null,
      ),
    );

    if (deleted) return;

    switch (winner.entityType) {
      case SyncEntityType.hazard:
        final hazard = hazardFromPayload(winner.payload);
        if (hazard == null) return;
        final existing = await hazards.readHazard(hazard.id);
        final stored = hazard.copyWith(
          syncStatus: SyncStatus.acknowledged,
          updatedAt: winner.updatedAt,
        );
        if (existing == null) {
          await hazards.insertHazard(stored);
        } else {
          await hazards.updateHazard(stored);
        }
      case SyncEntityType.victim:
        final existing = await victims.readVictim(winner.entityId);
        if (existing == null) return;
        await victims.updateVictim(
          existing.copyWith(
            triageCategory: TriageCategory.tryFromWire(
                  winner.payload['triageCategory'] as String?,
                ) ??
                existing.triageCategory,
            status: VictimStatus.tryFromWire(
                  winner.payload['status'] as String?,
                ) ??
                existing.status,
            syncStatus: SyncStatus.acknowledged,
            updatedAt: winner.updatedAt,
          ),
        );
      case SyncEntityType.incident:
        final existing = await incidents.readIncident(winner.entityId);
        if (existing == null) return;
        await incidents.updateIncident(
          existing.copyWith(
            status: IncidentStatus.tryFromWire(
                  winner.payload['status'] as String?,
                ) ??
                existing.status,
            syncStatus: SyncStatus.acknowledged,
            updatedAt: winner.updatedAt,
          ),
        );
      case SyncEntityType.task:
        final existing = await tasks.readTask(winner.entityId);
        if (existing == null) return;
        await tasks.updateTask(
          existing.copyWith(
            status: TaskStatus.tryFromWire(
                  winner.payload['status'] as String?,
                ) ??
                existing.status,
            priority: TaskPriority.tryFromWire(
                  winner.payload['priority'] as String?,
                ) ??
                existing.priority,
            syncStatus: SyncStatus.acknowledged,
            updatedAt: winner.updatedAt,
          ),
        );
      case SyncEntityType.sos:
        final existing = await sos.readEvent(winner.entityId);
        if (existing == null) return;
        await sos.updateEvent(
          existing.copyWith(
            status: SosStatus.tryFromWire(
                  winner.payload['status'] as String?,
                ) ??
                existing.status,
            priority: SosPriority.tryFromWire(
                  winner.payload['priority'] as String?,
                ) ??
                existing.priority,
            syncStatus: SyncStatus.acknowledged,
            updatedAt: winner.updatedAt,
          ),
        );
      case SyncEntityType.responderStatus:
        final existing =
            await responderStatuses.readFor(winner.entityId);
        if (existing == null) return;
        await responderStatuses.save(
          existing.copyWith(
            status: ResponderStatus.tryFromWire(
                  winner.payload['status'] as String?,
                ) ??
                existing.status,
            syncStatus: SyncStatus.acknowledged,
            updatedAt: winner.updatedAt,
          ),
        );
    }
  }
}
