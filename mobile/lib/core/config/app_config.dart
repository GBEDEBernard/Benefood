import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class AppConfig {
  const AppConfig._();

  static const String appName = 'Béninfood';

  /// URL de base de l'API Laravel.
  ///
  /// Priorité : 1) surcharge persistée dans l'app (écran « Serveur »),
  /// 2) `--dart-define=API_BASE_URL=...` au build,
  /// 3) défaut selon la plateforme :
  /// - Appareil physique : régler via l'écran « Serveur » (ex. `192.168.1.110`).
  /// - Émulateur Android : `10.0.2.2` (= loopback de la machine hôte).
  /// - Desktop & iOS Simulator : `127.0.0.1`.
  static String? apiBaseUrlOverride;

  static String get apiBaseUrl {
    final override = apiBaseUrlOverride;
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return defaultApiBaseUrl;
  }

  static String get defaultApiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Émulateur Android : 10.0.2.2 pointe vers la machine hôte.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static const String apiVersion = 'v1';

  /// Fond de carte configurable au build :
  /// `--dart-define=MAP_TILE_URL=https://…/{z}/{x}/{y}.png`.
  ///
  /// Le serveur public OpenStreetMap reste le repli de développement ; il ne
  /// doit pas être utilisé pour un déploiement à fort trafic.
  static const String mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const String mapAttribution = String.fromEnvironment(
    'MAP_ATTRIBUTION',
    defaultValue: '© OpenStreetMap',
  );

  /// Fréquence d'envoi de la position livreur (secondes).
  static const int locationIntervalSeconds = int.fromEnvironment(
    'LOCATION_INTERVAL_S',
    defaultValue: 4,
  );

  /// Déplacement minimal avant un nouvel envoi GPS (mètres).
  static const int locationDistanceFilterMeters = int.fromEnvironment(
    'LOCATION_DISTANCE_FILTER_M',
    defaultValue: 10,
  );

  /// Fréquence d'envoi de la position d'un livreur en ligne mais sans mission
  /// (secondes). Doit rester inférieure à la fraîcheur GPS exigée côté serveur
  /// (300 s par défaut) pour que le livreur reste visible des clients.
  static const int idleLocationIntervalSeconds = int.fromEnvironment(
    'IDLE_LOCATION_INTERVAL_S',
    defaultValue: 60,
  );

  /// Âge à partir duquel la position est signalée comme ancienne.
  static const int staleWarnSeconds = int.fromEnvironment(
    'STALE_WARN_S',
    defaultValue: 30,
  );

  /// Âge à partir duquel l'ETA est masquée (position trop ancienne).
  static const int staleHideEtaSeconds = int.fromEnvironment(
    'STALE_HIDE_ETA_S',
    defaultValue: 120,
  );

  /// Seuil de recalcul d'itinéraire (écart en mètres).
  static const int rerouteDeviationMeters = int.fromEnvironment(
    'REROUTE_DEVIATION_M',
    defaultValue: 50,
  );

  /// Intervalle minimal entre deux recalculs automatiques (secondes).
  static const int rerouteMinIntervalSeconds = int.fromEnvironment(
    'REROUTE_MIN_INTERVAL_S',
    defaultValue: 45,
  );

  /// Rayon d'arrivée au point de livraison (mètres).
  static const int arrivalRadiusMeters = int.fromEnvironment(
    'ARRIVAL_RADIUS_M',
    defaultValue: 120,
  );

  /// Missions simultanées autorisées pour un livreur.
  static const int maxActiveMissions = int.fromEnvironment(
    'MAX_ACTIVE_MISSIONS',
    defaultValue: 2,
  );

  static String get apiUrl => '$apiBaseUrl/api/$apiVersion';
}