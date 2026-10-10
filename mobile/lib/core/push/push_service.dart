import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../data/marketplace_api.dart';
import '../navigation/notification_router.dart';

/// Push FCM + deep-link « nouvelle commande » (J24, infra J126).
///
/// - Enregistre le jeton FCM de l'appareil (`registerDevice`) dès l'init.
/// - Intercepte les taps de notification (app en arrière-plan / terminée ou
///   premier plan) et ouvre l'écran cible porté par les données FCM :
///   `order_id` + `type` + `role` → détail commande vendeur ou client.
///
/// Le service doit être initialisé APRÈS que la session est prête (appelé
/// depuis `BeninfoodApp` quand un utilisateur est connecté).
class PushService {
  PushService._();

  static FirebaseMessaging? _messaging;
  static bool _initialized = false;
  static String? _lastPayloadKey;

  /// Contexte racine fourni par l'app pour ouvrir les écrans du deep-link.
  static BuildContext? rootContext;

  /// Initialise FCM et abonne les écouteurs. Idempotent.
  static Future<void> initialize({
    required MarketplaceApi marketplace,
    required bool isVendor,
  }) async {
    if (_initialized) {
      return;
    }
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Firebase non configuré (sans google-services.json) : push silencieux,
      // l'app reste fonctionnelle via le center de notifications intégré.
      debugPrint('PushService: Firebase indisponible ($e)');
      return;
    }
    _initialized = true;

    _messaging = FirebaseMessaging.instance;

    // Autorisations (iOS surtout) : alerte, badge, son.
    await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handler requis pour les messages en arrière-plan (iOS / Android 12+).
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Enregistrement du jeton auprès du backend.
    await _registerToken(marketplace);
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      _registerToken(marketplace);
    });

    // Notification tapée alors que l'app est terminée.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleTap(
        marketplace,
        _dataOf(initialMessage),
        isVendor: isVendor,
      );
    }

    // Notification tapée depuis l'arrière-plan.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(
        marketplace,
        _dataOf(message),
        isVendor: isVendor,
      );
    });

    // Premier plan : le backend envoie des messages « notification » ; on
    // laisse l'OS afficher le bandeau et on gère l'ouverture via le
    // deep-link du payload data (order_id).
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('PushService: message FCM premier plan ${message.messageId}');
    });
  }

  /// Anti-doublon : FCM délivre parfois le même tap deux fois.
  static void _handleTap(
    MarketplaceApi marketplace,
    Map<String, dynamic> data, {
    required bool isVendor,
  }) {
    final key = '${data['type']}|${data['order_id']}';
    if (key == _lastPayloadKey) {
      return;
    }
    _lastPayloadKey = key;

    final context = rootContext;
    if (context == null || !context.mounted) {
      return;
    }

    openNotificationTarget(
      context,
      marketplace: marketplace,
      data: data,
      isVendor: isVendor,
    );
  }

  static Map<String, dynamic> _dataOf(RemoteMessage message) {
    return <String, dynamic>{
      ...message.data,
      'title': message.notification?.title ?? message.data['title'],
    };
  }
}

/// Handler des messages FCM en arrière-plan (requis, top-level et annoté).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Rien à faire côté UI : l'OS affiche déjà la notification (transport
  // « notification » du backend). Ce handler est simplement obligatoire.
  debugPrint('PushService: message FCM en arrière-plan (${message.messageId})');
}

Future<void> _registerToken(MarketplaceApi marketplace) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await marketplace.registerDevice(
      fcmToken: token,
      platform: Platform.isIOS ? 'ios' : 'android',
    );
  } catch (_) {
    // Erreur réseau / device : on retentera via onTokenRefresh.
  }
}
