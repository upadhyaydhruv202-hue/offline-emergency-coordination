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
