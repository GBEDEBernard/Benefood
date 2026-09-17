import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erreur API normalisée (J24, §4).
///
/// L'API Laravel répond toujours avec :
/// `{ "message": "...", "errors": { field: [messages] }, "code": "...", "status": 401 }`
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.message,
    this.code,
    this.fieldErrors = const {},
    this.traceId,
  });

  final int status;
  final String message;
  final String? code;

  /// Erreurs de validation par champ (`errors.field` de l'API).
  final Map<String, List<String>> fieldErrors;
  final String? traceId;

  bool get isValidation => status == 422;
  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isNotFound => status == 404;
  bool get isConflict => status == 409;
  bool get isRateLimited => status == 429;
  bool get isServerError => status >= 500;

  factory ApiException.network(Object cause) => ApiException(
        status: 0,
        message: 'Connexion impossible. Vérifiez votre réseau.',
        code: 'network.error',
      );

  factory ApiException.timeout() => ApiException(
        status: 0,
        message: 'Le serveur met trop de temps à répondre.',
        code: 'network.timeout',
      );

  factory ApiException.fromResponse(http.Response response) {
    Map<String, dynamic>? body;
    try {
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {
      body = null;
    }

    String? message;
    String? code;
    String? traceId;
    Map<String, List<String>> fields = {};

    final rawErrors = body?['errors'];
    if (rawErrors is List) {
      // Format Béninfood : [{ code, message, field }]
      final messages = <String>{};
      for (final entry in rawErrors) {
        if (entry is Map<String, dynamic>) {
          final m = entry['message'];
          if (m is String && m.isNotEmpty) {
            messages.add(m);
          }
          final c = entry['code'];
          if (code == null && c is String && c.isNotEmpty) {
            code = c;
          }
          final f = entry['field'];
          if (f is String && f.isNotEmpty) {
            final mm = entry['message'];
            if (mm is String && mm.isNotEmpty) {
              fields.putIfAbsent(f, () => []).add(mm);
            }
          }
        }
      }
      if (messages.isNotEmpty) {
        message = messages.first;
      }
    } else if (body?['message'] is String) {
      message = body?['message'] as String;
    } else if (body?['errors'] is Map<String, dynamic>) {
      // Format Laravel : { errors: { field: [...] } }
      final raw = body?['errors'] as Map<String, dynamic>;
      raw.forEach((key, value) {
        if (value is List) {
          fields[key] = value.map((e) => e.toString()).toList();
        } else if (value is String) {
          fields[key] = [value];
        }
      });
      final rawMessage = body?['message'];
      message = rawMessage is String ? rawMessage : _fallbackMessage(response.statusCode);
    }

    if (message == null || message.isEmpty) {
      message = _fallbackMessage(response.statusCode);
    }

    return ApiException(
      status: response.statusCode,
      message: message,
      code: code,
      fieldErrors: fields,
      traceId: traceId,
    );
  }

  @override
  String toString() => 'ApiException($status $code): $message';
}

String _fallbackMessage(int status) => switch (status) {
      400 => 'Requête invalide.',
      401 => 'Session expirée, reconnectez-vous.',
      403 => 'Accès refusé.',
      404 => 'Ressource introuvable.',
      409 => 'Action impossible dans l’état actuel.',
      422 => 'Vérifiez les informations saisies.',
      429 => 'Trop de requêtes, veuillez réessayer plus tard.',
      _ => 'Une erreur est survenue.',
    };