import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/product_promotion.dart';
import '../../../shared/models/vendor.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/product_cards.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Accueil client (J148) : en-tête blanc, recherche, bannière promotionnelle,
/// catégories, restaurants populaires et plats du jour.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.marketplace,
    required this.session,
    this.onOpenMenu,
    this.onCartChanged,
  });

  final MarketplaceApi marketplace;
  final SessionProvider session;

  /// Ouvre le tiroir latéral (menu hamburger) — géré par le shell client.
  final VoidCallback? onOpenMenu;

  /// Appelé après un ajout au panier (rafraîchit le badge du panier).
  final VoidCallback? onCartChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _future;

  /// Index de catégorie sélectionnée : 0 = « Tous », i ≥ 1 = categories[i - 1].
  int _categoryIndex = 0;
  final Set<String> _favoriteVendorIds = <String>{};

  /// Évite les rafraîchissements concurrents (tirages répétés du pull-refresh).
  bool _refreshing = false;

  /// Recherche dynamique (plats + boutiques) directement sur l'accueil.
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Product> _searchProducts = const [];
  List<Vendor> _searchVendors = const [];
  bool _searchRunning = false;

  @override
  void initState() {
    super.initState();
    _future = widget.marketplace.home();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = widget.marketplace.home();
      _categoryIndex = 0;
    });
  }

  /// Un seul rafraîchissement à la fois. Le `FutureBuilder` conserve toujours
  /// le même [_future] entre deux rebuilds, mais des tirages successifs ne
  /// doivent pas lancer plusieurs appels réseau concurrents.
  Future<void> _onRefresh() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    _reload();
    try {
      await _future;
    } finally {
      _refreshing = false;
    }
  }

  // ----------------------------------------------------- recherche dynamique

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _searchProducts = const [];
        _searchVendors = const [];
        _searchRunning = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) {
        return;
      }
      setState(() => _searchRunning = true);
      try {
        final products = await widget.marketplace.products(
          q: query,
          perPage: 8,
        );
        final vendors = await widget.marketplace.vendors(q: query, perPage: 6);
        if (!mounted) {
          return;
        }
        setState(() {
          _searchProducts = products;
          _searchVendors = vendors;
          _searchRunning = false;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _searchProducts = const [];
          _searchVendors = const [];
          _searchRunning = false;
        });
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _searchProducts = const [];
      _searchVendors = const [];
      _searchRunning = false;
    });
  }

  void _openVendor(Vendor vendor) {
    _clearSearch();
    context.push('/client/shop/${vendor.id}');
  }

  void _openProduct(Product product) {
    _clearSearch();
    context.push('/client/product/${product.id}');
  }

  bool get _searchActive =>
      _searchController.text.trim().isNotEmpty ||
      _searchRunning ||
      _searchProducts.isNotEmpty ||
      _searchVendors.isNotEmpty;

  Future<void> _addToCart(Product product) async {
    try {
      await widget.marketplace.addToCart(product.id);
      if (!mounted) {
        return;
      }
      showToast(context, 'Ajouté au panier');
      widget.onCartChanged?.call();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      showToast(context, e.message, isError: true);
    }
  }

  // ----------------------------------------------------------------- surcouches

  void _showFilters(List<Category> categories) {
    if (categories.isEmpty) {
      context.push('/client/search');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Filtrer par catégorie',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _categoryIndex == 0
                              ? AppColors.orange
                              : AppColors.orangeLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.room_service,
                          size: 22,
                          color: _categoryIndex == 0
                              ? AppColors.surface
                              : AppColors.orange,
                        ),
                      ),
                      title: Text(context.tr('Tous')),
                      trailing: _categoryIndex == 0
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.orange,
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        setState(() => _categoryIndex = 0);
                      },
                    ),
                    for (var i = 0; i < categories.length; i++)
                      ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _categoryIndex == i + 1
                                ? AppColors.orange
                                : AppColors.orangeLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            categoryIcon(categories[i].name),
                            size: 22,
                            color: _categoryIndex == i + 1
                                ? AppColors.surface
                                : AppColors.orange,
                          ),
                        ),
                        title: Text(categories[i].name),
                        trailing: _categoryIndex == i + 1
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.orange,
                              )
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() => _categoryIndex = i + 1);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------- interface

  /// Bloc blanc haut : barre de menu / logo / cloche, salutation et recherche.
  Widget _topSection({required List<Category> categories}) {
    final firstName = (widget.session.user?.name ?? '').trim().split(' ').first;
    final greeting = firstName.isEmpty || firstName == 'null'
        ? context.tr('Le goût du Bénin, livré chez vous')
        : context
              .tr('Bonjour, {name} 👋 Que mangerez-vous aujourd’hui ?')
              .replaceAll('{name}', firstName);

    return Material(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BeninfoodAppBar(onMenu: widget.onOpenMenu, api: widget.marketplace),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              6,
              AppDimens.pagePadding,
              0,
            ),
            child: Text(
              greeting,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              10,
              AppDimens.pagePadding,
              10,
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: AppSearchField(
                        controller: _searchController,
                        hintText: context.tr('Rechercher un plat, un resto...'),
                        onChanged: _onSearchChanged,
                        suffix: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: _clearSearch,
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _FilterButton(onPressed: () => _showFilters(categories)),
                  ],
                ),
                if (_searchActive)
                  _SearchOverlay(
                    running: _searchRunning,
                    query: _searchController.text.trim(),
                    products: _searchProducts,
                    vendors: _searchVendors,
                    onVendor: _openVendor,
                    onProduct: _openProduct,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: _onRefresh,
        child: FutureBuilder<HomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              // Un seul loader centré : l'ancien `ListSkeleton` construisait
              // six cartes, chacune avec son propre CircularProgressIndicator.
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _topSection(categories: const []),
                  const SizedBox(
                    height: 260,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ],
              );
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _topSection(categories: const []),
                  SizedBox(
                    height: 300,
                    child: ErrorState(
                      message: snapshot.error is ApiException
                          ? (snapshot.error as ApiException).message
                          : 'Impossible de charger l’accueil.',
                      onRetry: _reload,
                    ),
                  ),
                ],
              );
            }

            final data = snapshot.data!;

            final allProducts = data.featuredProducts;
            final selectedCategory =
                _categoryIndex > 0 && _categoryIndex <= data.categories.length
                ? data.categories[_categoryIndex - 1]
                : null;
            final products = selectedCategory == null
                ? allProducts
                : allProducts
                      .where(
                        (product) => product.categoryId == selectedCategory.id,
                      )
                      .toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _topSection(categories: data.categories),

                // --- Offres réelles créées par les vendeurs ---
                if (data.promotions.isNotEmpty) ...[
                  SectionHeader(
                    title: context.tr('Offres du moment'),
                    actionLabel: context.tr('Toutes les offres'),
                    onAction: () => context.push('/client/search?promo=1'),
                  ),
                  _PromoBanner(
                    promotions: data.promotions,
                    onOpen: (promotion) {
                      final productId = promotion.productId.isNotEmpty
                          ? promotion.productId
                          : promotion.product?.id ?? '';
                      if (productId.isNotEmpty) {
                        context.push('/client/product/$productId');
                      }
                    },
                  ),
                ],

                // --- Accès direct à la carte des boutiques ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.pagePadding,
                    4,
                    AppDimens.pagePadding,
                    0,
                  ),
                  child: _NearbyMapCard(
                    onTap: () => context.push('/client/shops/map'),
                  ),
                ),

                // --- Actions rapides par type de boutique ---
                _ShopTypeStrip(
                  onSelect: (type) =>
                      context.push('/client/shops?type=${type.apiValue}'),
                ),

                // --- Restaurants populaires ---
                if (data.vendors.isNotEmpty) ...[
                  SectionHeader(
                    title: context.tr('Boutiques les mieux notées'),
                    actionLabel: context.tr('Voir tout'),
                    onAction: () => context.push('/client/search'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.pagePadding,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < data.vendors.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _RestaurantCard(
                            vendor: data.vendors[i],
                            favorite: _favoriteVendorIds.contains(
                              data.vendors[i].id,
                            ),
                            onTap: () => context.push(
                              '/client/shop/${data.vendors[i].id}',
                            ),
                            onToggleFavorite: () => setState(() {
                              final id = data.vendors[i].id;
                              if (!_favoriteVendorIds.remove(id)) {
                                _favoriteVendorIds.add(id);
                              }
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // --- Plats du jour ---
                if (allProducts.isNotEmpty) ...[
                  SectionHeader(
                    title: context.tr('Plats du jour les mieux notés'),
                    actionLabel: context.tr('Voir tout'),
                    onAction: () => context.push('/client/search'),
                  ),
                  if (products.isNotEmpty)
                    ProductGrid(
                      products: products,
                      shrinkWrap: true,
                      onTap: (p) => context.push('/client/product/${p.id}'),
                      onAdd: _addToCart,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        context.tr(
                          'Aucun plat dans cette catégorie pour le moment.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],

                if (data.vendors.isEmpty && allProducts.isEmpty)
                  EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: context.tr('Aucune boutique pour le moment'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- promotions

/// Carrousel des offres réellement publiées par les vendeurs.
///
/// Chaque carte affiche la remise, l'ancien prix barré, le prix promo et un
/// accès direct à la fiche du produit.
class _PromoBanner extends StatefulWidget {
  const _PromoBanner({required this.promotions, required this.onOpen});

  final List<ProductPromotion> promotions;
  final ValueChanged<ProductPromotion> onOpen;

  @override
  State<_PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<_PromoBanner> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            itemCount: widget.promotions.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) =>
                _buildSlide(widget.promotions[index]),
          ),
        ),
        if (widget.promotions.length > 1) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.promotions.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.orange
                        : AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSlide(ProductPromotion promotion) {
    final product = promotion.product;
    final title = promotion.title?.trim().isNotEmpty == true
        ? promotion.title!.trim()
        : (promotion.productName ?? 'Offre du moment');
    final oldPrice = promotion.originalPrice > 0
        ? promotion.originalPrice
        : (product?.price ?? 0);
    final endDate = promotion.endsAt == null
        ? null
        : formatDate(promotion.endsAt!.toIso8601String());

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        4,
        AppDimens.pagePadding,
        6,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onOpen(promotion),
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.goldLight, AppColors.orangeLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
              boxShadow: AppTheme.softShadow(),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppDimens.radiusPill),
                          ),
                        ),
                        child: Text(
                          '−${promotion.displayedDiscountPercent} %',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      if (promotion.productName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          promotion.productName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (oldPrice > 0)
                            Text(
                              formatAmount(oldPrice),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textFaint,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          if (oldPrice > 0) const SizedBox(width: 8),
                          Text(
                            formatAmount(promotion.promoPrice),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        endDate == null
                            ? 'Offre à durée limitée'
                            : 'Jusqu’au $endDate',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Voir l’offre',
                            style: TextStyle(
                              color: AppColors.orangeDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: AppColors.orangeDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 104,
                    height: 160,
                    child: AppNetworkImage(
                      url: promotion.imageUrl ?? product?.displayImageUrl,
                      icon: Icons.local_offer,
                      iconBackground: AppColors.surface,
                      iconColor: AppColors.goldDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ types boutiques

/// Actions rapides de l'accueil : raccourcis vers les boutiques ouvertes par
/// type (Restaurant, Boutique, Maquis).
/// Bandeau d'accès à la carte : boutiques ouvertes autour du client.
class _NearbyMapCard extends StatelessWidget {
  const _NearbyMapCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.orangeLight, Color(0xFFFFF3E4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Boutiques autour de moi'),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          'Restaurants, maquis et boutiques sur la carte',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.orangeDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopTypeStrip extends StatelessWidget {
  const _ShopTypeStrip({required this.onSelect});

  final ValueChanged<VendorType> onSelect;

  static const Map<VendorType, IconData> _icons = {
    VendorType.restaurant: Icons.restaurant,
    VendorType.boutique: Icons.storefront,
    VendorType.maquis: Icons.soup_kitchen,
  };

  @override
  Widget build(BuildContext context) {
    const types = [
      VendorType.restaurant,
      VendorType.boutique,
      VendorType.maquis,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        8,
        AppDimens.pagePadding,
        4,
      ),
      child: Row(
        children: [
          for (var i = 0; i < types.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _ShopTypeTile(
                label: types[i].label,
                icon: _icons[types[i]]!,
                onTap: () => onSelect(types[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShopTypeTile extends StatelessWidget {
  const _ShopTypeTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.orangeLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 21, color: AppColors.orange),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icône associée à une catégorie selon son libellé.
IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('plats locaux') || n.contains('plat ')) {
    return Icons.rice_bowl;
  }
  if (n.contains('fast') || n.contains('snack')) {
    return Icons.fastfood;
  }
  if (n.contains('maquis')) {
    return Icons.soup_kitchen;
  }
  if (n.contains('boisson')) {
    return Icons.local_bar;
  }
  if (n.contains('fruit') || n.contains('légum') || n.contains('legum')) {
    return Icons.eco;
  }
  if (n.contains('viande') || n.contains('poisson')) {
    return Icons.kebab_dining;
  }
  if (n.contains('lait') || n.contains('œuf') || n.contains('oeuf')) {
    return Icons.local_dining;
  }
  if (n.contains('boulangerie') || n.contains('pain')) {
    return Icons.bakery_dining;
  }
  if (n.contains('ménage') ||
      n.contains('menage') ||
      n.contains('hygièn') ||
      n.contains('hygien')) {
    return Icons.cleaning_services;
  }
  if (n.contains('épicerie') || n.contains('epicerie')) {
    return Icons.local_grocery_store;
  }
  return Icons.restaurant;
}

// ---------------------------------------------------------------- restaurants

/// Carte « Restaurants populaires » : image, nom, catégorie • ville,
/// note, temps d’estimation, statut de livraison et favori.
class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.vendor,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final HomeVendor vendor;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  static String _formatRating(double rating) =>
      rating.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = [
      if (vendor.category != null && vendor.category!.isNotEmpty)
        vendor.category!,
      if (vendor.city != null && vendor.city!.isNotEmpty) vendor.city!,
    ];
    final subtitle = subtitleParts.isNotEmpty
        ? subtitleParts.join(' • ')
        : (vendor.description ?? '');
    final isOpen = vendor.isOpen ?? false;
    final eta = vendor.etaLabel;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: AppNetworkImage(
                    url: vendor.coverUrl ?? vendor.logoUrl,
                    icon: Icons.storefront,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (vendor.rating != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatRating(vendor.rating!),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${vendor.reviewsCount})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        if (eta != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                eta,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isOpen
                                ? AppColors.green
                                : AppColors.textFaint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            isOpen
                                ? 'Livraison disponible'
                                : 'Fermé momentanément',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOpen
                                  ? AppColors.green
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: onToggleFavorite,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      favorite ? Icons.favorite : Icons.favorite_border,
                      size: 22,
                      color: favorite
                          ? AppColors.orange
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- divers

/// Bouton de filtres : carré arrondi beige avec icône de réglages orange.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.tr('Filtres'),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.tune, size: 22, color: AppColors.orange),
        ),
      ),
    );
  }
}

// ------------------------------------------------------- recherche dynamique

/// Panneau de résultats de la recherche dynamique : boutiques puis plats.
class _SearchOverlay extends StatelessWidget {
  const _SearchOverlay({
    required this.running,
    required this.query,
    required this.products,
    required this.vendors,
    required this.onVendor,
    required this.onProduct,
  });

  final bool running;
  final String query;
  final List<Product> products;
  final List<Vendor> vendors;
  final ValueChanged<Vendor> onVendor;
  final ValueChanged<Product> onProduct;

  @override
  Widget build(BuildContext context) {
    if (running) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.orange,
          ),
        ),
      );
    }

    if (products.isEmpty && vendors.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_off, color: AppColors.textFaint, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Aucun résultat pour “$query”',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (vendors.isNotEmpty) ...[
            const _SearchSectionLabel('Boutiques'),
            for (final vendor in vendors)
              _SearchVendorTile(vendor: vendor, onTap: () => onVendor(vendor)),
          ],
          if (products.isNotEmpty) ...[
            const _SearchSectionLabel('Plats'),
            for (final product in products)
              _SearchProductTile(
                product: product,
                onTap: () => onProduct(product),
              ),
          ],
        ],
      ),
    );
  }
}

class _SearchSectionLabel extends StatelessWidget {
  const _SearchSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w800,
          color: AppColors.textFaint,
        ),
      ),
    );
  }
}

class _SearchVendorTile extends StatelessWidget {
  const _SearchVendorTile({required this.vendor, required this.onTap});

  final Vendor vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final city = vendor.city;
    final subtitle = (city != null && city.isNotEmpty) ? city : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 42,
                height: 42,
                child: AppNetworkImage(
                  url: vendor.coverUrl ?? vendor.logoUrl,
                  icon: Icons.storefront,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchProductTile extends StatelessWidget {
  const _SearchProductTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 42,
                height: 42,
                child: AppNetworkImage(
                  url: product.displayImageUrl,
                  icon: Icons.fastfood,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  if (product.isOnPromo) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.goldLight,
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppDimens.radiusPill),
                        ),
                      ),
                      child: Text(
                        '−${product.displayedDiscountPercent} %',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.goldDark,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (product.isOnPromo)
                  Text(
                    formatAmount(product.price),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textFaint,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                AmountText(
                  product.displayedPrice,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
