import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../http/api_client.dart';

/// Stockage des tokens d'authentification (Sanctum).
///
/// Sur mobile, utilise [FlutterSecureStorage] (Keystore Keychain / Android Keystore).
/// Sur Linux desktop, [flutter_secure_storage] délègue à libsecret via D-Bus
/// (Secret Service). Si aucun Secret Service daemon (gnome-keyring / kwallet)
/// n'est lancé, l'appel C++ synchrone `secret_password_storev_sync` bloque le
/// thread de la plateforme indéfiniment — gel de l'UI et du hot reload.
/// On contourne cela en utilisant [SharedPreferences] (fichier JSON) sur Linux.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _secureStorage = storage ??
            const FlutterSecureStorage(
              // `encryptedSharedPreferences: true` s'appuie sur
              // androidx.security.crypto, qui se bloque indéfiniment sur
              // certains appareils (Android 12, certains Samsung). Le mode
              // direct utilise l'AES-GCM du Keystore Android, plus fiable.
              aOptions: AndroidOptions(encryptedSharedPreferences: false),
            ) {
    _usePrefs = !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
  }

  final FlutterSecureStorage _secureStorage;
  late final bool _usePrefs;
  static const _tokenKey = 'auth_token';
  static const _refreshKey = 'auth_refresh_token';
  static const _expiresKey = 'auth_expires_at';
  static const _sessionKey = 'auth_session';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> readToken() =>
      _usePrefs ? _prefs.then((p) => p.getString(_tokenKey)) : _secureStorage.read(key: _tokenKey);

  @override
  Future<String?> readRefreshToken() =>
      _usePrefs ? _prefs.then((p) => p.getString(_refreshKey)) : _secureStorage.read(key: _refreshKey);

  @override
  Future<void> write(Map<String, dynamic> payload) async {
    final token = payload['access_token'];
    if (_usePrefs) {
      final p = await _prefs;
      if (token != null) {
        await p.setString(_tokenKey, token.toString());
      }
      await p.setString(_refreshKey, (payload['refresh_token'] ?? _refreshTokenPlaceholder).toString());
      if (payload['expires_at'] != null) {
        await p.setString(_expiresKey, payload['expires_at'].toString());
      }
    } else {
      if (token != null) {
        await _secureStorage.write(key: _tokenKey, value: token.toString());
      }
      await _secureStorage.write(key: _refreshKey, value: (payload['refresh_token'] ?? _refreshTokenPlaceholder).toString());
      if (payload['expires_at'] != null) {
        await _secureStorage.write(key: _expiresKey, value: payload['expires_at'].toString());
      }
    }
  }

  Future<void> writeSession(Map<String, dynamic> session) async {
    final encoded = jsonEncode(session);
    if (_usePrefs) {
      await _prefs.then((p) => p.setString(_sessionKey, encoded));
    } else {
      await _secureStorage.write(key: _sessionKey, value: encoded);
    }
  }

  Future<Map<String, dynamic>?> readSession() async {
    final raw = await (_usePrefs
        ? _prefs.then((p) => p.getString(_sessionKey))
        : _secureStorage.read(key: _sessionKey));
    if (raw == null || raw.isEmpty) {
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
    if (_usePrefs) {
      final p = await _prefs;
      await Future.wait([
        p.remove(_tokenKey),
        p.remove(_refreshKey),
        p.remove(_expiresKey),
        p.remove(_sessionKey),
      ]);
    } else {
      await Future.wait([
        _secureStorage.delete(key: _tokenKey),
        _secureStorage.delete(key: _refreshKey),
        _secureStorage.delete(key: _expiresKey),
        _secureStorage.delete(key: _sessionKey),
      ]);
    }
  }
}

/// Le backend émet uniquement `access_token` (Sanctum). En fallback on le
/// réutilise comme refresh pour la démo locale.
String get _refreshTokenPlaceholder => '';
