import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/config/app_config.dart';
// Part files inherit this library's imports, and the generated code needs the
// enums backing every `textEnum` column below.
import '../../domain/entities/audit_event.dart';
import '../../domain/entities/disaster_type.dart';
import '../../domain/entities/hazard_severity.dart';
import '../../domain/entities/hazard_status.dart';
import '../../domain/entities/hazard_type.dart';
import '../../domain/entities/incident_status.dart';
import '../../domain/entities/responder_role.dart';
import '../../domain/entities/responder_status.dart';
import '../../domain/entities/sos_priority.dart';
import '../../domain/entities/sos_status.dart';
import '../../domain/entities/conflict_resolution.dart';
import '../../domain/entities/sync_entity_type.dart';
import '../../domain/entities/sync_operation_status.dart';
import '../../domain/entities/sync_operation_type.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/entities/task_priority.dart';
import '../../domain/entities/task_status.dart';
import '../../domain/entities/triage_category.dart';
import '../../domain/entities/victim_demographics.dart';
import '../../domain/entities/victim_status.dart';
import 'tables/app_metadata.dart';
import 'tables/audit_events.dart';
import 'tables/hazards.dart';
import 'tables/incidents.dart';
import 'tables/local_sessions.dart';
import 'tables/locations.dart';
import 'tables/responder_statuses.dart';
import 'tables/sos_events.dart';
import 'tables/sync_conflicts.dart';
import 'tables/sync_entity_heads.dart';
import 'tables/sync_operations.dart';
import 'tables/tasks.dart';
import 'tables/victims.dart';

part 'app_database.g.dart';

/// The device's primary operational datastore.
///
/// This is deliberately not a cache. It holds what the responder authored, and
/// it is complete without the backend. Every future table (sync_operations,
/// sync_conflicts) is added here with a matching [schemaVersion] bump and a
/// step in [migration]. See `docs/architecture.md`.
@DriftDatabase(
  tables: [
    AppMetadata,
    LocalSessions,
    Victims,
    Incidents,
    Locations,
    SosEvents,
    Hazards,
    Tasks,
    ResponderStatuses,
    AuditEvents,
    SyncOperations,
    SyncConflicts,
    SyncEntityHeads,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// Bump by one for every additive migration, and add the matching `from`
  /// branch in [migration]. Never edit a released step.
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // A device upgraded in the field keeps every record it already
          // holds, so migrations are additive only: new tables and new
          // nullable columns, never a drop and never a rewrite.
          if (from < 2) {
            await m.createTable(victims);
          }

          // Slice 3 adds field operations.
          if (from < 3) {
            await m.createTable(incidents);
            await m.createTable(locations);
            await m.createTable(sosEvents);
            await m.createTable(hazards);
            await m.createTable(tasks);
            await m.createTable(responderStatuses);
            await m.createTable(auditEvents);

            // Casualties registered by Slice 2 keep their rows and simply have
            // no incident or position recorded against them, which is the
            // truth about how they were captured.
            await m.addColumn(victims, victims.incidentId);
            await m.addColumn(victims, victims.locationAccuracy);
          }

          if (from < 4) {
            await m.addColumn(locations, locations.provider);
            await m.addColumn(locations, locations.isMocked);
          }

          // Slice 4: outbound sync queue, recorded conflicts, entity heads /
          // tombstones. Existing operational rows are unchanged.
          if (from < 5) {
            await m.createTable(syncOperations);
            await m.createTable(syncConflicts);
            await m.createTable(syncEntityHeads);
          }
        },
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Names of the tables Drift knows about, used by the health check the home
  /// screen renders.
  List<String> get tableNames =>
      allTables.map((table) => table.actualTableName).toList(growable: false);

  static QueryExecutor _open() =>
      driftDatabase(name: AppConfig.localDatabaseName);
}
