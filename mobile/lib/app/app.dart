import 'package:flutter/material.dart';

import '../core/auth/session_provider.dart';
import '../core/data/marketplace_api.dart';
import '../core/push/push_service.dart';
import '../core/theme/app_theme.dart';
import '../router/app_router.dart';

/// Racine de l'application : thème, routeur, push FCM (deep-link « nouvelle
/// commande ») lié à la session courante.
class BeninfoodApp extends StatefulWidget {
  const BeninfoodApp({
    super.key,
    required this.session,
    required this.marketplace,
  });

  final SessionProvider session;
  final MarketplaceApi marketplace;

  @override
  State<BeninfoodApp> createState() => _BeninfoodAppState();
}

class _BeninfoodAppState extends State<BeninfoodApp> {
  bool _pushReady = false;
  String? _pushUserId;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// (Re)branche le push dès qu'une session existe (et rejoué au changement
  /// de contexte pour réenregistrer le jeton côté serveur).
  void _onSessionChanged() {
    final user = widget.session.user;
    if (user == null || widget.session.restoring) {
      return;
    }
    if (_pushReady && _pushUserId == user.id) {
      return;
    }
    _pushReady = true;
    _pushUserId = user.id;

    final role = widget.session.activeRole;
    PushService.rootContext = context;
    PushService.initialize(
      marketplace: widget.marketplace,
      isVendor: role == 'vendor',
    );
  }

  @override
  Widget build(BuildContext context) {
    PushService.rootContext = context;
    return MaterialApp.router(
      title: 'Béninfood',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: buildAppRouter(widget.session, widget.marketplace),
    );
  }
}
