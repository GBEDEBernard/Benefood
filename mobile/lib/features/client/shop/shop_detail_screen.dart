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
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/product_review_sheet.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../presentation/client_shell.dart';

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

  final Set<String> _favoriteIds = <String>{};

  final Map<String, int> _likeDelta = <String, int>{};

  final Map<String, ProductReviewResult> _reviewResults =
      <String, ProductReviewResult>{};

  @override
  void initState() {
    super.initState();
    _future = widget.marketplace.vendor(widget.vendorId);
    _refreshCart();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await widget.marketplace.myFavorites();
      if (!mounted) {
        return;
      }
      setState(() {
        _favoriteIds
          ..clear()
          ..addAll(
            favorites
                .map((f) => f['product_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty),
          );
      });
    } catch (_) {
      return;
    }
  }

  bool _isLiked(String productId) => _favoriteIds.contains(productId);

  int _likesFor(Product product) =>
      (product.likesCount ?? 0) + (_likeDelta[product.id] ?? 0);

  double? _ratingFor(Product product) =>
      _reviewResults[product.id]?.rating ?? product.rating;

  int _reviewsFor(Product product) =>
      _reviewResults[product.id]?.reviewsCount ?? (product.reviewsCount ?? 0);

  Future<void> _toggleLike(Product product) async {
    final wasLiked = _isLiked(product.id);
    setState(() {
      if (wasLiked) {
        _favoriteIds.remove(product.id);
      } else {
        _favoriteIds.add(product.id);
      }
      _bumpLikes(product, wasLiked ? -1 : 1);
    });

    try {
      if (wasLiked) {
        await widget.marketplace.removeFavorite(product.id);
      } else {
        await widget.marketplace.addFavorite(product.id);
      }
      if (mounted && !wasLiked) {
        showToast(context, 'Ajouté à vos favoris');
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (wasLiked) {
          _favoriteIds.add(product.id);
        } else {
          _favoriteIds.remove(product.id);
        }
        _bumpLikes(product, wasLiked ? 1 : -1);
      });
      showToast(context, e.message, isError: true);
    }
  }

  void _bumpLikes(Product product, int delta) {
    _likeDelta[product.id] = (_likeDelta[product.id] ?? 0) + delta;
  }

  Future<void> _openReviewSheet(Product product) async {
    final input = await showProductReviewSheet(
      context,
      productName: product.name,
    );
    if (input == null || !mounted) {
      return;
    }
    try {
      final result = await widget.marketplace.submitProductReview(
        product.id,
        rating: input.rating,
        comment: input.comment,
      );
      if (!mounted) {
        return;
      }
      setState(() => _reviewResults[product.id] = result);
      showToast(context, 'Merci pour votre avis !');
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    }
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

  void _openCart() {
    ClientNavigation.openTab(context, 2);
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
      body: Column(
        children: [
          BeninfoodAppBar(onMenu: () => context.pop(), api: widget.marketplace),
          Expanded(
            child: FutureBuilder<ShopDetail>(
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
          ),
        ],
      ),
      bottomNavigationBar: _CartBar(cart: _cart, onTap: _openCart),
    );
  }

  Widget _buildContent(ShopDetail detail) {
    final vendor = detail.vendor;
    final products = detail.products.where((p) => p.isOrderable).toList()
      ..sort((a, b) {
        final ratingA = _ratingFor(a) ?? -1;
        final ratingB = _ratingFor(b) ?? -1;
        if (ratingA != ratingB) {
          return ratingB.compareTo(ratingA);
        }
        final reviewsA = _reviewsFor(a);
        final reviewsB = _reviewsFor(b);
        if (reviewsA != reviewsB) {
          return reviewsB.compareTo(reviewsA);
        }
        final likesA = _likesFor(a);
        final likesB = _likesFor(b);
        if (likesA != likesB) {
          return likesB.compareTo(likesA);
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

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
                  child: _CoverHeader(vendor: vendor),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: _coverHeight - 24),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
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
                  dishes: [
                    for (final p in products)
                      _DishFeedback(
                        product: p,
                        liked: _isLiked(p.id),
                        likes: _likesFor(p),
                        rating: _ratingFor(p),
                        reviews: _reviewsFor(p),
                      ),
                  ],
                  onTap: (p) => context.push('/client/product/${p.id}'),
                  onAdd: _addToCart,
                  onToggleLike: _toggleLike,
                  onReview: _openReviewSheet,
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
  const _CoverHeader({required this.vendor});

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppNetworkImage(url: vendor.coverUrl, icon: Icons.storefront),
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
        ],
      ),
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
      chips.add(
        Row(
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
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (vendor.etaLabel != null) {
      chips.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule,
              size: 17,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 3),
            Text(
              vendor.etaLabel!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    for (var i = 0; i < chips.length; i++) {
      if (i > 0) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '•',
              style: TextStyle(color: AppColors.textFaint, fontSize: 14),
            ),
          ),
        );
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
                    color: i == selected
                        ? AppColors.orange
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == selected ? Colors.white : AppColors.text,
                      fontWeight: i == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
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

class _DishFeedback {
  const _DishFeedback({
    required this.product,
    required this.liked,
    required this.likes,
    required this.rating,
    required this.reviews,
  });

  final Product product;
  final bool liked;
  final int likes;
  final double? rating;
  final int reviews;
}

class _PlatsTab extends StatelessWidget {
  const _PlatsTab({
    required this.dishes,
    required this.onTap,
    required this.onAdd,
    required this.onToggleLike,
    required this.onReview,
  });

  final List<_DishFeedback> dishes;
  final ValueChanged<Product> onTap;
  final ValueChanged<Product> onAdd;
  final ValueChanged<Product> onToggleLike;
  final ValueChanged<Product> onReview;

  @override
  Widget build(BuildContext context) {
    if (dishes.isEmpty) {
      return const EmptyState(
        icon: Icons.fastfood_outlined,
        title: 'Aucun plat disponible pour le moment',
      );
    }
    return Column(
      children: [
        for (final dish in dishes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DishCard(
              dish: dish,
              onTap: () => onTap(dish.product),
              onAdd: () => onAdd(dish.product),
              onToggleLike: () => onToggleLike(dish.product),
              onReview: () => onReview(dish.product),
            ),
          ),
      ],
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({
    required this.dish,
    required this.onTap,
    required this.onAdd,
    required this.onToggleLike,
    required this.onReview,
  });

  final _DishFeedback dish;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onToggleLike;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final product = dish.product;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: AppNetworkImage(
                    url: product.displayImageUrl,
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
                    else
                      const Text(
                        'Rupture de stock',
                        style: TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _RatingChip(
                          rating: dish.rating,
                          reviews: dish.reviews,
                          onTap: onReview,
                        ),
                        _LikeChip(
                          liked: dish.liked,
                          likes: dish.likes,
                          onTap: onToggleLike,
                        ),
                      ],
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

class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.rating,
    required this.reviews,
    required this.onTap,
  });

  final double? rating;
  final int reviews;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = rating;
    final label = value != null
        ? '${value.toStringAsFixed(1).replaceAll('.', ',')} ($reviews)'
        : 'Noter';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.goldLight,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 14, color: AppColors.goldDark),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.goldDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeChip extends StatelessWidget {
  const _LikeChip({
    required this.liked,
    required this.likes,
    required this.onTap,
  });

  final bool liked;
  final int likes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = liked ? AppColors.red : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: liked ? AppColors.redLight : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              '$likes',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
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
                const Icon(Icons.star_rounded, color: AppColors.gold, size: 36),
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
                  vendor.isOpenResolved
                      ? 'Ouvert maintenant'
                      : 'Fermé actuellement',
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
                  _CoordinateRow(
                    icon: Icons.phone_outlined,
                    text: vendor.phone!,
                  ),
              ],
            ),
          ),
        if (hours.isNotEmpty)
          _InfoBlock(
            title: 'Horaires',
            child: _HoursList(hours: hours),
          ),
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
                h.isClosed
                    ? 'Fermé'
                    : '${h.opensAt ?? ''} – ${h.closesAt ?? ''}',
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
