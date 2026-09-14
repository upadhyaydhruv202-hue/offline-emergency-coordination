import 'dart:async';

import 'package:drp_mobile/app/app.dart';
import 'package:drp_mobile/data/local/app_database.dart';
import 'package:drp_mobile/data/local/database_providers.dart';
import 'package:drp_mobile/features/connectivity/connectivity_providers.dart';
import 'package:drp_mobile/features/connectivity/connectivity_service.dart';
import 'package:drp_mobile/features/connectivity/connectivity_status.dart';
import 'package:drp_mobile/features/location/application/location_providers.dart';
import 'package:drp_mobile/features/location/data/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_location.dart';
import 'helpers/test_database.dart';

/// Boots the real application widget, so this exercises the router, the theme,
/// the providers and every Slice 1 screen rather than a test-only harness.
///
/// The two overrides replace things that need a device: the on-disk database
/// location and the platform connectivity channel. The code under test is
/// otherwise exactly what ships.
void main() {
  late AppDatabase database;

  setUp(() => database = openTestDatabase());
  tearDown(() => database.close());

  Future<void> bootApp(
    WidgetTester tester, {
    Set<ConnectivityTransport> transports = const {ConnectivityTransport.wifi},
    bool backendReachable = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          locationServiceProvider.overrideWithValue(
            LocationService(
              source: FakeLocationSource(updates: const Stream.empty()),
            ),
          ),
          connectivityServiceProvider.overrideWith((ref) {
            final service = ConnectivityService(
              transportSnapshot: () async => transports,
              transportChanges: Stream<void>.empty(),
              probe: () async => backendReachable,
            );
            // Cancels the periodic re-evaluation, which would otherwise leave
            // a pending timer when the tree is torn down.
            ref.onDispose(() => unawaited(service.dispose()));
            unawaited(service.start());
            return service;
          }),
        ],
        child: const DisasterResponseApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Tears the tree down inside the test body.
  ///
  /// The home screen watches a Drift query stream, and cancelling one schedules
  /// a zero-duration cleanup timer. Disposing here and then elapsing lets that
  /// timer run before the binding checks for pending timers.
  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> enterOfflineDemo(WidgetTester tester, String roleLabel) async {
    await tester.tap(find.text('Continue in Offline Demo Mode'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(roleLabel));
    await tester.pumpAndSettle();
  }

  testWidgets('launches and lands on the login screen with no session', (
    tester,
  ) async {
    await bootApp(tester);

    expect(find.text('Field sign-in'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Continue in Offline Demo Mode'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('offline demo mode reaches the responder home screen', (
    tester,
  ) async {
    await bootApp(tester);

    await enterOfflineDemo(tester, 'Rescue Team');

    expect(find.text('Offline Demo Responder'), findsOneWidget);
    expect(find.text('DEMO SESSION'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('home shows incident, role, connectivity and database status', (
    tester,
  ) async {
    await bootApp(tester, backendReachable: true);

    await enterOfflineDemo(tester, 'Medical Team');

    // Panel captions render uppercased, as in the operational specification.
    expect(find.text('FIELD RESPONDER'), findsOneWidget);
    expect(find.text('CURRENT INCIDENT'), findsOneWidget);
    expect(find.text('No current operation'), findsOneWidget);
    expect(find.text('MEDICAL TEAM'), findsOneWidget);

    expect(find.text('CONNECTIVITY'), findsOneWidget);
    expect(find.text('ONLINE'), findsWidgets);

    expect(find.text('READY'), findsOneWidget);
    expect(find.text('CURRENT LOCATION'), findsOneWidget);
    expect(find.text('RESPONDER STATUS'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('an unreachable backend renders DEGRADED, not a failure', (
    tester,
  ) async {
    await bootApp(tester);

    await enterOfflineDemo(tester, 'Volunteer');

    expect(find.text('DEGRADED'), findsWidgets);
    // The local datastore is unaffected by the backend being unreachable.
    expect(find.text('READY'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('with no link at all the device still reaches home', (
    tester,
  ) async {
    await bootApp(tester, transports: const {ConnectivityTransport.none});

    await enterOfflineDemo(tester, 'Incident Commander');

    expect(find.text('OFFLINE'), findsWidgets);
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('INCIDENT COMMANDER'), findsWidgets);

    await closeApp(tester);
  });

  testWidgets('an unbuilt module names the slice that will deliver it', (
    tester,
  ) async {
    await bootApp(tester);
    await enterOfflineDemo(tester, 'Rescue Team');

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();

    expect(find.text('COMING IN SLICE 5'), findsOneWidget);
    expect(
      find.textContaining('Coming in the next development slice'),
      findsOneWidget,
    );

    await closeApp(tester);
  });

  testWidgets('SOS is a live field module, not a placeholder', (tester) async {
    await bootApp(tester);
    await enterOfflineDemo(tester, 'Rescue Team');

    await tester.tap(find.byIcon(Icons.emergency_outlined));
    await tester.pumpAndSettle();

    expect(find.text('CREATE SOS'), findsWidgets);
    expect(find.text('SOS HISTORY'), findsOneWidget);
    expect(find.text('COMING IN SLICE 3'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('the session survives a restart of the widget tree', (
    tester,
  ) async {
    await bootApp(tester);
    await enterOfflineDemo(tester, 'Rescue Team');
    expect(find.text('Offline Demo Responder'), findsOneWidget);

    // Tearing the tree down and building it again over the same database is a
    // cold start: nothing is carried over in memory.
    await closeApp(tester);
    await bootApp(tester);

    expect(find.text('Field sign-in'), findsNothing);
    expect(find.text('Offline Demo Responder'), findsOneWidget);

    await closeApp(tester);
  });
}
