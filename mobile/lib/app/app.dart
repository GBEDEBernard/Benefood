import 'package:flutter/material.dart';

import '../core/auth/session_provider.dart';
import '../core/data/marketplace_api.dart';
import '../core/theme/app_theme.dart';
import '../router/app_router.dart';

class BeninfoodApp extends StatelessWidget {
  const BeninfoodApp({
    super.key,
    required this.session,
    required this.marketplace,
  });

  final SessionProvider session;
  final MarketplaceApi marketplace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Béninfood',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: buildAppRouter(session, marketplace),
    );
  }
}