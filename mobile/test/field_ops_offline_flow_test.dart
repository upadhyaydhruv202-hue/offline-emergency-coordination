import 'dart:async';

import 'package:drp_mobile/app/app.dart';
import 'package:drp_mobile/core/config/app_config.dart';
import 'package:drp_mobile/data/local/app_database.dart';
import 'package:drp_mobile/data/local/database_providers.dart';
import 'package:drp_mobile/features/connectivity/connectivity_providers.dart';
import 'package:drp_mobile/features/connectivity/connectivity_service.dart';
import 'package:drp_mobile/features/connectivity/connectivity_status.dart';
import 'package:drp_mobile/features/home/presentation/home_screen.dart';
import 'package:drp_mobile/features/hazards/presentation/widgets/hazard_form.dart';
import 'package:drp_mobile/features/incidents/presentation/widgets/incident_form.dart';
import 'package:drp_mobile/features/location/application/location_providers.dart';
import 'package:drp_mobile/features/location/data/location_service.dart';
import 'package:drp_mobile/features/tasks/presentation/task_create_screen.dart';
import 'package:drp_mobile/features/victims/presentation/widgets/triage_selector.dart';
import 'package:drp_mobile/features/victims/presentation/widgets/victim_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_location.dart';
import 'helpers/test_database.dart';

/// Slice 3 acceptance run: declare, locate, register, report, raise, task,
/// change status, kill the app, reopen — all with no transport.
void main() {
  late AppDatabase database;

  setUp(() => database = openTestDatabase());
  tearDown(() => database.close());

  Future<void> bootApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          locationServiceProvider.overrideWithValue(
            LocationService(
              source: FakeLocationSource(updates: const Stream.empty()),
              timeout: AppConfig.locationTimeout,
            ),
          ),
          connectivityServiceProvider.overrideWith((ref) {
            final service = ConnectivityService(
              transportSnapshot: () async =>
                  const {ConnectivityTransport.none},
              transportChanges: const Stream<void>.empty(),
              probe: () async => false,
            );
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

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> restartApp(WidgetTester tester) async {
    await closeApp(tester);
    await bootApp(tester);
  }

  Future<Finder> reveal(
    WidgetTester tester,
    Finder target, {
    required Finder screen,
  }) async {
    await tester.scrollUntilVisible(
      target,
      160,
      scrollable:
          find.descendant(of: screen, matching: find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
    return target;
  }

  Future<void> dismissSnackBars(WidgetTester tester) async {
    if (find.byType(SnackBar).evaluate().isEmpty) return;
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .clearSnackBars();
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await dismissSnackBars(tester);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> signInOffline(WidgetTester tester) async {
    await tester.tap(find.text('Continue in Offline Demo Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rescue Team'));
    await tester.pumpAndSettle();
  }

  Future<void> goHome(WidgetTester tester) async {
    await dismissSnackBars(tester);
    if (find.byType(HomeScreen).evaluate().isNotEmpty) return;

    if (find.byType(NavigationBar).evaluate().isEmpty) {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the full field-ops journey persists after a restart with no network',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await bootApp(tester);
      await signInOffline(tester);

      expect(find.text('OFFLINE'), findsWidgets);
      expect(find.text('READY'), findsOneWidget);
      expect(find.text('No current operation'), findsOneWidget);
      expect(find.text('AVAILABLE'), findsWidgets);

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final incidentForm = find.byType(IncidentForm);
      await tester.enterText(
        await reveal(
          tester,
          find.widgetWithText(TextFormField, 'Title'),
          screen: incidentForm,
        ),
        'Ahmedabad Earthquake Response',
      );
      await tester.enterText(
        await reveal(
          tester,
          find.widgetWithText(TextFormField, 'Assigned zone'),
          screen: incidentForm,
        ),
        'AHMEDABAD ZONE 04',
      );
      await tester.tap(
        await reveal(
          tester,
          find.text('Declare and set as current'),
          screen: incidentForm,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('INC-'), findsWidgets);
      expect(find.text('AHMEDABAD ZONE 04'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await goHome(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Ahmedabad Earthquake Response'), findsWidgets);

      await tapVisible(tester, find.text('Change', skipOffstage: false));
      await tester.tap(find.text('On mission'));
      await tester.pumpAndSettle();
      expect(find.text('ON MISSION'), findsWidgets);

      await tapVisible(
        tester,
        find.text('Refresh location', skipOffstage: false),
      );
      expect(find.textContaining('12.0000° N'), findsOneWidget);

      await tapVisible(
        tester,
        find.text('REGISTER VICTIM', skipOffstage: false),
      );
      await tester.pumpAndSettle();
      final victimForm = find.byType(VictimForm);
      await tester.tap(
        await reveal(
          tester,
          find.descendant(
            of: find.byType(TriageSelector),
            matching: find.text('CRITICAL'),
          ),
          screen: victimForm,
        ),
      );
      await tester.enterText(
        await reveal(
          tester,
          find.widgetWithText(TextFormField, 'Name'),
          screen: victimForm,
        ),
        'A. Sharma',
      );
      await tester.tap(
        await reveal(
          tester,
          find.text('Save to this device'),
          screen: victimForm,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A. Sharma'), findsWidgets);
      expect(find.text('SYNC PENDING'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await goHome(tester);

      await tapVisible(
        tester,
        find.text('REPORT HAZARD', skipOffstage: false),
      );
      await tester.pumpAndSettle();
      final hazardForm = find.byType(HazardForm);
      await tester.tap(find.text('Critical'));
      await tester.enterText(
        await reveal(
          tester,
          find.widgetWithText(TextFormField, 'Description'),
          screen: hazardForm,
        ),
        'North stairwell shifting',
      );
      await tester.tap(
        await reveal(
          tester,
          find.text('Save to this device'),
          screen: hazardForm,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('HAZARD REPORTED'), findsOneWidget);
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('HZ-'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.emergency_outlined),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('CREATE SOS').last);
      await tester.pumpAndSettle();
      expect(find.text('Create Emergency SOS?'), findsOneWidget);
      await tester.tap(find.text('CREATE SOS').last);
      await tester.pumpAndSettle();
      expect(find.text('SOS CREATED'), findsOneWidget);
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SOS-'), findsWidgets);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(
        await reveal(
          tester,
          find.text('MY TASKS', skipOffstage: false),
          screen: find.byType(HomeScreen),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final taskForm = find.byType(TaskCreateScreen);
      await tester.enterText(
        await reveal(
          tester,
          find.widgetWithText(TextFormField, 'What needs doing?'),
          screen: taskForm,
        ),
        'Search collapsed building',
      );
      await tester.tap(
        await reveal(
          tester,
          find.text('Save to this device'),
          screen: taskForm,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Search collapsed building'), findsWidgets);

      await tester.tap(find.text('ACCEPT TASK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START TASK'));
      await tester.pumpAndSettle();

      await restartApp(tester);

      expect(find.text('Ahmedabad Earthquake Response'), findsWidgets);
      expect(find.text('ON MISSION'), findsWidgets);
      expect(find.textContaining('12.0000° N'), findsOneWidget);
      expect(find.text('A. Sharma'), findsNothing);

      await tester.tap(find.byIcon(Icons.people_alt_outlined));
      await tester.pumpAndSettle();
      expect(find.text('A. Sharma'), findsOneWidget);
      expect(find.text('SYNC PENDING'), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.emergency_outlined),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('SOS-'), findsWidgets);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hazards'));
      await tester.pumpAndSettle();
      expect(find.textContaining('HZ-'), findsWidgets);
      expect(find.text('North stairwell shifting'), findsOneWidget);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Search collapsed building'), findsOneWidget);

      await closeApp(tester);
    },
  );
}
