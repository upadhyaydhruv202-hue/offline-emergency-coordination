/// Failures the UI is expected to render, as opposed to programming errors.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The coordination backend could not be contacted at all.
class OfflineException extends AppException {
  const OfflineException([
    super.message =
        'No route to the coordination backend. Continue in offline demo mode to keep working.',
  ]);
}

/// Credentials were rejected, or a token is missing/expired.
class AuthenticationException extends AppException {
  const AuthenticationException([super.message = 'Invalid email or password.']);
}

/// The backend answered, but with an error.
class ApiException extends AppException {
  const ApiException(this.statusCode, super.message);

  final int statusCode;
}

/// The local datastore could not be opened or migrated.
class LocalDatabaseException extends AppException {
  const LocalDatabaseException(super.message);
}

/// The device could not produce a position.
///
/// Distinct from [OfflineException] on purpose: GPS is a satellite service and
/// has nothing to do with whether the backend is reachable. Conflating the two
/// would teach a responder that losing signal means losing their position,
/// which is both false and dangerous.
class LocationUnavailableException extends AppException {
  const LocationUnavailableException(super.message, {this.isPermanent = false});

  /// True when retrying cannot help — the permission was refused for good, and
  /// the responder has to change it in the operating system's settings.
  final bool isPermanent;
}
