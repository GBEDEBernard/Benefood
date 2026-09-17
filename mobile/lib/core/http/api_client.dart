import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../errors/api_exception.dart';

/// Accès à l'API Béninfood `/api/v1`.
///
/// - Injecte le token Sanctum (`Authorization: Bearer`)
/// - Décode la réponse JSON et lève une [ApiException] normalisée (J24)
/// - Gère le refresh du token sur 401 (une seule tentative)
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    required TokenStore tokenStore,
    String? baseUrl,
  })  : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiUrl,
        _tokenStore = tokenStore;

  final http.Client _http;
  final String _baseUrl;
  final TokenStore _tokenStore;

  bool _refreshing = false;
  final List<Completer<void>> _refreshQueue = [];

  String? get baseUrl => _baseUrl;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object?> query = const {},
    bool auth = true,
  }) {
    return _request('GET', path, query: query, auth: auth);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const {},
    bool auth = true,
  }) {
    return _request('POST', path, body: body, query: query, auth: auth);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
    Map<String, Object?> query = const {},
    bool auth = true,
  }) {
    return _request('PATCH', path, body: body, query: query, auth: auth);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Object? body,
    Map<String, Object?> query = const {},
    bool auth = true,
  }) {
    return _request('DELETE', path, body: body, query: query, auth: auth);
  }

  /// Envoie un upload multipart (fichier + champs).
  Future<Map<String, dynamic>> multipart(
    String path, {
    required Map<String, String> fields,
    Map<String, List<int>>? files,
    Map<String, String>? fileNames,
    bool auth = true,
    String method = 'POST',
    void Function(int sent, int total)? onProgress,
  }) async {
    final uri = _uri(path);

    final request = http.MultipartRequest(method, uri);
    if (auth) {
      final token = await _tokenStore.readToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
    request.fields.addAll(fields);
    files?.forEach((name, bytes) {
      request.files.add(http.MultipartFile.fromBytes(
        name,
        bytes,
        filename: fileNames?[name] ?? '$name.bin',
      ));
    });

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response, attemptsLeft: auth ? 1 : 0);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    Map<String, Object?> query = const {},
    bool auth = true,
  }) async {
    _lastMethod = method;
    _lastPath = path;
    _lastBody = body;
    _lastQuery = query;
    _lastAuth = auth;

    final uri = _uri(path, query: query);

    final request = http.Request(method, uri);
    if (auth) {
      final token = await _tokenStore.readToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
    request.headers['Accept'] = 'application/json';
    request.headers['Accept-Language'] = 'fr';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final response = await _send(request);
    return _decode(response, attemptsLeft: auth ? 1 : 0);
  }

  Future<http.Response> _send(http.Request request) async {
    try {
      final streamed = await _http.send(request);
      return await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException.timeout();
    } on http.ClientException catch (e) {
      throw ApiException.network(e.message);
    } catch (e) {
      throw ApiException.network(e.toString());
    }
  }

  Future<Map<String, dynamic>> _decode(http.Response response, {int attemptsLeft = 0}) async {
    if (response.statusCode == 401 && attemptsLeft > 0) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        return _retryLastRequest();
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return const {};
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is List) {
        return {'data': decoded};
      }
      return {'data': decoded};
    }

    throw ApiException.fromResponse(response);
  }

  Object? _lastBody;
  Map<String, Object?>? _lastQuery;
  String? _lastMethod;
  String? _lastPath;
  bool _lastAuth = true;

  Future<Map<String, dynamic>> _retryLastRequest() => _request(
        _lastMethod!,
        _lastPath!,
        body: _lastBody,
        query: _lastQuery ?? const {},
        auth: _lastAuth,
      );

  Future<bool> _refreshToken() async {
    if (_refreshing) {
      final completer = Completer<void>();
      _refreshQueue.add(completer);
      await completer.future;
      return true;
    }

    _refreshing = true;
    try {
      final token = await _tokenStore.readToken();
      if (token == null) {
        return false;
      }

      // Le backend Sanctu crée un nouveau token pour la session courante.
      final response = await http.post(
        _uri('/auth/refresh'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = _extractPayload(body);
        await _tokenStore.write(payload);
        return true;
      }

      await _tokenStore.clear();
      return false;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
      for (final completer in _refreshQueue) {
        completer.complete();
      }
      _refreshQueue.clear();
    }
  }

  Map<String, dynamic> _extractPayload(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic> && data.containsKey('access_token')) {
      return data;
    }
    return body;
  }

  Uri _uri(String path, {Map<String, Object?> query = const {}}) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalized');
    if (query.isEmpty) {
      return uri;
    }
    final map = <String, String>{};
    query.forEach((key, value) {
      if (value != null) {
        map[key] = value.toString();
      }
    });
    return uri.replace(queryParameters: map);
  }
}

/// Persistance du token (SecureStorage côté App).
abstract interface class TokenStore {
  Future<String?> readToken();

  Future<String?> readRefreshToken();

  Future<void> write(Map<String, dynamic> authPayload);

  Future<void> clear();
}