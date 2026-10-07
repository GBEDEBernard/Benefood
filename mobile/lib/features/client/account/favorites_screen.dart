import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Favoris du client : produits enregistrés, retrait et ouverture fiche.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.marketplace.myFavorites();
  }

  void _reload() {
    final next = widget.marketplace.myFavorites();
    setState(() {
      _future = next;
    });
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    final productId = item['product_id'];
    if (productId is! String) {
      return;
    }
    setState(() {
      _future = _future.then((items) {
        final remaining = items
            .where((row) => row['product_id'] != productId)
            .toList();
        return remaining;
      });
    });
    try {
      await widget.marketplace.removeFavorite(productId);
      if (mounted) {
        showToast(context, 'Retiré des favoris');
      }
    } on ApiException catch (e) {
      _reload();
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mes favoris')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Impossible de charger vos favoris.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _reload,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.redLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border,
                        size: 36,
                        color: AppColors.red,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucun favori',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Touchez le cœur d’un produit dans le catalogue '
                      'pour l’ajouter ici.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final product = item['product'] is Map<String, dynamic>
                  ? item['product'] as Map<String, dynamic>
                  : null;
              if (product == null) {
                return const SizedBox.shrink();
              }
              final name = product['name'] is String
                  ? product['name'] as String
                  : '';
              final price = product['price'] is int
                  ? product['price'] as int
                  : 0;
              final imageUrl = product['image_url'] is String
                  ? product['image_url'] as String
                  : null;
              final vendorName = product['vendor_name'] is String
                  ? product['vendor_name'] as String
                  : '';

              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  boxShadow: AppTheme.softShadow(),
                ),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: () {
                      final id = product['id'];
                      if (id is String) {
                        context.push('/client/product/$id');
                      }
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    leading: SizedBox(
                      width: 56,
                      height: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        child: AppNetworkImage(
                          url: imageUrl,
                          icon: Icons.restaurant_outlined,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      [
                        formatAmount(price, showSymbol: false).trim(),
                        if (vendorName.isNotEmpty) vendorName,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Retirer des favoris',
                      onPressed: () => _remove(item),
                      icon: const Icon(Icons.favorite, color: AppColors.red),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
