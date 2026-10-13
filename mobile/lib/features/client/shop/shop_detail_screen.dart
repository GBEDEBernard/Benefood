import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/cart.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/vendor.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Fiche boutique (J149) : couverture, infos, onglets (Plats / Avis / Infos)
/// et barre de panier flottante.
class ShopDetailScreen extends StatefulWidget {
  const ShopDetailScreen({
    super.key,
    required this.marketplace,
    required this.vendorId,
  });

  final MarketplaceApi marketplace;
  final String vendorId;

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  static const _tabs = ['Plats', 'Avis', 'Infos'];
  static const double _coverHeight = 260;

  late Future<ShopDetail> _future;
  Cart _cart = const Cart(id: '', items: [], subtotal: 0);
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = widget.marketplace.vendor(widget.vendorId);
    _refreshCart();
  }

  Future<void> _refreshCart() async {
    try {
      final cart = await widget.marketplace.cart();
      if (!mounted) {
        return;
      }
      setState(() {
        _cart = cart;
      });
    } catch (_) {
      // Panier indisponible : on garde l'état courant (barre masquée vide).
    }
  }

  Future<void> _reload() async {
    final future = widget.marketplace.vendor(widget.vendorId);
    setState(() {
      _future = future;
    });
    await _refreshCart();
  }

  void _openCheckout() {
    context.push('/client/checkout');
  }

  Future<void> _addToCart(Product product) async {
    try {
      final cart = await widget.marketplace.addToCart(product.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _cart = cart;
      });
      showToast(context, 'Ajouté au panier');
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      showToast(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      body: FutureBuilder<ShopDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ListSkeleton();
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : 'Boutique introuvable.',
              onRetry: () {
                final next = widget.marketplace.vendor(widget.vendorId);
                setState(() {
                  _future = next;
                });
              },
            );
          }
          return _buildContent(snapshot.data!);
        },
      ),
      bottomNavigationBar: _CartBar(cart: _cart, onTap: _openCheckout),
    );
  }

  Widget _buildContent(ShopDetail detail) {
    final vendor = detail.vendor;
    final products = detail.products.where((p) => p.isOrderable).toList();

          return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: _reload,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Couverture + carte d'infos qui remonte dessus (24 px).
            Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _coverHeight,
                  child: _CoverHeader(
                    vendor: vendor,
                    cart: _cart,
                    onBack: () => context.pop(),
                    onCartTap: _openCheckout,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: _coverHeight - 24),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor.businessName,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _VendorMetaRow(vendor: vendor),
                        const SizedBox(height: 16),
                        _TabBar(
                          labels: _tabs,
                          selected: _tabIndex,
                          onSelected: (index) => setState(() {
                            _tabIndex = index;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: switch (_tabIndex) {
                1 => _AvisTab(vendor: vendor),
                2 => _InfosTab(vendor: vendor, hours: detail.hours),
                _ => _PlatsTab(
                    products: products,
                    onTap: (p) => context.push('/client/product/${p.id}'),
                    onAdd: _addToCart,
                  ),
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _CoverHeader extends StatelessWidget {
  const _CoverHeader({
    required this.vendor,
    required this.cart,
    required this.onBack,
    required this.onCartTap,
  });

  final Vendor vendor;
  final Cart cart;
  final VoidCallback onBack;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppNetworkImage(
            url: vendor.coverUrl,
            icon: Icons.storefront,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x8A000000),
                  Color(0x3D000000),
                  Colors.transparent,
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back_ios_new,
                    tooltip: 'Retour',
                    onTap: onBack,
                  ),
                  const Spacer(),
                  _CartHeaderButton(cart: cart, onTap: onCartTap),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.38),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _CartHeaderButton extends StatelessWidget {
  const _CartHeaderButton({required this.cart, required this.onTap});

  final Cart cart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _RoundIconButton(
          icon: Icons.shopping_cart_outlined,
          tooltip: 'Panier',
          onTap: onTap,
        ),
        if (cart.itemsCount > 0)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                cart.itemsCount > 99 ? '99+' : '${cart.itemsCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VendorMetaRow extends StatelessWidget {
  const _VendorMetaRow({required this.vendor});

  final Vendor vendor;

  String _formatRating(double rating) =>
      rating.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (vendor.rating != null) {
      chips.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
          const SizedBox(width: 3),
          Text(
            _formatRating(vendor.rating!),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '(${vendor.reviewsCount} avis)',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ));
    }

    if (vendor.etaLabel != null) {
      chips.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(
            vendor.etaLabel!,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ));
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    for (var i = 0; i < chips.length; i++) {
      if (i > 0) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '•',
            style: TextStyle(color: AppColors.textFaint, fontSize: 14),
          ),
        ));
      }
      children.add(chips[i]);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? AppColors.orange : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == selected ? Colors.white : AppColors.text,
                      fontWeight:
                          i == selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlatsTab extends StatelessWidget {
  const _PlatsTab({
    required this.products,
    required this.onTap,
    required this.onAdd,
  });

  final List<Product> products;
  final ValueChanged<Product> onTap;
  final ValueChanged<Product> onAdd;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const EmptyState(
        icon: Icons.fastfood_outlined,
        title: 'Aucun plat disponible pour le moment',
      );
    }
    return Column(
      children: [
        for (final product in products)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DishCard(
              product: product,
              onTap: () => onTap(product),
              onAdd: () => onAdd(product),
            ),
          ),
      ],
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({
    required this.product,
    required this.onTap,
    required this.onAdd,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final canOrder = product.isOrderable && !product.isOutOfStock;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        boxShadow: AppTheme.softShadow(),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: AppNetworkImage(
                    url: product.imageMain ?? product.imageUrl,
                    icon: Icons.fastfood,
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (canOrder)
                      AmountText(
                        product.price,
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      )
                    else if (product.isOutOfStock)
                      const Text(
                        'Rupture de stock',
                        style: TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _AddButton(canOrder: canOrder, onAdd: onAdd),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.canOrder, required this.onAdd});

  final bool canOrder;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (!canOrder) {
      return Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: AppColors.textFaint, size: 20),
      );
    }
    return Ink(
      decoration: const BoxDecoration(
        color: AppColors.orange,
        shape: BoxShape.circle,
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onAdd,
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.add, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _AvisTab extends StatelessWidget {
  const _AvisTab({required this.vendor});

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    final rating = vendor.rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rating != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: AppColors.gold,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.toStringAsFixed(1).replaceAll('.', ','),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${vendor.reviewsCount} avis',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const EmptyState(
          icon: Icons.rate_review_outlined,
          title: 'Aucun avis à afficher pour le moment',
        ),
      ],
    );
  }
}

class _InfosTab extends StatelessWidget {
  const _InfosTab({required this.vendor, required this.hours});

  final Vendor vendor;
  final List<OpeningHour> hours;

  @override
  Widget build(BuildContext context) {
    final hasDescription =
        vendor.description != null && vendor.description!.isNotEmpty;
    final hasCoordinates =
        vendor.address != null || vendor.phone != null || vendor.city != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vendor.isOpen != null)
          _InfoBlock(
            title: 'Statut',
            child: Row(
              children: [
                Icon(
                  vendor.isOpenResolved
                      ? Icons.check_circle
                      : Icons.cancel_outlined,
                  size: 18,
                  color: vendor.isOpenResolved
                      ? AppColors.green
                      : AppColors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  vendor.isOpenResolved ? 'Ouvert maintenant' : 'Fermé actuellement',
                  style: TextStyle(
                    color: vendor.isOpenResolved
                        ? AppColors.green
                        : AppColors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        if (hasDescription)
          _InfoBlock(title: 'À propos', child: _InfoText(vendor.description!)),
        if (hasCoordinates)
          _InfoBlock(
            title: 'Coordonnées',
            child: Column(
              children: [
                if (vendor.address != null && vendor.address!.isNotEmpty)
                  _CoordinateRow(
                    icon: Icons.place_outlined,
                    text: vendor.address!,
                  ),
                if (vendor.city != null && vendor.city!.isNotEmpty)
                  _CoordinateRow(icon: Icons.location_city, text: vendor.city!),
                if (vendor.phone != null && vendor.phone!.isNotEmpty)
                  _CoordinateRow(icon: Icons.phone_outlined, text: vendor.phone!),
              ],
            ),
          ),
        if (hours.isNotEmpty)
          _InfoBlock(title: 'Horaires', child: _HoursList(hours: hours)),
      ],
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        height: 1.45,
      ),
    );
  }
}

class _CoordinateRow extends StatelessWidget {
  const _CoordinateRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursList extends StatelessWidget {
  const _HoursList({required this.hours});

  final List<OpeningHour> hours;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: hours.map((h) {
        final isToday = _isToday(h.dayOfWeek);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(
                _dayName(h.dayOfWeek),
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? AppColors.green : AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                h.isClosed ? 'Fermé' : '${h.opensAt ?? ''} – ${h.closesAt ?? ''}',
                style: TextStyle(
                  color: h.isClosed
                      ? AppColors.textSecondary
                      : (isToday ? AppColors.green : AppColors.text),
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  bool _isToday(int dayOfWeek) {
    final today = DateTime.now().weekday; // 1 = lundi
    const mapping = [1, 2, 3, 4, 5, 6, 7]; // lundi..dimanche
    return mapping[(today - 1 + 7) % 7] == dayOfWeek;
  }

  String _dayName(int day) {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    return days[day.clamp(0, 6)];
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.cart, required this.onTap});

  final Cart cart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.orange,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: InkWell(
            onTap: onTap,
            child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Voir le panier',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cart.itemsCount} ${cart.itemsCount > 1 ? 'articles' : 'article'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              AmountText(
                cart.subtotal,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.white, size: 22),
            ],
          ),
          ),
        ),
      ),
    );
  }
}