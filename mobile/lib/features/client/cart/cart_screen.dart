import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/models/cart.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/quantity_stepper.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Panier client (J150) : quantités, suppression, récapitulatif.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Cart? _cart;
  bool _loading = true;
  String? _error;
  final Set<String> _busyItems = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cart = await widget.marketplace.cart();
      if (mounted) {
        setState(() {
          _cart = cart;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _update(CartItem item, int quantity) async {
    if (quantity < 1) {
      await _remove(item);
      return;
    }
    setState(() => _busyItems.add(item.id));
    try {
      final cart = await widget.marketplace.updateCartItem(item.id, quantity);
      if (mounted) {
        setState(() {
          _cart = cart;
          _busyItems.remove(item.id);
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        _busyItems.remove(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _remove(CartItem item) async {
    setState(() => _busyItems.add(item.id));
    try {
      final cart = await widget.marketplace.removeCartItem(item.id);
      if (mounted) {
        setState(() {
          _cart = cart;
          _busyItems.remove(item.id);
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        _busyItems.remove(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon panier')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final cart = _cart;
    if (cart == null || cart.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Votre panier est vide',
        subtitle: 'Parcourez les boutiques pour ajouter des produits.',
        actionLabel: 'Explorer',
        onAction: () => context.go('/client/search'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (cart.vendor != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(cart.vendor!.businessName, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                ...cart.items.map((item) => _CartItemTile(
                      item: item,
                      busy: _busyItems.contains(item.id),
                      onQuantityChanged: (q) => _update(item, q),
                      onRemove: () => _remove(item),
                    )),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    AmountText(cart.subtotal, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Commander',
                  icon: Icons.shopping_bag_outlined,
                  onPressed: () => context.push('/client/checkout'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.busy,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final CartItem item;
  final bool busy;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: AppNetworkImage(url: product.imageUrl, icon: Icons.fastfood),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name ?? 'Produit',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  AmountText(product.unitPrice, style: Theme.of(context).textTheme.bodySmall),
                  if (product.unit != null)
                    Text(product.unit!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      QuantityStepper(
                        quantity: item.quantity,
                        min: 0,
                        onChanged: busy ? (_) {} : onQuantityChanged,
                      ),
                      const Spacer(),
                      if (busy)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Theme.of(context).colorScheme.error,
                          tooltip: 'Retirer',
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