import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/config/app_config.dart';
// Part files inherit this library's imports, and the generated code needs the
// enum backing `LocalSessions.role`.
import '../../domain/entities/responder_role.dart';
import 'tables/app_metadata.dart';
import 'tables/local_sessions.dart';

part 'app_database.g.dart';

/// The device's primary operational datastore.
///
/// This is deliberately not a cache. Slice 1 persists only what authentication
/// and application metadata require, but the shape is the one later slices
/// extend: every future table (incidents, victims, triage_records, sos_events,
/// hazards, responders, tasks, locations, sync_operations, sync_conflicts,
/// audit_events) is added here with a matching [schemaVersion] bump and a step
/// in [migration]. See `docs/architecture.md`.
@DriftDatabase(tables: [AppMetadata, LocalSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// Bump by one for every additive migration, and add the matching `from`
  /// branch in [migration]. Never edit a released step.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
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
