import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';
import 'product_form_screen.dart';

/// Mes produits (J155) : liste, disponibilité, création et édition.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

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
      final products = await widget.marketplace.vendorProducts();
      if (mounted) {
        setState(() {
          _products = products;
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

  Future<void> _toggleAvailability(Product product) async {
    setState(() => _busyId = product.id);
    try {
      final updated = await widget.marketplace.updateProduct(
        product.id,
        isAvailable: !product.isAvailable,
      );
      if (mounted) {
        setState(() {
          final index = _products.indexWhere((p) => p.id == updated.id);
          if (index >= 0) {
            _products[index] = updated;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updated.isAvailable ? 'Produit disponible' : 'Produit masqué'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<void> _openForm([Product? product]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ProductFormScreen(marketplace: widget.marketplace, product: product),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes produits')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
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
    if (_products.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Aucun produit',
        subtitle: 'Ajoutez votre premier produit pour commencer à vendre.',
        actionLabel: 'Ajouter un produit',
        onAction: () => _openForm(),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return _ProductCard(
            product: product,
            busy: _busyId == product.id,
            onTap: () => _openForm(product),
            onToggle: () => _toggleAvailability(product),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.busy,
    required this.onTap,
    required this.onToggle,
  });

  final Product product;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 60, height: 60, child: AppNetworkImage(url: product.imageUrl)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        if (product.isOutOfStock)
                          StatusBadge(label: 'Rupture', color: Colors.red, small: true)
                        else if (!product.isAvailable)
                          StatusBadge(label: 'Masqué', color: Colors.grey, small: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AmountText(product.price, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (product.unit.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(product.unit, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                    if (product.stockQty != null) ...[
                      const SizedBox(height: 2),
                      Text('Stock : ${product.stockQty}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))
                  : Switch(
                      value: product.isAvailable,
                      onChanged: (_) => onToggle(),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}