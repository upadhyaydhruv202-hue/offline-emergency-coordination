import 'package:drp_mobile/data/local/app_database.dart';
import 'package:drp_mobile/data/local/daos/app_metadata_dao.dart';
import 'package:drp_mobile/data/local/daos/audit_dao.dart';
import 'package:drp_mobile/data/local/daos/hazard_dao.dart';
import 'package:drp_mobile/data/local/daos/incident_dao.dart';
import 'package:drp_mobile/data/local/daos/location_dao.dart';
import 'package:drp_mobile/data/local/daos/responder_status_dao.dart';
import 'package:drp_mobile/data/local/daos/sos_dao.dart';
import 'package:drp_mobile/data/local/daos/task_dao.dart';
import 'package:drp_mobile/data/local/daos/victim_dao.dart';
import 'package:drp_mobile/domain/entities/audit_event.dart';
import 'package:drp_mobile/domain/entities/disaster_type.dart';
import 'package:drp_mobile/domain/entities/hazard_draft.dart';
import 'package:drp_mobile/domain/entities/hazard_query.dart';
import 'package:drp_mobile/domain/entities/hazard_severity.dart';
import 'package:drp_mobile/domain/entities/hazard_status.dart';
import 'package:drp_mobile/domain/entities/hazard_type.dart';
import 'package:drp_mobile/domain/entities/incident_draft.dart';
import 'package:drp_mobile/domain/entities/incident_status.dart';
import 'package:drp_mobile/domain/entities/location_fix.dart';
import 'package:drp_mobile/domain/entities/responder_status.dart';
import 'package:drp_mobile/domain/entities/sos_priority.dart';
import 'package:drp_mobile/domain/entities/sos_status.dart';
import 'package:drp_mobile/domain/entities/sync_status.dart';
import 'package:drp_mobile/domain/entities/task_draft.dart';
import 'package:drp_mobile/domain/entities/task_priority.dart';
import 'package:drp_mobile/domain/entities/task_status.dart';
import 'package:drp_mobile/domain/entities/triage_category.dart';
import 'package:drp_mobile/domain/entities/victim_draft.dart';
import 'package:drp_mobile/features/audit/data/audit_repository.dart';
import 'package:drp_mobile/features/hazards/data/hazard_repository.dart';
import 'package:drp_mobile/features/incidents/data/incident_repository.dart';
import 'package:drp_mobile/features/location/data/location_repository.dart';
import 'package:drp_mobile/features/location/data/location_service.dart';
import 'package:drp_mobile/features/responder/data/responder_status_repository.dart';
import 'package:drp_mobile/features/sos/data/sos_repository.dart';
import 'package:drp_mobile/features/tasks/data/task_repository.dart';
import 'package:drp_mobile/features/victims/data/victim_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_location.dart';
import 'helpers/test_database.dart';

/// Slice 3 field operations against the real schema.
///
/// Nothing here constructs an HTTP client. If a write needed the backend, these
/// tests would fail the moment the radio was off.
void main() {
  late AppDatabase database;
  late IncidentRepository incidents;
  late SosRepository sos;
  late HazardRepository hazards;
  late TaskRepository tasks;
  late LocationRepository locations;
  late ResponderStatusRepository responderStatus;
  late AuditRepository audit;
  late VictimRepository victims;

  const actor = 'offline-abc123';
  final fix = LocationFix(
    latitude: 23.0225,
    longitude: 72.5714,
    accuracy: 8,
    timestamp: DateTime.utc(2026, 9, 8, 11, 12, 18),
  );

  setUp(() {
    database = openTestDatabase();
    final metadata = AppMetadataDao(database);
    incidents = IncidentRepository(
      incidents: IncidentDao(database),
      metadata: metadata,
    );
    sos = SosRepository(events: SosDao(database), metadata: metadata);
    hazards = HazardRepository(hazards: HazardDao(database), metadata: metadata);
    tasks = TaskRepository(tasks: TaskDao(database), metadata: metadata);
    locations = LocationRepository(
      locations: LocationDao(database),
      service: LocationService(source: FakeLocationSource(fix: fix)),
    );
    responderStatus = ResponderStatusRepository(ResponderStatusDao(database));
    audit = AuditRepository(AuditDao(database));
    victims = VictimRepository(
      victims: VictimDao(database),
      metadata: metadata,
    );
  });

  tearDown(() => database.close());

  Future<String> declareAhmedabad() async {
    final incident = await incidents.declare(
      draft: const IncidentDraft(
        title: 'Ahmedabad Earthquake Response',
        disasterType: DisasterType.earthquake,
        assignedZone: 'AHMEDABAD ZONE 04',
      ),
      createdBy: actor,
    );
    await incidents.selectCurrent(incident.id);
    return incident.id;
  }

  group('schema', () {
    test('is at version 4 and carries the field-ops tables', () async {
      await database.select(database.appMetadata).get();

      expect(database.schemaVersion, 5);
      expect(
        database.tableNames,
        containsAll(<String>[
          'app_metadata',
          'local_sessions',
          'victims',
          'incidents',
          'locations',
          'sos_events',
          'hazards',
          'tasks',
          'responder_status',
          'audit_events',
        ]),
      );
    });
  });

  group('incidents', () {
    test('declares a complete local record without a backend', () async {
      final incident = await incidents.declare(
        draft: const IncidentDraft(
          title: 'Ahmedabad Earthquake Response',
          disasterType: DisasterType.earthquake,
          assignedZone: 'AHMEDABAD ZONE 04',
        ),
        createdBy: actor,
      );

      final stored = await incidents.readIncident(incident.id);

      expect(stored, isNotNull);
      expect(stored!.title, 'Ahmedabad Earthquake Response');
      expect(stored.disasterType, DisasterType.earthquake);
      expect(stored.status, IncidentStatus.active);
      expect(stored.assignedZone, 'AHMEDABAD ZONE 04');
      expect(stored.incidentCode, startsWith('INC-'));
      expect(stored.syncStatus, SyncStatus.pending);
      expect(stored.createdBy, actor);
    });

    test('current incident persists in metadata and survives a re-read',
        () async {
      final id = await declareAhmedabad();

      expect(await incidents.readCurrentIncidentId(), id);
      expect((await incidents.readCurrentIncident())!.id, id);

      await incidents.clearCurrent();
      expect(await incidents.readCurrentIncident(), isNull);
    });

    test('status change is local and stays pending', () async {
      final incident = await incidents.declare(
        draft: const IncidentDraft(
          title: 'Flood sector',
          disasterType: DisasterType.flood,
        ),
        createdBy: actor,
      );

      final paused = await incidents.changeStatus(
        incident: incident,
        status: IncidentStatus.paused,
        modifiedBy: actor,
      );

      expect(paused.status, IncidentStatus.paused);
      expect(paused.syncStatus, SyncStatus.pending);
      expect(paused.lastModifiedBy, actor);
    });
  });

  group('location', () {
    test('stores a GPS fix without using the network', () async {
      final record = await locations.capture(
        responderId: actor,
        incidentId: 'inc-1',
      );

      expect(record.latitude, 23.0225);
      expect(record.longitude, 72.5714);
      expect(record.accuracy, 8);
      expect(record.syncStatus, SyncStatus.pending);
      expect(record.responderId, actor);

      final latest = await locations.readLatestFor(actor);
      expect(latest!.id, record.id);
    });
  });

  group('sos', () {
    test('raises a local SOS with pending sync status', () async {
      final event = await sos.raise(
        createdBy: actor,
        priority: SosPriority.critical,
        incidentId: 'inc-1',
        position: fix,
        message: 'Trapped on second floor',
      );

      expect(event.sosCode, startsWith('SOS-'));
      expect(event.status, SosStatus.created);
      expect(event.syncStatus, SyncStatus.pending);
      expect(event.latitude, 23.0225);
      expect(event.message, 'Trapped on second floor');

      final stored = await sos.readEvent(event.id);
      expect(stored!.id, event.id);
    });

    test('resolves an SOS locally', () async {
      final event = await sos.raise(
        createdBy: actor,
        priority: SosPriority.high,
      );
      final resolved = await sos.changeStatus(
        event: event,
        status: SosStatus.resolved,
      );

      expect(resolved.status, SosStatus.resolved);
      expect(resolved.syncStatus, SyncStatus.pending);
    });
  });

  group('hazards', () {
    test('reports a hazard offline and sorts critical first', () async {
      await hazards.report(
        draft: const HazardDraft(
          type: HazardType.roadBlocked,
          severity: HazardSeverity.low,
        ),
        reportedBy: actor,
      );
      await hazards.report(
        draft: const HazardDraft(
          type: HazardType.buildingDamage,
          severity: HazardSeverity.critical,
          description: 'North stairwell shifting',
        ),
        reportedBy: actor,
        incidentId: 'inc-1',
      );

      final list = await hazards.readHazards();
      expect(list.first.severity, HazardSeverity.critical);
      expect(list.first.syncStatus, SyncStatus.pending);
      expect(list.first.hazardCode, startsWith('HZ-'));

      final filtered = await hazards.readHazards(
        const HazardQuery(severity: HazardSeverity.critical),
      );
      expect(filtered, hasLength(1));
    });

    test('status change persists', () async {
      final hazard = await hazards.report(
        draft: const HazardDraft(
          type: HazardType.fire,
          severity: HazardSeverity.high,
        ),
        reportedBy: actor,
      );

      final resolved = await hazards.changeStatus(
        hazard: hazard,
        status: HazardStatus.resolved,
      );
      expect(resolved.status, HazardStatus.resolved);
      expect(resolved.syncStatus, SyncStatus.pending);
    });
  });

  group('tasks', () {
    test('creates a task and walks the lifecycle locally', () async {
      var task = await tasks.create(
        draft: const TaskDraft(
          title: 'Search collapsed building',
          priority: TaskPriority.high,
          location: 'Block C stairwell',
        ),
        createdBy: actor,
        incidentId: 'inc-1',
      );

      expect(task.taskCode, startsWith('TASK-'));
      expect(task.status, TaskStatus.pending);
      expect(task.assignedTo, actor);
      expect(task.syncStatus, SyncStatus.pending);

      task = await tasks.changeStatus(
        task: task,
        status: TaskStatus.accepted,
        claimedBy: actor,
      );
      expect(task.status, TaskStatus.accepted);

      task = await tasks.changeStatus(task: task, status: TaskStatus.inProgress);
      expect(task.status, TaskStatus.inProgress);

      task = await tasks.changeStatus(task: task, status: TaskStatus.completed);
      expect(task.status, TaskStatus.completed);
      expect(task.syncStatus, SyncStatus.pending);
    });
  });

  group('responder status', () {
    test('defaults to available and persists a change', () async {
      expect(await responderStatus.readStatus(actor), ResponderStatus.available);

      final record = await responderStatus.setStatus(
        responderId: actor,
        status: ResponderStatus.onMission,
        incidentId: 'inc-1',
      );

      expect(record.status, ResponderStatus.onMission);
      expect(record.syncStatus, SyncStatus.pending);
      expect(await responderStatus.readStatus(actor), ResponderStatus.onMission);
    });
  });

  group('victims + current context', () {
    test('registration stores incident and position from context', () async {
      final incidentId = await declareAhmedabad();

      final victim = await victims.register(
        draft: const VictimDraft(
          triageCategory: TriageCategory.critical,
          name: 'A. Sharma',
        ),
        createdBy: actor,
        incidentId: incidentId,
        position: fix,
      );

      expect(victim.incidentId, incidentId);
      expect(victim.latitude, 23.0225);
      expect(victim.longitude, 72.5714);
      expect(victim.locationAccuracy, 8);
      expect(victim.syncStatus, SyncStatus.pending);
    });
  });

  group('audit', () {
    test('records operational events without blocking a write', () async {
      final incidentId = await declareAhmedabad();
      await audit.record(
        eventType: AuditEventType.incidentSelected,
        entityType: AuditEntityType.incident,
        entityId: incidentId,
        actorId: actor,
        metadata: {'title': 'Ahmedabad Earthquake Response'},
      );

      final trail = await audit.readRecent();
      expect(trail, isNotEmpty);
      expect(trail.first.eventType, AuditEventType.incidentSelected);
      expect(trail.first.syncStatus, SyncStatus.pending);
      expect(trail.first.metadata, contains('Ahmedabad'));
    });
  });
}
