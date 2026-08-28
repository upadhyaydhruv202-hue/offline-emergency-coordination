import 'dart:async';

import 'package:drp_mobile/app/app.dart';
import 'package:drp_mobile/data/local/app_database.dart';
import 'package:drp_mobile/data/local/database_providers.dart';
import 'package:drp_mobile/features/connectivity/connectivity_providers.dart';
import 'package:drp_mobile/features/connectivity/connectivity_service.dart';
import 'package:drp_mobile/features/connectivity/connectivity_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });

  testWidgets('offline demo mode reaches the responder home screen', (
    tester,
  ) async {
    await bootApp(tester);

    await enterOfflineDemo(tester, 'Rescue Team');

    expect(find.text('Offline Demo Responder'), findsOneWidget);
    expect(find.text('DEMO SESSION'), findsOneWidget);
  });

  testWidgets('home shows incident, role, connectivity and database status', (
    tester,
  ) async {
    await bootApp(tester, backendReachable: true);

    await enterOfflineDemo(tester, 'Medical Team');

    // Panel captions render uppercased, as in the operational specification.
    expect(find.text('INCIDENT'), findsOneWidget);
    expect(find.text('Ahmedabad Earthquake Response'), findsOneWidget);

    expect(find.text('ROLE'), findsOneWidget);
    expect(find.text('Medical Team'), findsOneWidget);

    expect(find.text('CONNECTIVITY'), findsOneWidget);
    expect(find.text('ONLINE'), findsWidgets);

    expect(find.text('LOCAL DATABASE'), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);
  });

  testWidgets('an unreachable backend renders DEGRADED, not a failure', (
    tester,
  ) async {
    await bootApp(tester);

    await enterOfflineDemo(tester, 'Volunteer');

    expect(find.text('DEGRADED'), findsWidgets);
    // The local datastore is unaffected by the backend being unreachable.
    expect(find.text('READY'), findsOneWidget);
  });

  testWidgets('with no link at all the device still reaches home', (
    tester,
  ) async {
    await bootApp(tester, transports: const {ConnectivityTransport.none});

    await enterOfflineDemo(tester, 'Incident Commander');

    expect(find.text('OFFLINE'), findsWidgets);
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('Incident Commander'), findsWidgets);
  });

  testWidgets('an unbuilt module names the slice that will deliver it', (
    tester,
  ) async {
    await bootApp(tester);
    await enterOfflineDemo(tester, 'Rescue Team');

    await tester.tap(find.byIcon(Icons.people_alt_outlined));
    await tester.pumpAndSettle();

    expect(find.text('COMING IN SLICE 2'), findsOneWidget);
    expect(
      find.textContaining('Coming in the next development slice'),
      findsOneWidget,
    );
  });

  testWidgets('the session survives a restart of the widget tree', (
    tester,
  ) async {
    await bootApp(tester);
    await enterOfflineDemo(tester, 'Rescue Team');
    expect(find.text('Offline Demo Responder'), findsOneWidget);

    // A fresh ProviderScope over the same database stands in for a cold start.
    await bootApp(tester);

    expect(find.text('Field sign-in'), findsNothing);
    expect(find.text('Offline Demo Responder'), findsOneWidget);
  });
}
