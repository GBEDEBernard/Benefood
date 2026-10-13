import 'package:flutter/material.dart';

import '../../core/data/marketplace_api.dart';
import '../../core/theme/app_colors.dart';
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

/// En-tête uniforme des pages Béninfood (client, livreur et vendeur) :
/// bouton hamburger à gauche, marque Béninfood au centre, cloche de
/// notification à droite. La marque reste toujours parfaitement centrée,
/// quels que soient les boutons latéraux.
class BeninfoodAppBar extends StatelessWidget {
  const BeninfoodAppBar({
    super.key,
    this.onMenu,
    this.api,
    this.leading,
    this.trailing,
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

  /// Remplace le bouton hamburger (ex. bouton retour).
  final Widget? leading;

  /// Remplace l'action de droite (ex. cloche ou spinner de photo).
  final Widget? trailing;

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
    final trailing = api != null
        ? NotificationBell(api: api!)
        : const SizedBox(width: 44);

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