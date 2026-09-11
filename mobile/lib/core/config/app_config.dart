class AppConfig {
  const AppConfig._();

  static const String appName = 'Béninfood';

  /// Base URL de l'API Laravel.
  ///
  /// - Émulateur Android : http://10.0.2.2:8000
  /// - Appareil physique : http://IP-de-la-machine:8000
  /// - iOS Simulator : http://127.0.0.1:8000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String apiVersion = 'v1';

  static String get apiUrl => '$apiBaseUrl/api/$apiVersion';
}