import '../../../domain/entities/responder.dart';

/// Authentication state as the router and UI consume it.
sealed class AuthState {
  const AuthState();
}

/// Reading the locally persisted session. The splash screen owns this state.
class AuthRestoring extends AuthState {
  const AuthRestoring();
}

/// No session on this device.
class AuthSignedOut extends AuthState {
  const AuthSignedOut([this.message]);

  /// Set when the previous attempt failed, so the login screen can explain why.
  final String? message;
}

/// A sign-in attempt is in flight.
class AuthSigningIn extends AuthState {
  const AuthSigningIn();
}

/// A session exists locally; the device is usable.
class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.responder);

  final Responder responder;
}

extension AuthStateX on AuthState {
  Responder? get responderOrNull =>
      this is AuthSignedIn ? (this as AuthSignedIn).responder : null;

  bool get isSignedIn => this is AuthSignedIn;

  bool get isRestoring => this is AuthRestoring;
}
