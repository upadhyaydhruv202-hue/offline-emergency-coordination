import 'dart:async';

import 'package:drp_mobile/app/app.dart';
import 'package:drp_mobile/data/local/app_database.dart';
import 'package:drp_mobile/data/local/database_providers.dart';
import 'package:drp_mobile/features/connectivity/connectivity_providers.dart';
import 'package:drp_mobile/features/connectivity/connectivity_service.dart';
import 'package:drp_mobile/features/connectivity/connectivity_status.dart';
import 'package:drp_mobile/features/location/application/location_providers.dart';
import 'package:drp_mobile/features/location/data/location_service.dart';
import 'package:drp_mobile/features/victims/presentation/victim_detail_screen.dart';
import 'package:drp_mobile/features/victims/presentation/widgets/triage_selector.dart';
import 'package:drp_mobile/features/victims/presentation/widgets/victim_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_location.dart';
import 'helpers/test_database.dart';

/// The Slice 2 acceptance run, driven through the real application widget.
///
/// Every test here boots the app with **no network transport at all** and a
/// backend probe that always fails. If any part of registering, listing,
/// reassessing or reopening a victim needed the coordination backend, none of
/// it would pass.
void main() {
  late AppDatabase database;

  setUp(() => database = openTestDatabase());
  tearDown(() => database.close());

  /// Boots the shipping app over the shared in-memory database, offline.
  Future<void> bootApp(WidgetTester tester) async {
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
              transportSnapshot: () async => const {ConnectivityTransport.none},
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

  /// Tears the tree down inside the test body.
  ///
  /// Cancelling a Drift query stream schedules a zero-duration cleanup timer.
  /// Disposing here and then elapsing lets it run before the binding checks
  /// for pending timers.
  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  /// Kills the application and starts it again over the same database.
  ///
  /// The tree is torn down first so the router genuinely starts from its
  /// initial location: rebuilding over the top of a live one would preserve
  /// the current route and prove nothing about persistence.
  Future<void> restartApp(WidgetTester tester) async {
    await closeApp(tester);
    await bootApp(tester);
  }

  /// Scrolls the list inside [screen] until [target] is built and on screen.
  ///
  /// The forms are long enough that their lower half is never built on a test
  /// surface, which is also true on a real handset. `.first` picks the outer
  /// list rather than the scroll view every text field carries internally.
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

  Future<void> signInOffline(WidgetTester tester) async {
    await tester.tap(find.text('Continue in Offline Demo Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medical Team'));
    await tester.pumpAndSettle();
  }

  /// Clears a confirmation snack bar left over from an earlier save.
  ///
  /// The bar sits over the floating action button for several seconds and
  /// `pumpAndSettle` returns long before it expires, so the next tap would
  /// land on the bar instead of the button.
  Future<void> dismissSnackBars(WidgetTester tester) async {
    if (find.byType(SnackBar).evaluate().isEmpty) return;
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .clearSnackBars();
    await tester.pumpAndSettle();
  }

  Future<void> openVictims(WidgetTester tester) async {
    await dismissSnackBars(tester);
    await tester.tap(find.byIcon(Icons.people_alt_outlined));
    await tester.pumpAndSettle();
  }

  /// Fills in the registration form and saves. Leaves the app on the detail
  /// screen for the record that was just written.
  Future<void> registerVictim(
    WidgetTester tester, {
    required String name,
    required String triage,
    String age = '41',
    String injury = 'Crush injury to left leg',
  }) async {
    final form = find.byType(VictimForm);

    await dismissSnackBars(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(
      await reveal(
        tester,
        find.descendant(
          of: find.byType(TriageSelector),
          matching: find.text(triage),
        ),
        screen: form,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      await reveal(
        tester,
        find.widgetWithText(TextFormField, 'Name'),
        screen: form,
      ),
      name,
    );
    await tester.enterText(
      await reveal(
        tester,
        find.widgetWithText(TextFormField, 'Age'),
        screen: form,
      ),
      age,
    );
    await tester.enterText(
      await reveal(
        tester,
        find.widgetWithText(TextFormField, 'Injury type'),
        screen: form,
      ),
      injury,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      await reveal(tester, find.text('Save to this device'), screen: form),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the victim list is reachable and honest with no network', (
    tester,
  ) async {
    await bootApp(tester);
    await signInOffline(tester);
    await openVictims(tester);

    expect(find.text('No victims registered on this device'), findsOneWidget);
    expect(find.text('LOCAL DATA'), findsWidgets);
    expect(find.text('OFFLINE'), findsWidgets);
    expect(find.text('NOTHING PENDING'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('a victim registered offline appears in the list immediately', (
    tester,
  ) async {
    await bootApp(tester);
    await signInOffline(tester);
    await openVictims(tester);

    await registerVictim(tester, name: 'A. Sharma', triage: 'CRITICAL');

    // The app lands on the record it just wrote.
    expect(find.text('A. Sharma'), findsWidgets);
    expect(find.text('SYNC PENDING'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('A. Sharma'), findsOneWidget);
    expect(find.text('Crush injury to left leg'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('the record survives closing and reopening the application', (
    tester,
  ) async {
    await bootApp(tester);
    await signInOffline(tester);
    await openVictims(tester);
    await registerVictim(tester, name: 'Persisted Person', triage: 'URGENT');

    await restartApp(tester);
    await openVictims(tester);

    expect(find.text('Persisted Person'), findsOneWidget);
    expect(find.text('1 shown · 1 on this device'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('reassessing triage persists across a restart', (tester) async {
    await bootApp(tester);
    await signInOffline(tester);
    await openVictims(tester);
    await registerVictim(tester, name: 'Reassessed Person', triage: 'STABLE');

    // Saving leaves the app on the detail screen.
    await tester.tap(find.text('Reassess'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(TriageSelector),
        matching: find.text('CRITICAL'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Critical'), findsWidgets);

    await restartApp(tester);
    await openVictims(tester);

    expect(find.text('Reassessed Person'), findsOneWidget);
    expect(find.text('CRITICAL'), findsWidgets);

    await closeApp(tester);
  });

  testWidgets('marking a victim evacuated is stored on the device', (
    tester,
  ) async {
    await bootApp(tester);
    await signInOffline(tester);
    await openVictims(tester);
    await registerVictim(tester, name: 'Evacuated Person', triage: 'MODERATE');

    await dismissSnackBars(tester);
    await tester.tap(
      await reveal(
        tester,
        find.text('Mark Evacuated'),
        screen: find.byType(VictimDetailScreen),
      ),
    );
    await tester.pumpAndSettle();

    await restartApp(tester);
    await openVictims(tester);

    expect(find.text('EVACUATED'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('all four triage categories can be registered and counted', (
    tester,
  ) async {
    await bootApp(tester);
    await signInOffline(tester);
    await openVictims(tester);

    for (final category in ['CRITICAL', 'URGENT', 'MODERATE', 'STABLE']) {
      await registerVictim(
        tester,
        name: '$category case',
        triage: category,
        injury: 'Injury for $category',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(find.text('4 shown · 4 on this device'), findsOneWidget);
    expect(find.text('4 CHANGES PENDING'), findsOneWidget);

    // Critical is listed first regardless of the order they were entered in.
    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(
      rendered.indexOf('CRITICAL case'),
      lessThan(rendered.indexOf('STABLE case')),
    );

    await closeApp(tester);
  });

  testWidgets('the list filters by triage category', (tester) async {
    await bootApp(tester);
    await signInOffline(tester);
    await openVictims(tester);

    for (final category in ['CRITICAL', 'STABLE']) {
      await registerVictim(
        tester,
        name: '$category case',
        triage: category,
        injury: 'Injury for $category',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.widgetWithText(InkWell, 'STABLE').first);
    await tester.pumpAndSettle();

    expect(find.text('STABLE case'), findsOneWidget);
    expect(find.text('CRITICAL case'), findsNothing);
    expect(find.text('1 shown · 2 on this device'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('the list searches by name', (tester) async {
    await bootApp(tester);
    await signInOffline(tester);
    await openVictims(tester);

    for (final name in ['Meera Iyer', 'Rohit Verma']) {
      await registerVictim(
        tester,
        name: name,
        triage: 'URGENT',
        injury: 'Injury for $name',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byType(TextField).first, 'meera');
    await tester.pumpAndSettle();

    expect(find.text('Meera Iyer'), findsOneWidget);
    expect(find.text('Rohit Verma'), findsNothing);

    await closeApp(tester);
  });
}
