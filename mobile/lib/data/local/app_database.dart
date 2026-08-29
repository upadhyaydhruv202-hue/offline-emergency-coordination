import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/config/app_config.dart';
// Part files inherit this library's imports, and the generated code needs the
// enums backing every `textEnum` column below.
import '../../domain/entities/responder_role.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/entities/triage_category.dart';
import '../../domain/entities/victim_demographics.dart';
import '../../domain/entities/victim_status.dart';
import 'tables/app_metadata.dart';
import 'tables/local_sessions.dart';
import 'tables/victims.dart';

part 'app_database.g.dart';

/// The device's primary operational datastore.
///
/// This is deliberately not a cache. It holds what the responder authored,
/// and it is complete without the backend. Every future table (incidents,
/// triage_records, sos_events, hazards, responders, tasks, locations,
/// sync_operations, sync_conflicts, audit_events) is added here with a
/// matching [schemaVersion] bump and a step in [migration]. See
/// `docs/architecture.md`.
@DriftDatabase(tables: [AppMetadata, LocalSessions, Victims])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// Bump by one for every additive migration, and add the matching `from`
  /// branch in [migration]. Never edit a released step.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Slice 2 adds victims. A device upgraded in the field keeps every
          // record it already holds, so migrations are additive only.
          if (from < 2) {
            await m.createTable(victims);
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
