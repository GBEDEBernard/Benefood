import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'app_network_image.dart';

/// Tuile produit avec photo : utilisée dans les colis livreur, les articles
/// de commande client/vendeur et les récapitulatifs.
class PackageItemTile extends StatelessWidget {
  const PackageItemTile({
    super.key,
    required this.name,
    required this.quantity,
    this.imageUrl,
    this.trailing,
    this.dense = false,
  });

  final String name;
  final int quantity;
  final String? imageUrl;

  /// Montant ou info complémentaire à droite.
  final String? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final thumbSize = dense ? 44.0 : 52.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: thumbSize,
            height: thumbSize,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? AppNetworkImage(url: imageUrl, icon: Icons.fastfood_outlined)
                : const Icon(Icons.fastfood_outlined, color: AppColors.textFaint, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$quantity×',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.orangeDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Carte « Contenu du colis » pour le livreur : photos + quantités du colis
/// à collecter et livrer.
class PackageContentCard extends StatelessWidget {
  const PackageContentCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.goldDark),
              ),
              const SizedBox(width: 10),
              const Text(
                'Contenu du colis',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
