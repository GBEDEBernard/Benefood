import 'package:flutter/material.dart';

import '../restaurant_palette.dart';

/// Barre d'édition commune aux écrans « Ma boutique » : retour, titre et
/// bouton Enregistrer avec indicateur de chargement.
class ShopEditorAppBar extends StatelessWidget {
  const ShopEditorAppBar({super.key, required this.title, required this.onSave, required this.saving});

  final String title;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RestaurantPalette.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: RestaurantPalette.darkText),
                tooltip: 'Retour',
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: RestaurantPalette.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titre de section dans les formulaires d'édition de la boutique.
class ShopEditLabel extends StatelessWidget {
  const ShopEditLabel(this.label, {super.key, this.helper});

  final String label;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: RestaurantPalette.darkText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 2),
          Text(
            helper!,
            style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 12),
          ),
        ],
      ],
    );
  }
}