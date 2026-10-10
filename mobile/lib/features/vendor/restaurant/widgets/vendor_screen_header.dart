import 'package:flutter/material.dart';

import '../restaurant_palette.dart';

/// En-tête commun des écrans du shell vendeur : bouton hamburger (ou marge),
/// titre en majuscules et action optionnelle à droite.
class VendorScreenHeader extends StatelessWidget {
  const VendorScreenHeader({
    super.key,
    required this.title,
    this.onOpenDrawer,
    this.trailing,
  });

  final String title;
  final VoidCallback? onOpenDrawer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RestaurantPalette.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 6, right: 12, top: 8, bottom: 10),
          child: Row(
            children: [
              if (onOpenDrawer != null)
                IconButton(
                  onPressed: onOpenDrawer,
                  icon: const Icon(Icons.menu, color: RestaurantPalette.darkText),
                  tooltip: 'Ouvrir le menu',
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RestaurantPalette.forest,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
