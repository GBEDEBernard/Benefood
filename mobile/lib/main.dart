import 'package:flutter/material.dart';

import '../app/app.dart';
import '../core/auth/session_provider.dart';
import '../core/config/api_settings.dart';
import '../core/config/app_config.dart';
import '../core/data/marketplace_api.dart';
import '../core/http/api_client.dart';
import '../core/storage/secure_token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // URL de l'API : surcharge éventuellement enregistrée par l'utilisateur
  // (écran « Serveur ») pour les appareils physiques, appliquée avant la
  // création du client HTTP.
  AppConfig.apiBaseUrlOverride = await ApiSettings.override();

  final api = ApiClient(tokenStore: SecureTokenStore());
  final session = SessionProvider(api: api);

  runApp(
    BeninfoodApp(
      session: session,
      marketplace: MarketplaceApi(api),
    ),
  );

  // Restauration de session après le premier frame (Splash visible).
  Future<void>.microtask(session.restoreSession);
}