import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/marketplace_api.dart';
import '../navigation/notification_router.dart';

/// Push FCM + deep-link « nouvelle commande » (J24, infra J126).
///
/// - Enregistre le jeton FCM de l'appareil (`registerDevice`) dès l'init.
/// - Intercepte les taps de notification (app en arrière-plan / terminée ou
///   premier plan) et ouvre l'écran cible porté par les données FCM :
///   `order_id` + `type` + `role` → détail commande vendeur ou client.
/// - Android : affiche une bannière locale quand l'app est au premier plan
///   (FCM ne le fait pas automatiquement). iOS : bannière native via les
///   options de présentation au premier plan.
///
/// Le service doit être initialisé APRÈS que la session est prête (appelé
/// depuis `BeninfoodApp` quand un utilisateur est connecté).
class PushService {
  PushService._();

  static const String _channelId = 'beninfood_default';
  static const String _channelName = 'Notifications Béninfood';
  static const String _channelDescription =
      'Commandes, livraisons et paiements Béninfood';

  static FirebaseMessaging? _messaging;
  static FlutterLocalNotificationsPlugin? _localNotifications;
  static MarketplaceApi? _marketplace;
  static bool _initialized = false;
  static String? _lastPayloadKey;

  /// Contexte racine fourni par l'app pour ouvrir les écrans du deep-link.
  static BuildContext? rootContext;

  /// Espace courant (client, vendeur, livreur) : oriente le détail ouvert au
  /// tap. Tenu à jour par l'app à chaque changement de contexte de session.
  static NotificationAudience audience = NotificationAudience.client;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Initialise FCM et abonne les écouteurs. Idempotent.
  static Future<void> initialize({required MarketplaceApi marketplace}) async {
    if (_initialized) {
      // Nouvelle session (autre compte sur le même appareil) : le jeton FCM
      // doit être réassocié au bon utilisateur côté backend.
      _marketplace = marketplace;
      await _registerToken(marketplace);
      return;
    }

    // `main` initialise Firebase avant `runApp` ; si l'initialisation a échoué
    // (plateforme sans configuration), on reste silencieux.
    if (Firebase.apps.isEmpty) {
      debugPrint('PushService: Firebase non initialisé, push désactivé');
      return;
    }

    _initialized = true;
    _marketplace = marketplace;
    _messaging = FirebaseMessaging.instance;

    // Autorisations (iOS surtout, et POST_NOTIFICATIONS sur Android 13+).
    await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS : affiche la notification même quand l'app est ouverte.
    if (_isIOS) {
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await _initializeLocalNotifications();

    // Enregistrement du jeton auprès du backend.
    await _registerToken(marketplace);
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      _registerToken(marketplace);
    });

    // Notification tapée alors que l'app est terminée.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleTap(marketplace, _dataOf(initialMessage));
    }

    // Notification tapée depuis l'arrière-plan.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(marketplace, _dataOf(message));
    });

    // Premier plan : Android affiche une bannière locale ; iOS laisse l'OS
    // présenter la notification via les options ci-dessus.
    FirebaseMessaging.onMessage.listen((message) async {
      if (_isAndroid) {
        await _showLocalNotification(message);
      }
      debugPrint('PushService: message FCM premier plan ${message.messageId}');
    });
  }

  /// Initialise le plugin Android de notifications locales + son canal.
  static Future<void> _initializeLocalNotifications() async {
    if (!_isAndroid) {
      return;
    }

    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      );

      await plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          final raw = response.payload;
          if (raw == null || raw.isEmpty) {
            return;
          }
          try {
            final decoded = jsonDecode(raw);
            final marketplace = _marketplace;
            if (decoded is! Map || marketplace == null) {
              return;
            }
            _handleTap(marketplace, Map<String, dynamic>.from(decoded));
          } catch (e) {
            debugPrint('PushService: payload de notification invalide ($e)');
          }
        },
      );

      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );

      _localNotifications = plugin;
    } catch (e) {
      debugPrint('PushService: notifications locales indisponibles ($e)');
    }
  }

  /// Bannière locale Android pour un message reçu app ouverte.
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final plugin = _localNotifications;
    if (plugin == null) {
      return;
    }

    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body =
        notification?.body ?? message.data['body']?.toString() ?? '';

    if (title == null && body.isEmpty) {
      return;
    }

    try {
      await plugin.show(
        id: message.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: title ?? 'Béninfood',
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
          ),
        ),
        payload: jsonEncode(_dataOf(message)),
      );
    } catch (e) {
      debugPrint('PushService: affichage local impossible ($e)');
    }
  }

  /// Anti-doublon : FCM délivre parfois le même tap deux fois.
  static void _handleTap(
    MarketplaceApi marketplace,
    Map<String, dynamic> data,
  ) {
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
      audience: audience,
      type: data['type'] is String ? data['type'] as String : null,
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
///
/// Enregistré dans `main` avant `runApp` pour être disponible même quand
/// l'application est terminée.
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
    if (kDebugMode) {
      debugPrint('PushService: FCM token = $token');
    }
    await marketplace.registerDevice(
      fcmToken: token,
      platform: PushService._isIOS ? 'ios' : 'android',
    );
  } catch (_) {
    // Erreur réseau / device : on retentera via onTokenRefresh.
  }
}
