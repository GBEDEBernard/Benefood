import 'package:flutter/material.dart';

import '../../core/data/marketplace_api.dart';
import '../../core/navigation/notification_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'notification_bell.dart';

/// Marque Béninfood affichée au centre des en-têtes de page :
/// logo image (assets/Logo.jpeg) arrondi + écriture bicolore.
class BeninfoodBrand extends StatelessWidget {
  const BeninfoodBrand({super.key, this.logoSize = 30, this.fontSize = 17});

  final double logoSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset(
            'assets/Logo.jpeg',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: AppColors.greenLight,
              child: Center(
                child: Icon(Icons.restaurant, size: 18, color: AppColors.green),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.clip,
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              height: 1.1,
            ),
            children: const [
              TextSpan(text: 'BÉN', style: TextStyle(color: AppColors.green)),
              TextSpan(text: 'INFOOD', style: TextStyle(color: AppColors.orange)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Page standard de l'application : en-tête BÉN INFOOD (menu/retour, marque,
/// **cloche de notification**) puis titre facultatif et contenu.
///
/// Remplace `Scaffold(appBar: AppBar(title: …))` pour que la cloche soit
/// présente sur toutes les pages des trois espaces ; le bouton de gauche
/// revient en arrière quand aucun [onMenu] n'est fourni.
class BeninfoodPageScaffold extends StatelessWidget {
  const BeninfoodPageScaffold({
    super.key,
    required this.body,
    this.title,
    this.api,
    this.audience = NotificationAudience.client,
    this.onMenu,
    this.actions = const [],
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  /// Contenu de la page (liste, formulaire, écran de détail…).
  final Widget body;

  /// Titre de page affiché sous l'en-tête (null : pas de titre).
  final String? title;

  /// API de la cloche de notification (null : en-tête sans cloche).
  final MarketplaceApi? api;

  /// Espace courant : oriente les notifications vers le bon écran.
  final NotificationAudience audience;

  /// Action du bouton de gauche. Par défaut : retour en arrière.
  final VoidCallback? onMenu;

  /// Actions de page affichées à gauche de la cloche (rafraîchir, favori…).
  final List<Widget> actions;

  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Column(
        children: [
          BeninfoodAppBar(
            onMenu: onMenu ?? () => Navigator.of(context).maybePop(),
            api: api,
            audience: audience,
            actions: actions,
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                6,
                AppDimens.pagePadding,
                14,
              ),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.6,
                ),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// En-tête uniforme des pages Béninfood (client, livreur et vendeur) :
/// bouton hamburger à gauche, marque Béninfood au centre, cloche de
/// notification à droite. La marque reste toujours parfaitement centrée,
/// quels que soient les boutons latéraux.
class BeninfoodAppBar extends StatelessWidget {
  const BeninfoodAppBar({
    super.key,
    this.onMenu,
    this.api,
    this.audience = NotificationAudience.client,
    this.leading,
    this.trailing,
    this.actions = const [],
    this.tooltip = 'Ouvrir le menu',
    this.backgroundColor = Colors.white,
    this.height = 56,
  });

  /// Ouvre le tiroir latéral. Si null, un espace (44px) le remplace
  /// afin de conserver le centrage de la marque.
  final VoidCallback? onMenu;

  /// API pour la cloche de notification. Si null et [trailing] est null,
  /// aucun élément n'est affiché à droite.
  final MarketplaceApi? api;

  /// Espace courant : oriente les notifications ouvertes depuis la cloche
  /// vers le bon écran (client, vendeur, livreur).
  final NotificationAudience audience;

  /// Remplace le bouton hamburger (ex. bouton retour).
  final Widget? leading;

  /// Remplace l'action de droite (ex. cloche ou spinner de photo).
  final Widget? trailing;

  /// Actions de page affichées à gauche de la cloche (rafraîchir, favori…).
  final List<Widget> actions;

  final String tooltip;
  final Color backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final leading = onMenu != null
        ? IconButton(
            onPressed: onMenu,
            tooltip: tooltip,
            icon: const Icon(Icons.menu, size: 26, color: AppColors.text),
          )
        : const SizedBox(width: 44);
    final trailing = this.trailing ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...actions,
            if (api != null)
              NotificationBell(api: api!, audience: audience)
            else
              const SizedBox(width: 44),
          ],
        );

    return Material(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Center(child: this.leading ?? leading),
              ),
              const Center(child: BeninfoodBrand()),
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(child: this.trailing ?? trailing),
              ),
            ],
          ),
        ),
      ),
    );
  }
}