import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../core/http/api_client.dart';
import '../../core/storage/secure_token_store.dart';
import '../../shared/models/user.dart';

/// État d'authentification global + restauration de session (J146).
///
/// Consomme `POST /auth/login`, `POST /auth/register`, `GET /me`,
/// `POST /me/active-role` et stocke le token dans le secure storage.
class SessionProvider extends ChangeNotifier {
  SessionProvider({
    required ApiClient api,
    SecureTokenStore? tokenStore,
  })  : _api = api,
        _tokenStore = tokenStore ?? SecureTokenStore();

  final ApiClient _api;
  final SecureTokenStore _tokenStore;

  static const _activeRoleKey = 'active_role';
  static const _sessionUserKey = 'session_user';

  bool _initialized = false;
  bool _restoring = true;
  User? _user;
  String? _activeRole;

  bool get initialized => _initialized;
  bool get restoring => _restoring;
  bool get isAuthenticated => _user != null;
  User? get user => _user;
  String? get activeRole => _activeRole;

  /// Restaure la session au lancement (Splash, J146 §2.1).
  ///
  /// La restauration est bornée dans le temps : le splash ne doit jamais
  /// rester bloqué si le secure storage ou le réseau ne répondent pas.
  Future<void> restoreSession() async {
    debugPrint('restoreSession: START');
    _restoring = true;
    _initialized = false;
    debugPrint('restoreSession: _restoring=true, calling notifyListeners');
    notifyListeners();

    try {
      debugPrint('restoreSession: calling _restoreSession with 12s timeout');
      await _restoreSession().timeout(const Duration(seconds: 12));
      debugPrint('restoreSession: _restoreSession completed');
    } catch (e) {
      debugPrint('restoreSession: restauration interrompue ($e)');
    } finally {
      _initialized = true;
      _restoring = false;
      debugPrint('restoreSession: _restoring=false, calling notifyListeners in finally');
      notifyListeners();
      debugPrint('restoreSession: END (finally completed)');
    }
  }

  Future<void> _restoreSession() async {
    debugPrint('_restoreSession: START');
    Map<String, dynamic>? session;
    try {
      debugPrint('_restoreSession: reading session from tokenStore (5s timeout)');
      session = await _tokenStore.readSession().timeout(const Duration(seconds: 5));
      debugPrint('_restoreSession: readSession completed, result is ${session == null ? 'null' : 'non-null'}');
    } catch (e) {
      debugPrint('restoreSession: session illisible ($e)');
      return;
    }

    if (session == null) {
      debugPrint('_restoreSession: session is null, returning early (no cached session)');
      return;
    }

    debugPrint('_restoreSession: session found, checking _me');
    _activeRole = session[_activeRoleKey] is String ? session[_activeRoleKey] as String : null;

    try {
      debugPrint('_restoreSession: calling GET /me');
      final response = await _api.get('/me');
      debugPrint('_restoreSession: GET /me completed');
      _user = User.fromJson(_dataOf(response));
      if (_user != null && (_activeRole == null || !_user!.contexts.contains(_activeRole))) {
        _activeRole = _defaultRoleFor(_user!);
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        debugPrint('_restoreSession: 401 on /me, clearing token');
        await _tokenStore.clear();
        _activeRole = null;
        return;
      }
      debugPrint('_restoreSession: ApiException on /me, using cached user');
      _user = _cachedUserFrom(session);
    } catch (e) {
      // Réseau : on garde la session locale pour l'expérience offline.
      debugPrint('restoreSession: réseau indisponible ($e)');
      _user = _cachedUserFrom(session);
    }
  }

  User? _cachedUserFrom(Map<String, dynamic> session) {
    final rawUser = session[_sessionUserKey];
    if (rawUser is Map<String, dynamic>) {
      return User.fromJson(rawUser);
    }
    return null;
  }

  Future<void> login(String login, String password) async {
    final response = await _api.post('/auth/login', body: {
      'login': login,
      'password': password,
    });

    final payload = _dataOf(response);
    await _tokenStore.write(payload);

    final user = User.fromJson(payload['user'] as Map<String, dynamic>?);
    _setUser(user);
  }

  Future<void> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    required String passwordConfirmation,
    List<String> roles = const ['client'],
  }) async {
    final response = await _api.post('/auth/register', body: {
      'name': name,
      'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'roles': roles,
    });

    final payload = _dataOf(response);
    await _tokenStore.write(payload);

    final user = User.fromJson(payload['user'] as Map<String, dynamic>?);
    _setUser(user);
  }

  Future<void> forgotPassword(String login) async {
    await _api.post('/auth/forgot-password', body: {'login': login});
  }

  Future<void> resetPassword({
    required String login,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _api.post('/auth/reset-password', body: {
      'login': login,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'code': code,
    });
  }

  /// Bascule de contexte (J19 §2.6).
  ///
  /// [context] est un contexte canonique (`client`, `vendor`, `driver`) ; le
  /// slug réel du rôle (`driver-independent`, …) est résolu via le profil.
  Future<void> switchRole(String context) async {
    final slug = _user?.slugForContext(context) ?? context;
    await _api.post('/me/active-role', body: {'role_slug': slug});
    _activeRole = context;
    await _persist();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    try {
      final response = await _api.get('/me');
      _user = User.fromJson(_dataOf(response));
      notifyListeners();
    } on ApiException {
      // Silencieux : le contexte actif reste valide.
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // On déconnecte même si le serveur échoue.
    }
    await _tokenStore.clear();
    _user = null;
    _activeRole = null;
    notifyListeners();
  }

  void _setUser(User user) {
    _user = user;
    if (_activeRole == null || !user.contexts.contains(_activeRole)) {
      // Règle J19 §2.6 : premier rôle actif par défaut.
      _activeRole = _defaultRoleFor(user);
    }
    _persist();
    notifyListeners();
  }

  String? _defaultRoleFor(User user) {
    if (user.roleSlugs.isEmpty) {
      return null;
    }
    if (user.hasRoleClient) {
      return AppContext.client;
    }
    if (user.hasRoleVendor) {
      return AppContext.vendor;
    }
    if (user.hasRoleDriver) {
      return AppContext.driver;
    }
    return AppContext.fromSlug(user.roleSlugs.first);
  }

  Future<void> _persist() async {
    await _tokenStore.writeSession({
      _activeRoleKey: _activeRole,
      _sessionUserKey: _user?.toJson(),
    });
  }
}

Map<String, dynamic> _dataOf(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is List) {
    return {'list': data};
  }
  return response;
}
