import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class AppConfig {
  const AppConfig._();

  static const String appName = 'Béninfood';

  /// URL de base de l'API Laravel.
  ///
  /// Surchargable au build : `flutter run --dart-define=API_BASE_URL=...`.
  /// - Appareil physique : `http://IP-de-la-machine:8000` (ex. `192.168.1.110`).
  /// - Émulateur Android : `10.0.2.2` (= loopback de la machine hôte).
  /// - Desktop & iOS Simulator : `127.0.0.1`.
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Émulateur Android : 10.0.2.2 pointe vers la machine hôte.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static const String apiVersion = 'v1';

  static String get apiUrl => '$apiBaseUrl/api/$apiVersion';
}