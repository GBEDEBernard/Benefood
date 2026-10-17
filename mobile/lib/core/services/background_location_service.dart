import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Suivi de la position du livreur en arrière-plan.
///
/// Pendant une mission active, le service maintient un processus Android en
/// premier plan (notification « suivi de livraison ») et une tâche iOS, et
/// transmet la position au serveur toutes les 15 s même quand l'app est
/// minimisée ou l'écran éteint.
///
/// L'isolation du service impose de refaire un appel HTTP léger (et non de
/// réutiliser [MarketplaceApi]) : on lit donc le token Sanctum directement depuis
/// le Keystore et l'URL de base depuis les préférences, comme le fait l'app.
class BackgroundLocationService {
  BackgroundLocationService._();

  static const _channelId = 'beninfood_location';
  static const _notificationId = 888;
  static const _tokenKey = 'auth_token';
  static const _overrideKey = 'api_base_url_override';
  static const _endpoint = '/driver/me/availability/location';
  static const _interval = Duration(seconds: 15);

  /// Configure le service (à faire une fois au démarrage de l'app).
  static Future<void> configure() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: false,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'Béninfood — suivi de livraison',
        initialNotificationContent: 'Votre position est partagée avec le client.',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// Démarre le suivi si ce n'est pas déjà fait.
  static Future<void> start() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      service.startService();
    }
  }

  /// Arrête le suivi (appelé à la fin de la mission ou à la déconnexion).
  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }

  /// Point d'entrée du service (exécuté dans un isolate séparé).
  static void _onStart(ServiceInstance service) {
    Timer.periodic(_interval, (_) => _reportPosition());

    // Arrêt propre quand le service est stoppé (app en premier plan).
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  /// Retourne `true` à iOS pour continuer en arrière-plan.
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    await _reportPosition();
    return true;
  }

  /// Une transmission de position : position GPS + PATCH authentifié.
  static Future<void> _reportPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));

      final token = await _readToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final uri = Uri.parse('${await _apiUrl()}$_endpoint');
      final response = await http
          .patch(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Accept-Language': 'fr',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'latitude': position.latitude,
              'longitude': position.longitude,
            }),
          )
          .timeout(const Duration(seconds: 10));

      // 401 : token expiré — on laisse l'app principale le rafraîchir.
      if (response.statusCode >= 400 && response.statusCode != 401) {
        return;
      }
    } catch (_) {
      // Position ou réseau indisponible : on réessaiera au prochain tick.
    }
  }

  static Future<String?> _readToken() async {
    const storage = FlutterSecureStorage();
    return storage.read(key: _tokenKey);
  }

  static Future<String> _apiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(_overrideKey)?.trim();
    final base = (override != null && override.isNotEmpty)
        ? override
        : (Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000');
    return '$base/api/v1';
  }
}
