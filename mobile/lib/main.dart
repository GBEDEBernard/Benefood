import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/auth/session_provider.dart';
import 'core/data/marketplace_api.dart';
import 'core/http/api_client.dart';
import 'core/storage/secure_token_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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