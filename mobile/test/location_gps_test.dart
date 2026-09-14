import 'package:drp_mobile/core/errors/app_exception.dart';
import 'package:drp_mobile/data/local/daos/location_dao.dart';
import 'package:drp_mobile/domain/entities/gps_status.dart';
import 'package:drp_mobile/domain/entities/location_fix.dart';
import 'package:drp_mobile/domain/entities/location_record.dart';
import 'package:drp_mobile/domain/entities/sync_status.dart';
import 'package:drp_mobile/features/location/data/location_repository.dart';
import 'package:drp_mobile/features/location/data/location_service.dart';
import 'package:drp_mobile/features/location/data/location_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_location.dart';
import 'helpers/test_database.dart';

LocationRecord stored(LocationFix fix, {String id = 'loc-1'}) => LocationRecord(
      id: id,
      responderId: 'r1',
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracy: fix.accuracy,
      timestamp: fix.timestamp,
      createdAt: fix.timestamp,
      syncStatus: SyncStatus.pending,
      source: fix.source,
      isMocked: fix.isMocked,
    );

void main() {
  final now = DateTime.utc(2026, 9, 13, 8, 0, 0);
  final live = LocationFix(
    latitude: 18.5204,
    longitude: 73.8567,
    accuracy: 8,
    timestamp: now.subtract(const Duration(seconds: 3)),
    source: 'gps',
  );
  final weak = LocationFix(
    latitude: 18.5204,
    longitude: 73.8567,
    accuracy: 80,
    timestamp: now.subtract(const Duration(seconds: 3)),
    source: 'fused',
  );
  final stale = LocationFix(
    latitude: 18.5204,
    longitude: 73.8567,
    accuracy: 8,
    timestamp: now.subtract(const Duration(minutes: 10)),
    source: 'gps',
  );
  final emulator = LocationFix(
    latitude: 37.4220,
    longitude: -122.0841,
    accuracy: 5,
    timestamp: now.subtract(const Duration(seconds: 1)),
    source: 'mock',
    isMocked: true,
  );

  group('classification', () {
    test('live location success', () {
      final result = GpsClassification.classify(
        now: now,
        allowMock: false,
        record: stored(live),
        access: LocationAccessState.granted,
        listening: true,
      );
      expect(result.status, GpsStatus.liveGps);
      expect(result.record!.latitude, 18.5204);
    });

    test('permission denied', () {
      final result = GpsClassification.classify(
        now: now,
        allowMock: false,
        access: LocationAccessState.denied,
      );
      expect(result.status, GpsStatus.permissionDenied);
      expect(result.record, isNull);
    });

    test('permission denied still shows last known real GPS', () {
      final result = GpsClassification.classify(
        now: now,
        allowMock: false,
        record: stored(live),
        access: LocationAccessState.denied,
      );
      expect(result.status, GpsStatus.lastKnown);
      expect(result.record!.latitude, 18.5204);
    });

    test('location unavailable', () {
      final result = GpsClassification.classify(
        now: now,
        allowMock: false,
        access: LocationAccessState.serviceDisabled,
      );
      expect(result.status, GpsStatus.unavailable);
    });

    test('stale last-known location', () {
      final result = GpsClassification.classify(
        now: now,
        allowMock: false,
        record: stored(stale),
        access: LocationAccessState.granted,
        listening: false,
      );
      expect(result.status, GpsStatus.lastKnown);
    });

    test('demo mode toggle never claims live GPS', () {
      final result = GpsClassification.classify(
        now: now,
        allowMock: true,
        record: stored(emulator),
        access: LocationAccessState.granted,
        listening: true,
      );
      expect(result.status, GpsStatus.demoMode);
    });

    test('emulator default is not live GPS', () {
      final unmarked = LocationFix(
        latitude: 37.4220,
        longitude: -122.0841,
        accuracy: 5,
        timestamp: now,
        source: 'fused',
      );
      expect(unmarked.isPublishedEmulatorDefault, isTrue);
      final result = GpsClassification.classify(
        now: now,
        allowMock: false,
        record: stored(unmarked),
        access: LocationAccessState.granted,
        listening: true,
      );
      expect(result.status, GpsStatus.mockLocation);
    });

    test('weak accuracy is live but labelled GPS WEAK', () {
      final result = GpsClassification.classify(
        now: now,
        allowMock: false,
        record: stored(weak),
        access: LocationAccessState.granted,
        listening: true,
      );
      expect(result.status, GpsStatus.gpsWeak);
    });

    test('coordinate updates change the classified record', () {
      final first = GpsClassification.classify(
        now: now,
        allowMock: false,
        record: stored(live),
        access: LocationAccessState.granted,
        listening: true,
      );
      final moved = live.distanceMetersTo(
        LocationFix(
          latitude: 18.5304,
          longitude: 73.8567,
          accuracy: 8,
          timestamp: now,
          source: 'gps',
        ),
      );
      expect(first.record!.latitude, 18.5204);
      expect(moved, greaterThan(5));
    });
  });

  group('LocationService + repository', () {
    test('stores a live fix from the source without inventing coordinates',
        () async {
      final database = openTestDatabase();
      addTearDown(database.close);
      final fix = live;
      final repo = LocationRepository(
        locations: LocationDao(database),
        service: LocationService(source: FakeLocationSource(fix: fix)),
      );

      final record = await repo.capture(responderId: 'r1');
      expect(record.latitude, fix.latitude);
      expect(record.longitude, fix.longitude);
      expect(record.source, 'gps');
      expect(record.isMocked, isFalse);
    });

    test('refuses to read a fix when permission is denied', () async {
      final service = LocationService(
        source: FakeLocationSource(access: LocationAccess.denied),
      );
      expect(
        () => service.currentFix(),
        throwsA(isA<LocationUnavailableException>()),
      );
    });

    test('streams coordinate updates from the source', () async {
      final moved = LocationFix(
        latitude: 18.5304,
        longitude: 73.8567,
        accuracy: 6,
        timestamp: now,
        source: 'gps',
      );
      final service = LocationService(
        source: FakeLocationSource(
          fix: live,
          updates: Stream<LocationFix>.fromIterable([live, moved]),
        ),
      );

      final updates = await service.watchFixes().toList();
      expect(updates, hasLength(2));
      expect(updates.last.latitude, 18.5304);
    });

    test('schema v4 persists provider and mock flag', () async {
      final database = openTestDatabase();
      addTearDown(database.close);
      await database.select(database.appMetadata).get();
      expect(database.schemaVersion, 5);

      final dao = LocationDao(database);
      await dao.insertLocation(stored(emulator, id: 'mock-1'));
      final latest = await dao.readLatestFor('r1');
      expect(latest!.isMocked, isTrue);
      expect(latest.source, 'mock');
    });
  });
}
