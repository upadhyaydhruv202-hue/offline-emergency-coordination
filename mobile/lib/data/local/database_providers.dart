import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'daos/app_metadata_dao.dart';
import 'daos/session_dao.dart';
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

/// A random, device-local identifier.
///
/// Slice 1 needs it only to label the datastore. Later slices give records an
/// origin so that operations authored on different devices can be merged
/// without collision; a cryptographic device identity is a hardening-slice
/// concern.
String generateDeviceId() {
  final random = Random.secure();
  final bytes = List<int>.generate(8, (_) => random.nextInt(256));
  final hex =
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  return 'DRP-$hex';
}
