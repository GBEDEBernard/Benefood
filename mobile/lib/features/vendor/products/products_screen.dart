import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../restaurant/restaurant_palette.dart';
import 'product_form_screen.dart';

/// Actions du menu contextuel d'une carte produit.
enum _ProductAction { edit, archive, delete }

/// Mes produits (J155) : liste dynamique avec recherche, onglets Tous/Archives,
/// bascule d'activité (Actif/Inactif), archivage, suppression et ajout.
///
/// En démonstration (`marketplace == null`) un jeu de données local pilote
/// l'écran ; en réel les produits viennent de `vendorProducts()`.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, this.marketplace, this.onOpenDrawer});

  /// API vendeur en mode réel ; `null` = mode démonstration.
  final MarketplaceApi? marketplace;

  /// Ouvre le tiroir latéral du shell vendeur (hamburger).
  final VoidCallback? onOpenDrawer;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  String? _busyId;
  String _query = '';
  bool _archived = false;

  bool get _demoMode => widget.marketplace == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_demoMode) {
      setState(() {
        _products = _demoProducts();
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await widget.marketplace!.vendorProducts();
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

  /// Produits de l'onglet courant, filtrés par la recherche.
  List<Product> get _visible {
    final query = _query.trim().toLowerCase();
    return _products.where((p) {
      final matchesTab = _archived ? p.archived : !p.archived;
      if (!matchesTab) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return p.name.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _toggleAvailability(Product product) async {
    setState(() => _busyId = product.id);
    try {
      final target = !product.isAvailable;
      if (_demoMode) {
        _replaceLocal(product.copyWith(isAvailable: target));
      } else {
        final updated = await widget.marketplace!.updateProduct(
          product.id,
          isAvailable: target,
        );
        if (mounted) {
          setState(() => _replaceLocal(updated));
        }
      }
      if (mounted) {
        showToast(context, target ? 'Produit disponible' : 'Produit masqué');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<void> _archive(Product product) async {
    final target = !product.archived;
    setState(() => _busyId = product.id);
    try {
      if (!_demoMode) {
        await widget.marketplace!.updateProduct(
          product.id,
          isActive: target,
        );
      }
      if (mounted) {
        setState(() {
          _replaceLocal(
            product.copyWith(
              isActive: target,
              status: target ? 'archived' : 'active',
            ),
          );
        });
        showToast(context, target ? 'Produit archivé' : 'Produit restauré');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<void> _delete(Product product) async {
    setState(() => _busyId = product.id);
    try {
      if (!_demoMode) {
        await widget.marketplace!.deleteProduct(product.id);
      }
      if (mounted) {
        setState(() => _products.removeWhere((p) => p.id == product.id));
        showToast(context, 'Produit supprimé');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  void _replaceLocal(Product updated) {
    final index = _products.indexWhere((p) => p.id == updated.id);
    if (index >= 0) {
      _products[index] = updated;
    }
  }

  Future<void> _openForm([Product? product]) async {
    if (_demoMode) {
      showToast(context, 'Formulaire produit bientôt disponible.');
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            ProductFormScreen(marketplace: widget.marketplace!, product: product),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  void _runAction(Product product, _ProductAction action) {
    switch (action) {
      case _ProductAction.edit:
        _openForm(product);
      case _ProductAction.archive:
        _archive(product);
      case _ProductAction.delete:
        _delete(product);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RestaurantPalette.background,
      appBar: AppBar(
        backgroundColor: RestaurantPalette.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 56,
        leading: widget.onOpenDrawer == null
            ? null
            : IconButton(
                icon: Icon(Icons.menu, color: RestaurantPalette.darkText),
                tooltip: 'Menu',
                onPressed: widget.onOpenDrawer,
              ),
        title: Text(
          'Mes produits',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: RestaurantPalette.darkText,
          ),
        ),
        centerTitle: true,
        actions: [
          _NotificationBell(demoMode: _demoMode),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: RestaurantPalette.orange,
        foregroundColor: RestaurantPalette.white,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Ajouter un produit',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && !_demoMode) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchRow(),
        _buildTabs(),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: RestaurantPalette.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: RestaurantPalette.borderColor),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit...',
                  hintStyle: const TextStyle(
                    color: RestaurantPalette.grayText,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: RestaurantPalette.grayText,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: RestaurantPalette.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RestaurantPalette.borderColor),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.tune,
                color: RestaurantPalette.darkText,
                size: 20,
              ),
              tooltip: 'Filtres',
              onPressed: () =>
                  showToast(context, 'Filtres bientôt disponibles.'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final all = _products.length;
    final archived = _products.where((p) => p.archived).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: 'Tous ($all)',
              selected: !_archived,
              onTap: () => setState(() => _archived = false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TabChip(
              label: 'Archives ($archived)',
              selected: _archived,
              onTap: () => setState(() => _archived = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final items = _visible;
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: _archived ? 'Aucun produit archivé' : 'Aucun produit',
        subtitle: _archived
            ? 'Les produits archivés apparaîtront ici.'
            : 'Ajoutez votre premier produit pour commencer à vendre.',
        actionLabel: _archived ? null : 'Ajouter un produit',
        onAction: _archived ? null : () => _openForm(),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final product = items[index];
          return _ProductCard(
            product: product,
            busy: _busyId == product.id,
            onToggle: () => _toggleAvailability(product),
            onMenu: (action) => _runAction(product, action),
            onTap: () => _openForm(product),
          );
        },
      ),
    );
  }
}

/// Jeu de données de démonstration (fiches du spec « Mes produits »).
List<Product> _demoProducts() => [
      _demo(1, 'Akassa sauce arachide', 1200, 'portion', 35, rating: 4.6, reviews: 18, likes: 32),
      _demo(2, 'Poulet braisé (demi)', 3500, 'portion', 12, rating: 4.8, reviews: 24, likes: 41),
      _demo(3, 'Attiéké poisson', 2500, 'portion', 20, rating: 4.5, reviews: 15, likes: 27),
      _demo(4, 'Aloko poisson', 2000, 'portion', 18, rating: 4.7, reviews: 21, likes: 36),
      _demo(5, 'Burger boeuf', 2000, 'unité', 8, rating: 4.3, reviews: 9, likes: 15),
      _demo(6, 'Pizza royale', 5000, 'pièce', 6, rating: 4.4, reviews: 12, likes: 19),
      _demo(7, 'Jus de bissap', 500, 'verre', 40, rating: 4.9, reviews: 30, likes: 52),
      _demo(8, 'Salade complète', 1500, 'portion', 0, archived: true),
      _demo(9, 'Glace artisanale', 1000, 'boule', 0, archived: true),
    ];

Product _demo(
  int index,
  String name,
  int price,
  String unit,
  int stock, {
  double? rating,
  int? reviews,
  int? likes,
  bool archived = false,
}) {
  return Product(
    id: 'demo_p$index',
    vendorId: 'demo',
    categoryId: 'demo',
    name: name,
    price: price,
    currency: 'XOF',
    unit: unit,
    stockQty: stock,
    isAvailable: true,
    isActive: !archived,
    status: archived ? 'archived' : 'active',
    rating: rating,
    reviewsCount: reviews,
    likesCount: likes,
  );
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? RestaurantPalette.orange : RestaurantPalette.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? RestaurantPalette.orange
                : RestaurantPalette.borderColor,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected
                  ? RestaurantPalette.white
                  : RestaurantPalette.darkText,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.demoMode});

  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: RestaurantPalette.darkText,
            ),
            tooltip: 'Notifications',
            onPressed: () =>
                showToast(context, 'Aucune notification pour le moment.'),
          ),
          if (demoMode)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: RestaurantPalette.danger,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  '3',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: RestaurantPalette.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.busy,
    required this.onToggle,
    required this.onMenu,
    required this.onTap,
  });

  final Product product;
  final bool busy;
  final VoidCallback onToggle;
  final ValueChanged<_ProductAction> onMenu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: RestaurantPalette.cardSpacing),
      padding: const EdgeInsets.all(10),
      decoration: RestaurantPalette.cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: AppNetworkImage(
                url: product.imageUrl,
                icon: Icons.fastfood_outlined,
                iconColor: RestaurantPalette.orange,
                iconBackground: const Color(0xFFFFEDD5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _ProductInfo(product: product)),
          const SizedBox(width: 8),
          _ControlColumn(
            product: product,
            busy: busy,
            onToggle: onToggle,
            onMenu: onMenu,
          ),
        ],
      ),
    );
  }
}

class _ProductInfo extends StatelessWidget {
  const _ProductInfo({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: RestaurantPalette.darkText,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Flexible(
              child: AmountText(
                product.price,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: RestaurantPalette.orange,
                ),
              ),
            ),
            if (product.unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  product.unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: RestaurantPalette.grayText,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (product.stockQty != null) ...[
          const SizedBox(height: 2),
          Text(
            'Stock : ${product.stockQty}',
            style: const TextStyle(
              fontSize: 12,
              color: RestaurantPalette.grayText,
            ),
          ),
        ],
        _StatsRow(product: product),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final likes = product.likesCount ?? 0;
    final hasStats = product.rating != null || likes > 0;
    if (!hasStats) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (product.rating != null) ...[
            const Icon(
              Icons.star_rounded,
              size: 14,
              color: Color(0xFFFBBF24),
            ),
            Text(
              product.rating!.toStringAsFixed(1).replaceFirst('.', ','),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: RestaurantPalette.grayText,
              ),
            ),
            if (product.reviewsCount != null)
              Text(
                '(${product.reviewsCount} avis)',
                style: const TextStyle(
                  fontSize: 11,
                  color: RestaurantPalette.grayText,
                ),
              ),
          ],
          if (likes > 0) ...[
            const Text(
              '·',
              style: TextStyle(
                fontSize: 11,
                color: RestaurantPalette.grayText,
              ),
            ),
            const Icon(
              Icons.favorite,
              size: 13,
              color: RestaurantPalette.danger,
            ),
            Text(
              '$likes',
              style: const TextStyle(
                fontSize: 11,
                color: RestaurantPalette.grayText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlColumn extends StatelessWidget {
  const _ControlColumn({
    required this.product,
    required this.busy,
    required this.onToggle,
    required this.onMenu,
  });

  final Product product;
  final bool busy;
  final VoidCallback onToggle;
  final ValueChanged<_ProductAction> onMenu;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            PopupMenuButton<_ProductAction>(
              tooltip: 'Actions du produit',
              enabled: !busy,
              padding: EdgeInsets.zero,
              iconSize: 18,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 24),
              icon: Icon(
                Icons.more_vert,
                color: RestaurantPalette.grayText,
              ),
              color: RestaurantPalette.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: onMenu,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _ProductAction.edit,
                  child: _MenuRow(
                    icon: Icons.edit_outlined,
                    label: 'Modifier',
                  ),
                ),
                PopupMenuItem(
                  value: _ProductAction.archive,
                  child: _MenuRow(
                    icon: product.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    label: product.archived ? 'Restaurer' : 'Archiver',
                  ),
                ),
                const PopupMenuItem(
                  value: _ProductAction.delete,
                  child: _MenuRow(
                    icon: Icons.delete_outline,
                    label: 'Supprimer',
                    destructive: true,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          _AvailabilityLine(
            label: 'Actif',
            value: product.isAvailable,
            color: RestaurantPalette.success,
            enabled: !busy,
            onTap: onToggle,
          ),
          const SizedBox(height: 6),
          _AvailabilityLine(
            label: 'Inactif',
            value: !product.isAvailable,
            color: const Color(0xFF9CA3AF),
            enabled: !busy,
            onTap: onToggle,
          ),
        ],
      ),
    );
  }
}

class _AvailabilityLine extends StatelessWidget {
  const _AvailabilityLine({
    required this.label,
    required this.value,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool value;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 44,
          height: 36,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Switch(
              value: value,
              activeThumbColor: color,
              onChanged: enabled ? (_) => onTap() : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: RestaurantPalette.grayText),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: destructive
                ? RestaurantPalette.danger
                : RestaurantPalette.darkText,
          ),
        ),
      ],
    );
  }
}