import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/identifiers.dart';
import 'app_database.dart';
import 'daos/app_metadata_dao.dart';
import 'daos/audit_dao.dart';
import 'daos/hazard_dao.dart';
import 'daos/incident_dao.dart';
import 'daos/location_dao.dart';
import 'daos/responder_status_dao.dart';
import 'daos/session_dao.dart';
import 'daos/sos_dao.dart';
import 'daos/task_dao.dart';
import 'daos/victim_dao.dart';
import 'local_database_health.dart';
import 'tables/app_metadata.dart';

/// The single [AppDatabase] instance for the process.
///
/// Overridden in tests with an in-memory executor.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final sessionDaoProvider = Provider<SessionDao>(
  (ref) => SessionDao(ref.watch(appDatabaseProvider)),
);

final appMetadataDaoProvider = Provider<AppMetadataDao>(
  (ref) => AppMetadataDao(ref.watch(appDatabaseProvider)),
);

final victimDaoProvider = Provider<VictimDao>(
  (ref) => VictimDao(ref.watch(appDatabaseProvider)),
);

final incidentDaoProvider = Provider<IncidentDao>(
  (ref) => IncidentDao(ref.watch(appDatabaseProvider)),
);

final locationDaoProvider = Provider<LocationDao>(
  (ref) => LocationDao(ref.watch(appDatabaseProvider)),
);

final sosDaoProvider = Provider<SosDao>(
  (ref) => SosDao(ref.watch(appDatabaseProvider)),
);

final hazardDaoProvider = Provider<HazardDao>(
  (ref) => HazardDao(ref.watch(appDatabaseProvider)),
);

final taskDaoProvider = Provider<TaskDao>(
  (ref) => TaskDao(ref.watch(appDatabaseProvider)),
);

final responderStatusDaoProvider = Provider<ResponderStatusDao>(
  (ref) => ResponderStatusDao(ref.watch(appDatabaseProvider)),
);

final auditDaoProvider = Provider<AuditDao>(
  (ref) => AuditDao(ref.watch(appDatabaseProvider)),
);

/// Opens the datastore, mints the device identifier on first run, and reports
/// the result. Any failure is returned as data rather than thrown, because the
/// home screen must still render to tell the responder what is wrong.
final localDatabaseHealthProvider =
    FutureProvider<LocalDatabaseHealth>((ref) async {
  final database = ref.watch(appDatabaseProvider);
  final metadata = ref.watch(appMetadataDaoProvider);

  try {
    final deviceId = await metadata.readOrCreate(
      AppMetadataKeys.deviceId,
      generateDeviceId,
    );

    await metadata.write(
      AppMetadataKeys.schemaInitialisedAt,
      DateTime.now().toUtc().toIso8601String(),
    );

    return LocalDatabaseHealth(
      state: LocalDatabaseState.ready,
      schemaVersion: database.schemaVersion,
      tables: database.tableNames,
      deviceId: deviceId,
    );
  } on Exception catch (error) {
    return LocalDatabaseHealth.failed(error.toString());
  }
});
