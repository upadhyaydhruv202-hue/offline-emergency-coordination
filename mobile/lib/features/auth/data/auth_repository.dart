import 'dart:math';

import '../../../data/local/daos/session_dao.dart';
import '../../../data/remote/auth_api.dart';
import '../../../domain/entities/responder.dart';
import '../../../domain/entities/responder_role.dart';
import 'token_store.dart';

/// Owns how a session comes into existence and where it is kept.
///
/// The local database is authoritative. A successful backend login *writes* a
/// session locally; it is never the thing the app reads from afterwards. That
/// is what lets the device restart with no network and still know who is
/// holding it.
class AuthRepository {
  const AuthRepository({
    required this.api,
    required this.sessions,
    required this.tokens,
  });

  final AuthApi api;
  final SessionDao sessions;
  final TokenStore tokens;

  /// Reads the session already on this device. No network involved.
  Future<Responder?> restoreSession() => sessions.readActiveSession();

  /// Authenticates against the backend, then persists the result locally.
  Future<Responder> signIn({
    required String email,
    required String password,
  }) async {
    final result = await api.login(email: email, password: password);

    await tokens.save(
      accessToken: result.tokens.accessToken,
      refreshToken: result.tokens.refreshToken,
    );

    final responder = Responder(
      id: result.profile.id,
      email: result.profile.email,
      fullName: result.profile.fullName,
      role: result.profile.role,
      signedInAt: DateTime.now().toUtc(),
    );

    await sessions.saveSession(responder);
    return responder;
  }

  /// Creates a session without contacting anything.
  ///
  /// This is not a fake login: it produces a genuine local session, marked as
  /// such, so the offline-first path can be exercised and demonstrated with no
  /// infrastructure at all. Records authored under it carry the flag through
  /// to synchronisation in a later slice.
  Future<Responder> startOfflineDemoSession({
    required ResponderRole role,
  }) async {
    final responder = Responder(
      id: 'offline-${_randomSuffix()}',
      email: 'offline.demo@device.local',
      fullName: 'Offline Demo Responder',
      role: role,
      signedInAt: DateTime.now().toUtc(),
      isOfflineDemo: true,
    );

    await sessions.saveSession(responder);
    return responder;
  }

  Future<Responder> changeRole(Responder responder, ResponderRole role) async {
    await sessions.updateRole(responder.id, role);
    return responder.copyWith(role: role);
  }

  Future<void> signOut() async {
    await tokens.clear();
    await sessions.clear();
  }

  static String _randomSuffix() {
    final random = Random.secure();
    return List<int>.generate(6, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
