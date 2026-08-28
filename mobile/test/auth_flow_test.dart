import 'package:drp_mobile/app/router/app_router.dart';
import 'package:drp_mobile/app/router/app_routes.dart';
import 'package:drp_mobile/data/local/app_database.dart';
import 'package:drp_mobile/data/local/daos/session_dao.dart';
import 'package:drp_mobile/data/remote/auth_api.dart';
import 'package:drp_mobile/domain/entities/responder.dart';
import 'package:drp_mobile/domain/entities/responder_role.dart';
import 'package:drp_mobile/features/auth/application/auth_state.dart';
import 'package:drp_mobile/features/auth/data/auth_repository.dart';
import 'package:drp_mobile/features/auth/data/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/test_database.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _MockTokenStore extends Mock implements TokenStore {}

void main() {
  late AppDatabase database;
  late SessionDao sessions;
  late _MockAuthApi api;
  late _MockTokenStore tokens;
  late AuthRepository repository;

  setUp(() {
    database = openTestDatabase();
    sessions = SessionDao(database);
    api = _MockAuthApi();
    tokens = _MockTokenStore();
    repository = AuthRepository(api: api, sessions: sessions, tokens: tokens);

    when(() => tokens.save(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async {});
    when(tokens.clear).thenAnswer((_) async {});
  });

  tearDown(() => database.close());

  group('offline demo mode', () {
    test('creates a usable session without touching the network', () async {
      final responder =
          await repository.startOfflineDemoSession(role: ResponderRole.volunteer);

      expect(responder.isOfflineDemo, isTrue);
      expect(responder.role, ResponderRole.volunteer);
      verifyNever(() => api.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ));
    });

    test('survives a restart because it was written to the local database',
        () async {
      await repository.startOfflineDemoSession(role: ResponderRole.rescueTeam);

      // A fresh repository over the same database stands in for a cold start.
      final restored = await AuthRepository(
        api: api,
        sessions: SessionDao(database),
        tokens: tokens,
      ).restoreSession();

      expect(restored, isNotNull);
      expect(restored!.isOfflineDemo, isTrue);
      expect(restored.role, ResponderRole.rescueTeam);
    });
  });

  group('backend sign-in', () {
    test('persists the session and the tokens', () async {
      when(() => api.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer(
        (_) async => const LoginResult(
          tokens: AuthTokens(
            accessToken: 'access',
            refreshToken: 'refresh',
            expiresIn: 3600,
          ),
          profile: RemoteProfile(
            id: 'user-42',
            email: 'commander@drp.example',
            fullName: 'A. Rathore',
            role: ResponderRole.incidentCommander,
          ),
        ),
      );

      final responder = await repository.signIn(
        email: 'commander@drp.example',
        password: 'Rescue-Demo-2026',
      );

      expect(responder.isOfflineDemo, isFalse);
      expect(responder.role, ResponderRole.incidentCommander);
      expect(await sessions.readActiveSession(), isNotNull);
      verify(() => tokens.save(accessToken: 'access', refreshToken: 'refresh'))
          .called(1);
    });

    test('signing out clears both the session and the tokens', () async {
      await repository.startOfflineDemoSession(role: ResponderRole.volunteer);

      await repository.signOut();

      expect(await sessions.readActiveSession(), isNull);
      verify(tokens.clear).called(1);
    });
  });

  group('role model', () {
    test('exposes exactly the five Slice 1 roles', () {
      expect(
        ResponderRole.values.map((role) => role.wireValue).toSet(),
        {
          'RESCUE_TEAM',
          'MEDICAL_TEAM',
          'VOLUNTEER',
          'INCIDENT_COMMANDER',
          'ADMIN',
        },
      );
    });

    test('round-trips every role through its wire value', () {
      for (final role in ResponderRole.values) {
        expect(ResponderRole.tryFromWire(role.wireValue), role);
      }
    });

    test('rejects an unknown wire value instead of guessing', () {
      expect(ResponderRole.tryFromWire('SUPREME_LEADER'), isNull);
      expect(ResponderRole.tryFromWire(null), isNull);
    });

    test('only commander and admin are command roles', () {
      expect(
        ResponderRole.values.where((role) => role.isCommand).toSet(),
        {ResponderRole.incidentCommander, ResponderRole.admin},
      );
    });
  });

  group('navigation policy', () {
    final responder = Responder(
      id: 'user-1',
      email: 'rescue@drp.example',
      fullName: 'S. Menon',
      role: ResponderRole.rescueTeam,
      signedInAt: DateTime.utc(2026, 8, 28),
    );

    test('holds on the splash screen while the session is being restored', () {
      expect(
        redirectForTest(const AuthRestoring(), AppRoute.splash.path),
        isNull,
      );
      expect(
        redirectForTest(const AuthRestoring(), AppRoute.home.path),
        AppRoute.splash.path,
      );
    });

    test('sends an anonymous device to the login screen', () {
      expect(
        redirectForTest(const AuthSignedOut(), AppRoute.home.path),
        AppRoute.login.path,
      );
      expect(
        redirectForTest(const AuthSignedOut(), AppRoute.login.path),
        isNull,
      );
    });

    test('sends a signed-in responder from the entry screens to home', () {
      expect(
        redirectForTest(AuthSignedIn(responder), AppRoute.login.path),
        AppRoute.home.path,
      );
      expect(
        redirectForTest(AuthSignedIn(responder), AppRoute.splash.path),
        AppRoute.home.path,
      );
    });

    test('leaves a signed-in responder on any in-session route', () {
      for (final route in [
        AppRoute.home,
        AppRoute.victims,
        AppRoute.sos,
        AppRoute.map,
        AppRoute.profile,
        AppRoute.role,
      ]) {
        expect(
          redirectForTest(AuthSignedIn(responder), route.path),
          isNull,
          reason: '${route.path} should be reachable when signed in',
        );
      }
    });
  });
}
