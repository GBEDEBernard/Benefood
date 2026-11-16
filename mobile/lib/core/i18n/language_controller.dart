import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/session_provider.dart';
import '../data/marketplace_api.dart';
import 'app_language.dart';

/// État global de la langue de l'application.
///
/// Le choix est conservé localement pour l'affichage immédiat, puis synchronisé
/// avec l'API (`PATCH /me`, champ `locale`). La liste des langues provient de
/// `GET /languages`, avec un repli intégré (français, anglais, fon).
class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final LanguageController instance = LanguageController._();

  static const _prefsKey = 'app_locale';

  String _code = AppLanguage.french.code;
  List<AppLanguage> _languages = AppLanguage.builtIn;
  MarketplaceApi? _api;
  SessionProvider? _session;
  Future<void>? _initializing;

  String get code => _code;
  Locale get locale => AppLanguage.fromCode(_code).locale;
  AppLanguage get language => AppLanguage.fromCode(_code);
  List<AppLanguage> get languages => List.unmodifiable(_languages);

  /// Charge la langue mémorisée sur l'appareil (au démarrage).
  Future<void> initialize() => _initializing ??= _loadStoredLanguage();

  Future<void> _loadStoredLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      final normalized = AppLanguage.normalize(stored);
      if (normalized != _code) {
        _code = normalized;
        notifyListeners();
      }
    } catch (_) {
      // Stockage indisponible : on garde le français.
    }
  }

  /// Branche l'API et la session, puis charge le référentiel des langues.
  void attach({
    required MarketplaceApi marketplace,
    required SessionProvider session,
  }) {
    _api = marketplace;
    _session = session;
    applyUserLocale(session.user?.locale);
    unawaited(loadLanguages());
  }

  /// Applique la langue enregistrée sur le compte (sans rappeler l'API).
  void applyUserLocale(String? storedCode) {
    if (!AppLanguage.isSupported(storedCode)) {
      return;
    }
    final normalized = AppLanguage.normalize(storedCode);
    if (normalized == _code) {
      return;
    }
    _code = normalized;
    unawaited(_persist(normalized));
    notifyListeners();
  }

  /// Récupère les langues servies par le backend.
  Future<void> loadLanguages() async {
    final api = _api;
    if (api == null) {
      return;
    }
    try {
      final remote = await api.supportedLanguages();
      final byCode = {
        for (final language in remote)
          if (AppLanguage.isSupported(language.code)) language.code: language,
      };
      final merged = [
        for (final fallback in AppLanguage.builtIn)
          byCode[fallback.code] ?? fallback,
      ];
      if (!listEquals(merged, _languages)) {
        _languages = merged;
        notifyListeners();
      }
    } catch (_) {
      // Réseau indisponible : la liste intégrée reste affichée.
    }
  }

  /// Change la langue, la mémorise et la synchronise avec le compte.
  Future<void> setLanguage(String code) async {
    if (!AppLanguage.isSupported(code)) {
      return;
    }
    final normalized = AppLanguage.normalize(code);
    if (normalized == _code) {
      return;
    }

    _code = normalized;
    notifyListeners();
    await _persist(normalized);

    final api = _api;
    final session = _session;
    if (api == null || session == null || !session.isAuthenticated) {
      return;
    }

    try {
      await api.updateMe(locale: normalized);
      await session.applyLocale(normalized);
    } catch (_) {
      // Le choix local reste actif ; la prochaine ouverture réessaiera.
    }
  }

  Future<void> _persist(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {
      // Pas bloquant : la langue reste active pour la session courante.
    }
  }
}
