import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drp_mobile/app/app.dart';
import 'package:drp_mobile/core/config/app_config.dart';
import 'package:drp_mobile/data/local/app_database.dart';
import 'package:drp_mobile/data/local/database_providers.dart';
import 'package:drp_mobile/domain/entities/location_fix.dart';
import 'package:drp_mobile/features/connectivity/connectivity_providers.dart';
import 'package:drp_mobile/features/connectivity/connectivity_service.dart';
import 'package:drp_mobile/features/connectivity/connectivity_status.dart';
import 'package:drp_mobile/features/home/presentation/home_screen.dart';
import 'package:drp_mobile/features/hazards/presentation/widgets/hazard_form.dart';
import 'package:drp_mobile/features/incidents/presentation/widgets/incident_form.dart';
import 'package:drp_mobile/features/location/application/location_providers.dart';
import 'package:drp_mobile/features/location/data/location_service.dart';
import 'package:drp_mobile/features/tasks/presentation/task_create_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_location.dart';
import 'helpers/test_database.dart';

/// Writes Slice 3 PNGs into docs/screenshots. Opt-in only:
/// `$env:CAPTURE_SLICE3_SHOTS="1"; flutter test test/slice3_screenshot_capture_test.dart`
void main() {
  final capture = Platform.environment['CAPTURE_SLICE3_SHOTS'] == '1';

  late AppDatabase database;
  final boundaryKey = GlobalKey();

  setUpAll(loadScreenshotFonts);
  setUp(() => database = openTestDatabase());
  tearDown(() => database.close());

  Future<void> bootApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          locationServiceProvider.overrideWithValue(
            LocationService(
              source: FakeLocationSource(
                updates: const Stream.empty(),
                fix: LocationFix(
                  latitude: 12.0,
                  longitude: 77.0,
                  accuracy: 8,
                  timestamp: DateTime.utc(2026, 9, 8, 11, 12, 18),
                  source: 'gps',
                  isMocked: false,
                ),
              ),
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
        child: RepaintBoundary(
          key: boundaryKey,
          child: const DisasterResponseApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> saveShot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('../docs/screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
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

  testWidgets(
    'capture Slice 3 field-ops screenshots',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await bootApp(tester);
      await tester.tap(find.text('Continue in Offline Demo Mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rescue Team'));
      await tester.pumpAndSettle();

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
      if (capture) await saveShot(tester, 'mobile-incident-detail');

      await tester.pageBack();
      await tester.pumpAndSettle();
      if (capture) await saveShot(tester, 'mobile-incidents');

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Home'),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Change', skipOffstage: false));
      await tester.tap(find.text('On mission'));
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.text('Refresh location', skipOffstage: false),
      );
      await dismissSnackBars(tester);
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(HomeScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      if (capture) await saveShot(tester, 'mobile-home');

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
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();
      if (capture) await saveShot(tester, 'mobile-hazards');

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
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();
      if (capture) await saveShot(tester, 'mobile-sos');

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
      await tester.tap(find.text('ACCEPT TASK'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await dismissSnackBars(tester);
      if (capture) await saveShot(tester, 'mobile-tasks');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
    skip: !capture,
  );
}

Future<void> loadScreenshotFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';

  Future<ByteData> bytes(String name) async {
    final data = await File('$dir/$name').readAsBytes();
    return ByteData.view(Uint8List.fromList(data).buffer);
  }

  final roboto = FontLoader('Roboto')
    ..addFont(bytes('roboto-regular.ttf'))
    ..addFont(bytes('roboto-medium.ttf'))
    ..addFont(bytes('roboto-bold.ttf'))
    ..addFont(bytes('roboto-black.ttf'));
  await roboto.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes('materialicons-regular.otf'));
  await icons.load();
}
