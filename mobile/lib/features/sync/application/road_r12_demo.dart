import 'package:drift/native.dart';

import '../../../data/local/app_database.dart';
import '../../../data/local/daos/app_metadata_dao.dart';
import '../../../data/local/daos/audit_dao.dart';
import '../../../data/local/daos/hazard_dao.dart';
import '../../../data/local/daos/incident_dao.dart';
import '../../../data/local/daos/responder_status_dao.dart';
import '../../../data/local/daos/sos_dao.dart';
import '../../../data/local/daos/sync_conflict_dao.dart';
import '../../../data/local/daos/sync_entity_head_dao.dart';
import '../../../data/local/daos/sync_operation_dao.dart';
import '../../../data/local/daos/task_dao.dart';
import '../../../data/local/daos/victim_dao.dart';
import '../../../data/local/tables/app_metadata.dart';
import '../../../domain/entities/disaster_type.dart';
import '../../../domain/entities/hazard.dart';
import '../../../domain/entities/hazard_severity.dart';
import '../../../domain/entities/hazard_status.dart';
import '../../../domain/entities/hazard_type.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/entities/incident_status.dart';
import '../../../domain/entities/sync_entity_type.dart';
import '../../../domain/entities/sync_operation.dart';
import '../../../domain/entities/sync_operation_type.dart';
import '../../../domain/entities/sync_status.dart';
import '../../audit/data/audit_repository.dart';
import '../crdt/crdt_engine.dart';
import '../data/entity_applier.dart';
import '../data/entity_payloads.dart';
import '../data/sync_journal.dart';
import 'sync_service.dart';

/// Shared ids so Device A and Device B edit the same Road R-12 entity.
class RoadR12Demo {
  static const entityId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0012';
  static const incidentId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeee0004';
  static const hazardCode = 'HZ-R12-001';
  static const incidentCode = 'INC-ZONE-04';
}

class DeviceHarness {
  DeviceHarness(this.database, {required this.deviceId, required this.actorId})
      : metadata = AppMetadataDao(database),
        hazards = HazardDao(database),
        operations = SyncOperationDao(database),
        conflicts = SyncConflictDao(database),
        heads = SyncEntityHeadDao(database) {
    journal = SyncJournal(
      metadata: metadata,
      operations: operations,
      heads: heads,
      audit: AuditRepository(AuditDao(database)),
    );
    service = SyncService(
      database: database,
      metadata: metadata,
      operations: operations,
      conflicts: conflicts,
      heads: heads,
      engine: const CrdtEngine(),
      applier: EntityApplier(
        hazards: hazards,
        victims: VictimDao(database),
        incidents: IncidentDao(database),
        tasks: TaskDao(database),
        sos: SosDao(database),
        responderStatuses: ResponderStatusDao(database),
        heads: heads,
      ),
      audit: AuditRepository(AuditDao(database)),
      actorId: actorId,
    );
  }

  final AppDatabase database;
  final String deviceId;
  final String actorId;
  final AppMetadataDao metadata;
  final HazardDao hazards;
  final SyncOperationDao operations;
  final SyncConflictDao conflicts;
  final SyncEntityHeadDao heads;
  late final SyncJournal journal;
  late final SyncService service;

  static Future<DeviceHarness> open({
    required String deviceId,
    required String actorId,
    AppDatabase? database,
  }) async {
    final db = database ?? AppDatabase(NativeDatabase.memory());
    final harness = DeviceHarness(db, deviceId: deviceId, actorId: actorId);
    await harness.metadata.write(AppMetadataKeys.deviceId, deviceId);
    return harness;
  }

  Future<void> seedIncidentAndRoad() async {
    final now = DateTime.utc(2026, 9, 14, 12);
    final incidents = IncidentDao(database);
    if (await incidents.readIncident(RoadR12Demo.incidentId) == null) {
      await incidents.insertIncident(
        Incident(
          id: RoadR12Demo.incidentId,
          incidentCode: RoadR12Demo.incidentCode,
          title: 'Ahmedabad Earthquake Response',
          disasterType: DisasterType.earthquake,
          status: IncidentStatus.active,
          assignedZone: 'ZONE 04',
          createdAt: now,
          updatedAt: now,
          createdBy: actorId,
          syncStatus: SyncStatus.pending,
        ),
      );
    }
    if (await hazards.readHazard(RoadR12Demo.entityId) == null) {
      final hazard = Hazard(
        id: RoadR12Demo.entityId,
        hazardCode: RoadR12Demo.hazardCode,
        incidentId: RoadR12Demo.incidentId,
        reportedBy: actorId,
        type: HazardType.roadBlocked,
        severity: HazardSeverity.high,
        priority: HazardSeverity.high.priority,
        description: 'Road R-12',
        observedAt: now,
        status: HazardStatus.reported,
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      );
      await hazards.insertHazard(hazard);
      await journal.record(
        entityType: SyncEntityType.hazard,
        entityId: hazard.id,
        operationType: SyncOperationType.create,
        payload: hazardPayload(hazard),
        actorId: actorId,
        now: now,
      );
    }
  }

  Future<SyncOperation> reportBlocked() => _updateRoad(
        type: HazardType.roadBlocked,
        severity: HazardSeverity.high,
      );

  Future<SyncOperation> reportPartiallyAccessible() => _updateRoad(
        type: HazardType.partiallyAccessible,
        severity: HazardSeverity.medium,
      );

  Future<SyncOperation> _updateRoad({
    required HazardType type,
    required HazardSeverity severity,
  }) async {
    final existing = await hazards.readHazard(RoadR12Demo.entityId);
    if (existing == null) {
      throw StateError('Road R-12 is not on this device');
    }
    final updated = existing.copyWith(
      type: type,
      severity: severity,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: SyncStatus.pending,
    );
    await hazards.updateHazard(updated);
    return journal.record(
      entityType: SyncEntityType.hazard,
      entityId: updated.id,
      operationType: SyncOperationType.update,
      payload: hazardPayload(updated),
      actorId: actorId,
    );
  }

  Future<void> close() => database.close();
}

/// Runs the judge scenario: two isolated SQLite databases, simulated transport,
/// same CRDT engine the production path uses.
Future<({DeviceHarness a, DeviceHarness b, MergeResult result})>
    runRoadR12Scenario({AppDatabase? deviceA}) async {
  final a = await DeviceHarness.open(
    deviceId: 'DRP-ALPHA001',
    actorId: 'responder-alpha',
    database: deviceA,
  );
  final b = await DeviceHarness.open(
    deviceId: 'DRP-BRAVO001',
    actorId: 'responder-bravo',
  );
  await a.seedIncidentAndRoad();
  await b.seedIncidentAndRoad();
  await a.reportBlocked();
  await b.reportPartiallyAccessible();

  const transport = SimulatedTransport();
  final exchanged = transport.exchange(
    fromA: await a.operations.readAll(),
    fromB: await b.operations.readAll(),
  );

  final resultA = await a.service.applyRemoteOperations(exchanged);
  final resultB = await b.service.applyRemoteOperations(exchanged);
  assert(resultA.winners[RoadR12Demo.entityId]?.operationId ==
      resultB.winners[RoadR12Demo.entityId]?.operationId);
  return (a: a, b: b, result: resultA);
}
