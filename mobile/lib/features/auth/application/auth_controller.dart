import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/local/database_providers.dart';
import '../../../data/remote/auth_api.dart';
import '../../../domain/entities/responder_role.dart';
import '../data/auth_repository.dart';
import '../data/token_store.dart';
import 'auth_state.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  final api = AuthApi();
  ref.onDispose(api.close);
  return api;
});

final tokenStoreProvider = Provider<TokenStore>((ref) => const TokenStore());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    api: ref.watch(authApiProvider),
    sessions: ref.watch(sessionDaoProvider),
    tokens: ref.watch(tokenStoreProvider),
  ),
);

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  bool _disposed = false;

  @override
  AuthState build() {
    ref.onDispose(() => _disposed = true);
    scheduleMicrotask(_restore);
    return const AuthRestoring();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    try {
      final responder = await _repository.restoreSession();
      _set(
        responder == null
            ? const AuthSignedOut()
            : AuthSignedIn(responder),
      );
    } on Exception catch (error) {
      _set(AuthSignedOut('Could not read the local session: $error'));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _set(const AuthSigningIn());
    try {
      _set(AuthSignedIn(await _repository.signIn(email: email, password: password)));
    } on AppException catch (error) {
      _set(AuthSignedOut(error.message));
    }
  }

  /// Starts a local-only session. Never touches the network, so it cannot fail
  /// for connectivity reasons.
  Future<void> startOfflineDemo(ResponderRole role) async {
    _set(const AuthSigningIn());
    try {
      _set(AuthSignedIn(await _repository.startOfflineDemoSession(role: role)));
    } on Exception catch (error) {
      _set(AuthSignedOut('Could not open a local session: $error'));
    }
  }

  Future<void> changeRole(ResponderRole role) async {
    final current = state;
    if (current is! AuthSignedIn) return;
    _set(AuthSignedIn(await _repository.changeRole(current.responder, role)));
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _set(const AuthSignedOut());
  }

  void _set(AuthState next) {
    if (_disposed) return;
    state = next;
  }
}
