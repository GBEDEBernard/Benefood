import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../app/app.dart';
import '../core/auth/session_provider.dart';
import '../core/config/api_settings.dart';
import '../core/config/app_config.dart';
import '../core/data/marketplace_api.dart';
import '../core/http/api_client.dart';
import '../core/i18n/language_controller.dart';
import '../core/push/push_service.dart';
import '../core/storage/secure_token_store.dart';

Future<void> main() async {
  debugPrint('main: start');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('main: binding initialized');

  // Firebase doit être prêt (et le handler d'arrière-plan enregistré) avant
  // runApp : sinon un message reçu app terminée ne réveille pas le handler.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    // Config Firebase absente (plateforme non enregistrée) : l'app reste
    // utilisable, seules les notifications push sont désactivées.
    debugPrint('main: Firebase indisponible ($e)');
  }

  // URL de l'API : surcharge éventuellement enregistrée par l'utilisateur
  // (écran « Serveur ») pour les appareils physiques, appliquée avant la
  // création du client HTTP.
  debugPrint('main: calling ApiSettings.override()');
  AppConfig.apiBaseUrlOverride = await ApiSettings.override();
  debugPrint('main: apiBaseUrlOverride = ${AppConfig.apiBaseUrlOverride}');

  debugPrint('main: creating ApiClient and SessionProvider');
  final api = ApiClient(tokenStore: SecureTokenStore());
  final session = SessionProvider(api: api);

  await LanguageController.instance.initialize();

  debugPrint('main: calling runApp');
  runApp(
    BeninfoodApp(
      session: session,
      marketplace: MarketplaceApi(api),
    ),
  );
  debugPrint('main: runApp done');

  // Restauration de session après le premier frame (Splash visible).
  debugPrint('main: scheduling microtask for restoreSession');
  Future<void>.microtask(() {
    debugPrint('main: microtask FIRED - calling restoreSession');
    session.restoreSession();
  });
  debugPrint('main: microtask scheduled, main exiting');
}
