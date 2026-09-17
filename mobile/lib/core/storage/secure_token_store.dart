import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../http/api_client.dart';

/// Stockage sécurisé des tokens d'authentification (Sanctum).
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _tokenKey = 'auth_token';
  static const _refreshKey = 'auth_refresh_token';
  static const _expiresKey = 'auth_expires_at';
  static const _sessionKey = 'auth_session';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> write(Map<String, dynamic> payload) async {
    final token = payload['access_token'];
    if (token != null) {
      await _storage.write(key: _tokenKey, value: token.toString());
    }
    await _storage.write(key: _refreshKey, value: (payload['refresh_token'] ?? _refreshTokenPlaceholder).toString());
    if (payload['expires_at'] != null) {
      await _storage.write(key: _expiresKey, value: payload['expires_at'].toString());
    }
  }

  Future<void> writeSession(Map<String, dynamic> session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session));
  }

  Future<Map<String, dynamic>?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _expiresKey);
    await _storage.delete(key: _sessionKey);
  }
}

/// Le backend émet uniquement `access_token` (Sanctum). En fallback on le
/// réutilise comme refresh pour la démo locale.
String get _refreshTokenPlaceholder => '';