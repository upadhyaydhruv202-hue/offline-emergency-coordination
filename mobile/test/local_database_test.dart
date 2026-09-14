import 'package:drp_mobile/data/local/app_database.dart';
import 'package:drp_mobile/data/local/daos/app_metadata_dao.dart';
import 'package:drp_mobile/data/local/daos/session_dao.dart';
import 'package:drp_mobile/data/local/tables/app_metadata.dart';
import 'package:drp_mobile/domain/entities/responder.dart';
import 'package:drp_mobile/domain/entities/responder_role.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = openTestDatabase());
  tearDown(() => database.close());

  Responder buildResponder({
    String id = 'user-1',
    ResponderRole role = ResponderRole.rescueTeam,
    bool offlineDemo = false,
  }) =>
      Responder(
        id: id,
        email: 'rescue@drp.example',
        fullName: 'S. Menon',
        role: role,
        signedInAt: DateTime.utc(2026, 8, 28, 10, 30),
        isOfflineDemo: offlineDemo,
      );

  group('initialisation', () {
    test('opens and reports the current schema version', () async {
      // Any query forces the migration to run.
      await database.select(database.appMetadata).get();

      expect(database.schemaVersion, 5);
    });

    test('creates the Slice 1 tables and the later operational tables',
        () async {
      await database.select(database.appMetadata).get();

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
          'sync_operations',
          'sync_conflicts',
          'sync_entity_heads',
        ]),
      );
    });

    test('starts with no session and no metadata', () async {
      expect(await SessionDao(database).readActiveSession(), isNull);
      expect(await AppMetadataDao(database).count(), 0);
    });
  });

  group('session persistence', () {
    test('round-trips a responder', () async {
      final dao = SessionDao(database);
      await dao.saveSession(buildResponder());

      final restored = await dao.readActiveSession();

      expect(restored, isNotNull);
      expect(restored!.email, 'rescue@drp.example');
      expect(restored.role, ResponderRole.rescueTeam);
      expect(restored.isOfflineDemo, isFalse);
    });

    test('preserves the offline demo marker', () async {
      final dao = SessionDao(database);
      await dao.saveSession(
        buildResponder(id: 'offline-1', offlineDemo: true),
      );

      final restored = await dao.readActiveSession();

      expect(restored!.isOfflineDemo, isTrue);
    });

    test('keeps at most one session so a device cannot hold two identities',
        () async {
      final dao = SessionDao(database);
      await dao.saveSession(buildResponder(id: 'user-1'));
      await dao.saveSession(
        buildResponder(id: 'user-2', role: ResponderRole.medicalTeam),
      );

      final rows = await database.select(database.localSessions).get();

      expect(rows, hasLength(1));
      expect(rows.single.id, 'user-2');
      expect(rows.single.role, ResponderRole.medicalTeam);
    });

    test('updates the role in place', () async {
      final dao = SessionDao(database);
      await dao.saveSession(buildResponder());

      await dao.updateRole('user-1', ResponderRole.incidentCommander);

      final restored = await dao.readActiveSession();
      expect(restored!.role, ResponderRole.incidentCommander);
    });

    test('clear removes the session', () async {
      final dao = SessionDao(database);
      await dao.saveSession(buildResponder());

      await dao.clear();

      expect(await dao.readActiveSession(), isNull);
    });

    test('watch emits the current session and subsequent changes', () async {
      final dao = SessionDao(database);
      final emissions = <Responder?>[];
      final subscription = dao.watchActiveSession().listen(emissions.add);

      await dao.saveSession(buildResponder());
      await pumpEventQueue();

      await subscription.cancel();
      expect(emissions.last?.id, 'user-1');
    });
  });

  group('app metadata', () {
    test('readOrCreate mints a value once and reuses it', () async {
      final dao = AppMetadataDao(database);

      final first = await dao.readOrCreate(
        AppMetadataKeys.deviceId,
        () => 'DRP-AAAA',
      );
      final second = await dao.readOrCreate(
        AppMetadataKeys.deviceId,
        () => 'DRP-BBBB',
      );

      expect(first, 'DRP-AAAA');
      expect(second, 'DRP-AAAA');
    });

    test('write overwrites an existing key', () async {
      final dao = AppMetadataDao(database);

      await dao.write(AppMetadataKeys.lastSyncAt, 'first');
      await dao.write(AppMetadataKeys.lastSyncAt, 'second');

      expect(await dao.read(AppMetadataKeys.lastSyncAt), 'second');
      expect(await dao.count(), 1);
    });
  });
}
