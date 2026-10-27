import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../data/marketplace_api.dart';
import 'location_service.dart';

/// Présence GPS du livreur « en ligne ».
///
/// Le suivi d'une mission envoie déjà la position en continu. Hors mission,
/// ce service prend le relais : position immédiate à la mise en ligne puis
/// rafraîchissement périodique, afin que le livreur reste visible dans la
/// recherche des clients (le serveur ignore les positions de plus de 5 min).
class DriverPresenceService {
  DriverPresenceService._();

  /// `true` tant que le livreur est considéré en ligne par l'application.
  static final ValueNotifier<bool> online = ValueNotifier<bool>(false);

  static MarketplaceApi? _api;
  static Timer? _timer;
  static bool _reporting = false;

  /// Passe en ligne avec une position GPS réelle.
  ///
  /// Retourne l'échec de localisation le cas échéant : la disponibilité n'est
  /// alors pas modifiée, pour ne jamais afficher un livreur « en ligne » sans
  /// position exploitable.
  static Future<LocationFailure?> goOnline(MarketplaceApi api) async {
    _api = api;

    final result = await LocationService.currentPosition();
    if (!result.isSuccess) {
      if (kDebugMode) {
        debugPrint(
          '[driver_presence] mise en ligne refusée : ${result.failure?.name}',
        );
      }
      return result.failure;
    }

    final geo = result.geo!;
    await api.setAvailability(
      true,
      latitude: geo.latitude,
      longitude: geo.longitude,
    );

    online.value = true;
    _startHeartbeat();

    return null;
  }

  /// Passe hors ligne et arrête le suivi.
  static Future<void> goOffline(MarketplaceApi api) async {
    _api = api;
    _stopHeartbeat();
    online.value = false;
    await api.setAvailability(false);
  }

  /// Réaligne le suivi sur l'état réel du profil (ouverture de l'app, retour
  /// au premier plan, rafraîchissement de l'écran missions).
  static Future<void> sync(MarketplaceApi api, bool isAvailable) async {
    _api = api;
    online.value = isAvailable;

    if (!isAvailable) {
      _stopHeartbeat();
      return;
    }

    _startHeartbeat();
    await reportNow();
  }

  /// Envoie immédiatement la position courante.
  static Future<void> reportNow() async {
    final api = _api;
    if (api == null || _reporting) {
      return;
    }

    _reporting = true;
    try {
      final result = await LocationService.currentPosition();
      if (!result.isSuccess) {
        return;
      }
      final geo = result.geo!;
      await api.updateDriverLocation(geo.latitude, geo.longitude);
      online.value = true;
    } catch (error) {
      // Réseau ou GPS indisponible : le prochain battement réessaiera.
      if (kDebugMode) {
        debugPrint('[driver_presence] position non transmise : $error');
      }
    } finally {
      _reporting = false;
    }
  }

  /// Suspend le rafraîchissement périodique sans changer l'état en ligne
  /// (écran livreur fermé). Il reprend au prochain [sync] ou retour au premier
  /// plan, sans laisser de minuteur actif derrière soi.
  static void pauseHeartbeat() {
    _stopHeartbeat();
  }

  /// Arrête le suivi (déconnexion, changement de compte).
  static void stop() {
    _stopHeartbeat();
    _api = null;
    online.value = false;
  }

  static void _startHeartbeat() {
    if (_timer != null || _api == null) {
      return;
    }
    _timer = Timer.periodic(
      const Duration(seconds: AppConfig.idleLocationIntervalSeconds),
      (_) => unawaited(reportNow()),
    );
  }

  static void _stopHeartbeat() {
    _timer?.cancel();
    _timer = null;
  }
}
