import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/product_promotion.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import 'promotion_form_screen.dart';

/// Liste des promotions du vendeur connecté.
///
/// Chaque carte résume l'offre (ancien prix, prix promo, remise, période) et
/// permet de la modifier, de la mettre en pause ou de la supprimer.
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  late Future<_PromotionsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PromotionsData> _load() async {
    final results = await Future.wait<Object>([
      widget.marketplace.vendorProducts(),
      widget.marketplace.vendorPromotions(),
    ]);
    return _PromotionsData(
      products: results[0] as List<Product>,
      promotions: results[1] as List<ProductPromotion>,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _openForm(
    List<Product> products, {
    ProductPromotion? promotion,
  }) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PromotionFormScreen(
          marketplace: widget.marketplace,
          products: products,
          promotion: promotion,
        ),
      ),
    );
    if (created == true && mounted) {
      _reload();
    }
  }

  Future<void> _toggle(ProductPromotion promotion) async {
    try {
      await widget.marketplace.togglePromotion(promotion.id);
      if (!mounted) {
        return;
      }
      _reload();
      showToast(
        context,
        promotion.isActive ? 'Promotion mise en pause.' : 'Promotion activée.',
      );
    } on ApiException catch (error) {
      if (mounted) {
        showToast(context, error.message, isError: true);
      }
    }
  }

  Future<void> _delete(ProductPromotion promotion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la promotion ?'),
        content: Text(
          'L’offre « ${promotion.title ?? promotion.productName ?? 'sans titre'} » '
          'ne sera plus visible par les clients.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.marketplace.deletePromotion(promotion.id);
      if (!mounted) {
        return;
      }
      _reload();
      showToast(context, 'Promotion supprimée.');
    } on ApiException catch (error) {
      if (mounted) {
        showToast(context, error.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BeninfoodPageScaffold(
      title: 'Mes promotions',
      api: widget.marketplace,
      audience: NotificationAudience.vendor,
      floatingActionButton: FutureBuilder<_PromotionsData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.products.isEmpty) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => _openForm(snapshot.data!.products),
            icon: const Icon(Icons.add),
            label: const Text('Créer une promo'),
          );
        },
      ),
      body: SafeArea(
        child: FutureBuilder<_PromotionsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorState(
                message: snapshot.error is ApiException
                    ? (snapshot.error as ApiException).message
                    : 'Impossible de charger les promotions.',
                onRetry: _reload,
              );
            }

            final data = snapshot.data!;

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding,
                  4,
                  AppDimens.pagePadding,
                  96,
                ),
                children: [
                  _buildIntroCard(data.promotions.length),
                  const SizedBox(height: 18),
                  if (data.promotions.isEmpty)
                    EmptyState(
                      icon: Icons.local_offer_outlined,
                      title: 'Aucune promotion pour le moment',
                      subtitle: data.products.isEmpty
                          ? 'Ajoutez d’abord un produit pour créer une offre.'
                          : 'Créez une offre pour afficher un prix barré et attirer plus de clients.',
                      actionLabel: data.products.isEmpty ? null : 'Créer une promo',
                      onAction: data.products.isEmpty
                          ? null
                          : () => _openForm(data.products),
                    )
                  else
                    for (var i = 0; i < data.promotions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _PromotionCard(
                        promotion: data.promotions[i],
                        product: _findProduct(
                          data.products,
                          data.promotions[i].productId,
                        ),
                        onEdit: () => _openForm(
                          data.products,
                          promotion: data.promotions[i],
                        ),
                        onToggle: () => _toggle(data.promotions[i]),
                        onDelete: () => _delete(data.promotions[i]),
                      ),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntroCard(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.goldLight, AppColors.orangeLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vos offres, vos clients',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'Saisissez un pourcentage, choisissez un plat, '
                          'plusieurs ou toute la boutique : le prix promo '
                          'apparaît partout côté client.'
                      : '$count offre${count > 1 ? 's' : ''} configurée'
                          '${count > 1 ? 's' : ''} — le prix promo est appliqué '
                          'automatiquement au paiement.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Product? _findProduct(List<Product> products, String id) {
    for (final product in products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }
}

class _PromotionsData {
  const _PromotionsData({required this.products, required this.promotions});

  final List<Product> products;
  final List<ProductPromotion> promotions;
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({
    required this.promotion,
    required this.product,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final ProductPromotion promotion;
  final Product? product;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final active = promotion.isActive;
    final statusLabel = !active
        ? 'En pause'
        : promotion.isCurrentlyActive
            ? 'En cours'
            : 'Programmée';
    final statusColor = !active
        ? AppColors.textSecondary
        : promotion.isCurrentlyActive
            ? AppColors.green
            : AppColors.goldDark;
    final oldPrice = promotion.originalPrice > 0
        ? promotion.originalPrice
        : (product?.price ?? 0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  promotion.title?.trim().isNotEmpty == true
                      ? promotion.title!
                      : (promotion.productName ?? product?.name ?? 'Offre'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (product != null || promotion.productName != null) ...[
            const SizedBox(height: 4),
            Text(
              product?.name ?? promotion.productName!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                child: Text(
                  '−${promotion.displayedDiscountPercent} %',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.goldDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (oldPrice > 0)
                Text(
                  formatAmount(oldPrice),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textFaint,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                formatAmount(promotion.promoPrice),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 15,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_formatDate(promotion.startsAt)} → ${_formatDate(promotion.endsAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Modifier'),
              ),
              TextButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  active ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  size: 17,
                ),
                label: Text(active ? 'Pause' : 'Activer'),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Supprimer',
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) {
    return '—';
  }
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${date.day} ${months[date.month - 1]} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
