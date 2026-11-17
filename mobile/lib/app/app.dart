import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/auth/session_provider.dart';
import '../core/data/marketplace_api.dart';
import '../core/i18n/app_localizations.dart';
import '../core/i18n/language_controller.dart';
import '../core/navigation/notification_router.dart';
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
    final languages = LanguageController.instance;
    unawaited(languages.initialize());
    languages.attach(marketplace: widget.marketplace, session: widget.session);
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
    if (user == null) {
      // Déconnexion : la prochaine session devra réenregistrer le jeton FCM.
      _pushReady = false;
      _pushUserId = null;
      PushService.audience = NotificationAudience.client;
      return;
    }
    if (widget.session.restoring) {
      return;
    }

    LanguageController.instance.applyUserLocale(user.locale);

    // L'espace actif peut changer sans nouvelle session : le deep-link des
    // notifications doit suivre (suivi client ↔ commande vendeur ↔ mission).
    PushService.audience = notificationAudienceFromRole(
      widget.session.activeRole,
    );

    if (_pushReady && _pushUserId == user.id) {
      return;
    }
    _pushReady = true;
    _pushUserId = user.id;

    PushService.rootContext = context;
    PushService.initialize(marketplace: widget.marketplace);
  }

  @override
  Widget build(BuildContext context) {
    PushService.rootContext = context;
    return ListenableBuilder(
      listenable: LanguageController.instance,
      builder: (context, _) {
        final language = LanguageController.instance;
        return AppLocalizations(
          languageCode: language.code,
          child: MaterialApp.router(
            title: context.tr('Béninfood'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            // Le fon n'a pas encore de localisations Material : les widgets
            // système restent en français, les textes de l'app sont traduits
            // par AppLocalizations.
            locale: language.code == 'fon'
                ? const Locale('fr')
                : language.code == 'en'
                    ? Locale('en')
                    : language.locale,
            supportedLocales: const [Locale('fr'), Locale('en'), Locale('fon')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: buildAppRouter(widget.session, widget.marketplace),
          ),
        );
      },
    );
  }
}
