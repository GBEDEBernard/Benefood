
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages de connexion à l'API, persistés sur l'appareil.
///
/// L'URL de base par défaut dépend de la plateforme (émulateur / desktop).
/// Un appareil physique (téléphone) doit pointer vers l'IP locale du poste,
/// ex. `http://192.168.1.102:8000`.
class ApiSettings {
  const ApiSettings._();

  static const String _overrideKey = 'api_base_url_override';

  /// URL de base surchargée (null = comportement par défaut de [AppConfig]).
  static Future<String?> override() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_overrideKey);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  /// Enregistre une URL de base. `null` ou vide = retour au défaut.
  static Future<void> saveOverride(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final value = url?.trim();
    if (value == null || value.isEmpty) {
      await prefs.remove(_overrideKey);
    } else {
      await prefs.setString(_overrideKey, value);
    }
  }

  /// Nettoie une saisie utilisateur : retire les slashes de fin et l'éventuel
  /// suffixe `/api/v1` déjà saisi.
  static String? normalize(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    return value.replaceFirst(RegExp(r'/api/v1$'), '').replaceFirst(RegExp(r'/+$'), '');
  }
}