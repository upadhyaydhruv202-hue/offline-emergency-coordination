import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keystore/Keychain-backed storage for the bearer tokens.
///
/// Tokens are the only secret the field device holds in Slice 1. They are kept
/// out of the Drift database so that a database export - a plausible field
/// operation - cannot leak them.
class TokenStore {
  const TokenStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const String _accessKey = 'drp.access_token';
  static const String _refreshKey = 'drp.refresh_token';

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
