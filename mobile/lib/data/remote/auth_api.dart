import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/responder_role.dart';

/// Tokens plus the profile returned by `POST /auth/login`.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
}

class RemoteProfile {
  const RemoteProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String email;
  final String fullName;
  final ResponderRole role;
}

class LoginResult {
  const LoginResult({required this.tokens, required this.profile});

  final AuthTokens tokens;
  final RemoteProfile profile;
}

/// Thin client over the coordination backend's auth endpoints.
///
/// Every method either returns a value or throws an [AppException]; callers
/// never see a raw socket or format error.
class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final body = await _post('/auth/login', {
      'email': email,
      'password': password,
    });

    return LoginResult(
      tokens: AuthTokens(
        accessToken: body['access_token'] as String,
        refreshToken: body['refresh_token'] as String,
        expiresIn: body['expires_in'] as int,
      ),
      profile: _parseProfile(body['user'] as Map<String, dynamic>),
    );
  }

  Future<RemoteProfile> me(String accessToken) async {
    final body = await _get('/auth/me', accessToken);
    return _parseProfile(body);
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> payload,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(AppConfig.requestTimeout);
    } on Exception {
      throw const OfflineException();
    }
    return _decode(response);
  }

  Future<Map<String, dynamic>> _get(String path, String accessToken) async {
    final http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$_baseUrl$path'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(AppConfig.requestTimeout);
    } on Exception {
      throw const OfflineException();
    }
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = _tryDecodeJson(response.body);

    // A gateway or captive portal can answer with HTML on any status code, so
    // the shape is checked before the status is trusted.
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        response.statusCode,
        'The backend returned a response this build cannot read.',
      );
    }

    if (response.statusCode == 200) return decoded;

    final error = decoded['error'];
    final message = error is Map<String, dynamic>
        ? error['message'] as String? ?? 'Request failed.'
        : 'Request failed.';

    if (response.statusCode == 401) throw AuthenticationException(message);
    throw ApiException(response.statusCode, message);
  }

  Object? _tryDecodeJson(String source) {
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
  }

  RemoteProfile _parseProfile(Map<String, dynamic> json) {
    final role = ResponderRole.tryFromWire(json['role'] as String?);
    if (role == null) {
      throw ApiException(200, 'Unrecognised role "${json['role']}".');
    }
    return RemoteProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: role,
    );
  }
}
