import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/cart.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/feedback_widgets.dart';
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
        setState(() => _busyItems.remove(item.id));
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _remove(CartItem item, {bool silent = false}) async {
    setState(() => _busyItems.add(item.id));
    try {
      final cart = await widget.marketplace.removeCartItem(item.id);
      if (mounted) {
        setState(() {
          _cart = cart;
          _busyItems.remove(item.id);
        });
        if (!silent) {
          showToast(context, 'Produit retiré du panier');
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busyItems.remove(item.id));
        showToast(context, e.message, isError: true);
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
        actionLabel: 'Explorer les boutiques',
        onAction: () => context.go('/client/search'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                if (cart.vendor != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _VendorHeader(vendor: cart.vendor!),
                  ),
                ...cart.items.map(
                  (item) => _CartItemTile(
                    item: item,
                    busy: _busyItems.contains(item.id),
                    onQuantityChanged: (q) => _update(item, q),
                    onRemove: () => _remove(item),
                  ),
                ),
              ],
            ),
          ),
        ),
        _CheckoutBar(cart: cart, onCheckout: () => context.push('/client/checkout')),
      ],
    );
  }
}

class _VendorHeader extends StatelessWidget {
  const _VendorHeader({required this.vendor});

  final CartVendor vendor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: AppNetworkImage(
              url: vendor.logoUrl,
              icon: Icons.storefront_outlined,
              iconColor: AppColors.orange,
              iconBackground: AppColors.orangeLight,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vendor.businessName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Text(
                'Commande chez ce vendeur',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.cart, required this.onCheckout});

  final Cart cart;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('Total', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                Text(
                  '${cart.itemsCount} article${cart.itemsCount > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  _formatAmount(cart.subtotal),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Commander',
              icon: Icons.shopping_bag_outlined,
              onPressed: onCheckout,
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(int value) {
    final parts = value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
    return '$parts FCFA';
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
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 68,
                height: 68,
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
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatAmount(product.unitPrice)}${product.unit != null ? ' / ${product.unit}' : ''}',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      QuantityStepper(
                        quantity: item.quantity,
                        min: 0,
                        onChanged: busy ? (_) {} : onQuantityChanged,
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          _formatAmount(item.subtotal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 4),
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
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
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

  String _formatAmount(int value) {
    final parts = value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
    return '$parts FCFA';
  }
}