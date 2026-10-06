import 'package:flutter/material.dart';

import '../models/product.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'amount_widgets.dart';
import 'app_network_image.dart';

/// Carte produit "grille" (2 colonnes) — image, badge, nom, boutique, prix, ajout.
class ProductCardGrid extends StatelessWidget {
  const ProductCardGrid({
    super.key,
    required this.product,
    required this.onTap,
    this.onAdd,
    this.compact = false,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(url: product.imageUrl, icon: Icons.fastfood_outlined),
                  if (!product.isOrderable || product.isOutOfStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                        ),
                        child: Text(
                          product.isOutOfStock ? 'Rupture' : 'Indisponible',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (product.vendorName != null && !compact) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.vendorName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 3),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AmountText(
                          product.price,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (onAdd != null)
                        InkWell(
                          onTap: product.isOrderable && !product.isOutOfStock ? onAdd : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 20),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte produit horizontale (listes de recherche / boutique).
class ProductListCard extends StatelessWidget {
  const ProductListCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAdd,
    this.dense = false,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: dense ? 56 : 68,
                  height: dense ? 56 : 68,
                  child: AppNetworkImage(url: product.imageUrl, icon: Icons.fastfood_outlined),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (product.vendorName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.vendorName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 6),
                    AmountText(
                      product.price,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (onAdd != null)
                onAddButton(product, onAdd!)
              else if (!product.isOrderable && !product.isOutOfStock)
                const Icon(Icons.cancel, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget onAddButton(Product p, VoidCallback onAdd) {
    final enabled = p.isOrderable && !p.isOutOfStock;
    return InkWell(
      onTap: enabled ? onAdd : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? AppColors.orange : AppColors.textSecondary.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 19),
      ),
    );
  }
}

/// Grille 2 colonnes réactive de cartes produit.
class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    required this.onTap,
    this.onAdd,
    this.shrinkWrap = false,
    this.padding,
  });

  final List<Product> products;
  final ValueChanged<Product> onTap;
  final ValueChanged<Product>? onAdd;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCardGrid(
          product: product,
          onTap: () => onTap(product),
          onAdd: onAdd == null ? null : () => onAdd!(product),
        );
      },
    );
  }
}