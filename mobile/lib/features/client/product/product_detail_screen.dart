import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/quantity_stepper.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/status_badge.dart';

/// Fiche produit client (J148) : description, prix, quantité, ajout panier.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.marketplace, required this.productId});

  final MarketplaceApi marketplace;
  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<Product> _future;
  int _quantity = 1;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _future = widget.marketplace.product(widget.productId);
  }

  Future<void> _addToCart(Product product) async {
    setState(() => _adding = true);
    try {
      await widget.marketplace.addToCart(product.id, quantity: _quantity);
      if (mounted) {
        showToast(context, 'Produit ajouté au panier');
        context.go('/client');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produit')),
      body: FutureBuilder<Product>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : 'Produit introuvable.',
              onRetry: () => setState(() => _future = widget.marketplace.product(widget.productId)),
            );
          }
          final product = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 140),
                  children: [
                    // Visuel produit
                    Container(
                      margin: const EdgeInsets.all(AppDimens.pagePadding),
                      height: 260,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.softShadow(),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppNetworkImage(url: product.imageUrl, icon: Icons.fastfood_outlined),
                          if (!product.isOrderable || product.isOutOfStock)
                            Positioned(
                              top: 14,
                              right: 14,
                              child: StatusBadge(
                                label: product.isOutOfStock ? 'Rupture de stock' : 'Indisponible',
                                color: AppColors.red,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.goldLight,
                                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                                ),
                                child: Text(
                                  product.unit,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.goldDark),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            formatAmount(product.price),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.orange,
                            ),
                          ),
                          if (product.stockQty != null) ...[
                            const SizedBox(height: 10),
                            StatusBadge(
                              label: product.isOutOfStock
                                  ? 'Rupture de stock'
                                  : 'En stock (${product.stockQty})',
                              color: product.isOutOfStock
                                  ? AppColors.red
                                  : AppColors.success,
                              icon: product.isOutOfStock
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                            ),
                          ],
                          if (product.vendorName != null) ...[
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: () => context.push('/client/shop/${product.vendorId}'),
                              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.storefront_outlined,
                                        size: 18, color: AppColors.green),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        product.vendorName!,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (product.description != null && product.description!.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            Text('Description', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            Text(product.description!, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (product.isOrderable)
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        QuantityStepper(
                          quantity: _quantity,
                          onChanged: (v) => setState(() => _quantity = v),
                          max: product.stockQty ?? 99,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppButton(
                            label: 'Ajouter au panier',
                            icon: Icons.add_shopping_cart,
                            onPressed: () => _addToCart(product),
                            loading: _adding,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}