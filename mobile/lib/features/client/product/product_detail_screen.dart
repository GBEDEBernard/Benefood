import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/quantity_stepper.dart';
import '../../../shared/widgets/state_widgets.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit ajouté au panier'), behavior: SnackBarBehavior.floating),
        );
        context.go('/client');
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
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
              message: snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Produit introuvable.',
              onRetry: () => setState(() => _future = widget.marketplace.product(widget.productId)),
            );
          }
          final product = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    SizedBox(
                      height: 260,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppNetworkImage(url: product.imageUrl),
                          if (!product.isOrderable)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                                child: const Text('Indisponible', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              ),
                              Text('${product.unit}', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatAmount(product.price),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                          ),
                          if (product.vendorName != null) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => context.push('/client/shop/${product.vendorId}'),
                              icon: const Icon(Icons.storefront_outlined, size: 18),
                              label: Text(product.vendorName!),
                            ),
                          ],
                          if (product.description != null && product.description!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text('Description', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 6),
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)],
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