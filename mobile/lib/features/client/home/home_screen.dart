import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/brand_logo.dart';
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
  static const List<_PromoSlide> _promoSlides = [
    _PromoSlide(
      head: 'Des repas ',
      highlight: 'savoureux',
      tail: ' livrés chez vous !',
      subtitle: 'Découvrez le meilleur de Cotonou',
    ),
    _PromoSlide(
      head: 'Vos plats locaux, ',
      highlight: 'prêts',
      tail: ' en un clin d’œil',
      subtitle: 'Maquis et traiteurs près de chez vous',
    ),
    _PromoSlide(
      head: 'Fast-food et ',
      highlight: 'boissons fraîches',
      tail: '',
      subtitle: 'Burgers, jus et gourmandises à volonté',
    ),
    _PromoSlide(
      head: 'Commandez, ',
      highlight: 'on livre',
      tail: ' chez vous',
      subtitle: 'Suivez votre commande en temps réel',
    ),
  ];

  late Future<HomeData> _future;

  /// Index de catégorie sélectionnée : 0 = « Tous », i ≥ 1 = categories[i - 1].
  int _categoryIndex = 0;
  final Set<String> _favoriteVendorIds = <String>{};

  /// Dernières catégories reçues (utilisées par le bouton de filtres).
  List<Category> _lastCategories = const [];

  @override
  void initState() {
    super.initState();
    _future = widget.marketplace.home();
  }

  void _reload() {
    setState(() {
      _future = widget.marketplace.home();
      _categoryIndex = 0;
    });
  }

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

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      builder: (context) {
        const notifications = [
          (
            icon: Icons.restaurant,
            title: 'Votre commande est en préparation',
            subtitle: 'Le restaurant prépare votre repas',
            time: 'Il y a 5 min',
          ),
          (
            icon: Icons.delivery_dining,
            title: 'Livraison en cours',
            subtitle: 'Votre livreur est en route',
            time: 'Il y a 20 min',
          ),
          (
            icon: Icons.local_offer,
            title: 'Offre du jour',
            subtitle: '10 % sur les plats locaux jusqu’à 18 h',
            time: 'Il y a 1 h',
          ),
        ];

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Tout lire',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final notification in notifications)
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.orangeLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      notification.icon,
                      size: 20,
                      color: AppColors.orange,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${notification.subtitle} • ${notification.time}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

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
                      title: const Text('Tous'),
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
  Widget _topSection() {
    final firstName = (widget.session.user?.name ?? '').trim().split(' ').first;
    final greeting = firstName.isEmpty || firstName == 'null'
        ? 'Le goût du Bénin, livré chez vous'
        : 'Bonjour, $firstName 👋 Que mangerez-vous aujourd’hui ?';

    return Material(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onOpenMenu,
                    tooltip: 'Menu',
                    icon: const Icon(
                      Icons.menu,
                      size: 26,
                      color: AppColors.text,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'assets/Logo.jpeg',
                        height: 44,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const BrandMark(),
                      ),
                    ),
                  ),
                  _NotificationBell(onPressed: _showNotifications),
                ],
              ),
            ),
          ),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AppSearchField(
                    hintText: 'Rechercher un plat, un resto...',
                    readOnly: true,
                    onTap: () => context.push('/client/search'),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterButton(onPressed: () => _showFilters(_lastCategories)),
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
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: FutureBuilder<HomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [_topSection(), const ListSkeleton(shrinkWrap: true)],
              );
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _topSection(),
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
            _lastCategories = data.categories;

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

            final imageUrls = allProducts
                .map((product) => product.imageUrl)
                .whereType<String>()
                .take(_promoSlides.length)
                .toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _topSection(),

                // --- Bannière promotionnelle (carrousel) ---
                _PromoBanner(
                  slides: _promoSlides,
                  imageUrls: imageUrls,
                  onOrder: () => context.push('/client/search'),
                ),

                // --- Catégories ---
                if (data.categories.isNotEmpty)
                  _CategoryStrip(
                    categories: data.categories,
                    selectedIndex: _categoryIndex,
                    onSelect: (index) => setState(() => _categoryIndex = index),
                  ),

                // --- Restaurants populaires ---
                if (data.vendors.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Restaurants populaires',
                    actionLabel: 'Voir tout',
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
                    title: 'Plats du jour',
                    actionLabel: 'Voir tout',
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
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        'Aucun plat dans cette catégorie pour le moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],

                if (data.vendors.isEmpty && allProducts.isEmpty)
                  const EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Aucune boutique pour le moment',
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

class _PromoSlide {
  const _PromoSlide({
    required this.head,
    required this.highlight,
    required this.tail,
    required this.subtitle,
  });

  final String head;
  final String highlight;
  final String tail;
  final String subtitle;
}

/// Carrousel promotionnel : carte beige, texte à gauche, image à droite,
/// bouton « Commander » et points de pagination.
class _PromoBanner extends StatefulWidget {
  const _PromoBanner({
    required this.slides,
    required this.imageUrls,
    required this.onOrder,
  });

  final List<_PromoSlide> slides;
  final List<String> imageUrls;
  final VoidCallback onOrder;

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
          height: 158,
          child: PageView.builder(
            itemCount: widget.slides.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final imageUrl = widget.imageUrls.isEmpty
                  ? null
                  : widget.imageUrls[index % widget.imageUrls.length];
              return _buildSlide(widget.slides[index], imageUrl);
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.slides.length; i++)
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
    );
  }

  Widget _buildSlide(_PromoSlide slide, String? imageUrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        8,
        AppDimens.pagePadding,
        4,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          border: Border.all(color: AppColors.border),
          boxShadow: AppTheme.softShadow(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        height: 1.25,
                      ),
                      children: [
                        TextSpan(text: slide.head),
                        TextSpan(
                          text: slide.highlight,
                          style: const TextStyle(color: AppColors.orange),
                        ),
                        TextSpan(text: slide.tail),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    slide.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    child: InkWell(
                      onTap: widget.onOrder,
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Commander',
                              style: TextStyle(
                                color: AppColors.surface,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color: AppColors.surface,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 100,
                height: double.infinity,
                child: AppNetworkImage(
                  url: imageUrl,
                  icon: Icons.rice_bowl,
                  iconBackground: AppColors.orangeLight,
                  iconColor: AppColors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ catégories

/// Bande de catégories défilante : « Tous » (actif par défaut) puis les
/// catégories du catalogue, icône dans un carré arrondi + libellé dessous.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<Category> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <_CategoryItem>[
      const _CategoryItem(label: 'Tous', icon: Icons.room_service, index: 0),
      for (var i = 0; i < categories.length; i++)
        _CategoryItem(
          label: categories[i].name,
          icon: categoryIcon(categories[i].name),
          index: i + 1,
        ),
    ];

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          8,
          AppDimens.pagePadding,
          8,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          final active = item.index == selectedIndex;
          return InkWell(
            onTap: () => onSelect(item.index),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            child: SizedBox(
              width: 74,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.orange
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      border: Border.all(
                        color: active ? AppColors.orange : AppColors.border,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      item.icon,
                      size: 26,
                      color: active ? AppColors.surface : AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.label,
    required this.icon,
    required this.index,
  });

  final String label;
  final IconData icon;
  final int index;
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

/// Cloche de notifications avec pastille rouge (menu de l'accueil).
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: onPressed,
            tooltip: 'Notifications',
            icon: const Icon(
              Icons.notifications_none,
              size: 26,
              color: AppColors.text,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '3',
                style: TextStyle(
                  color: AppColors.surface,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton de filtres : carré arrondi beige avec icône de réglages orange.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Filtres',
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
