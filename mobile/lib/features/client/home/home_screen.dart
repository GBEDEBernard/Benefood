import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/models/product.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/home_header.dart';
import '../../../shared/widgets/product_cards.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Accueil client (J148) : recherche, catégories, boutiques, produits en avant.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.marketplace, required this.session});

  final MarketplaceApi marketplace;
  final SessionProvider session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.marketplace.home();
  }

  /// En-tête premium partagé par les états chargé / chargement.
  Widget _homeHeader(String subtitle) {
    return HomeHeader(
      title: 'Béninfood',
      subtitle: subtitle,
      leading: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
        child: ClipOval(
          child: Image.asset(
            'assets/Logo.jpeg',
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const HomeBadgeIcon(icon: Icons.storefront, size: 48),
          ),
        ),
      ),
      actions: [
        HomeHeaderAction(
          icon: Icons.search,
          tooltip: 'Rechercher',
          onPressed: () => context.push('/client/search'),
        ),
      ],
    );
  }

  void _reload() {
    setState(() {
      _future = widget.marketplace.home();
    });
  }

  Future<void> _addToCart(Product product) async {
    try {
      await widget.marketplace.addToCart(product.id);
      if (!mounted) {
        return;
      }
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
    final firstName = (widget.session.user?.name ?? '').trim().split(' ').first;
    final subtitle = firstName.isEmpty || firstName == 'null'
        ? 'Le goût du Bénin, livré chez vous'
        : 'Bonjour, $firstName 👋 Que mangerez-vous aujourd’hui ?';

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
              // Header visible dès le chargement (design premium constant).
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _homeHeader(subtitle),
                  const ListSkeleton(),
                ],
              );
            }
            if (snapshot.hasError) {
              return ErrorState(
                message: snapshot.error is ApiException
                    ? (snapshot.error as ApiException).message
                    : 'Impossible de charger l’accueil.',
                onRetry: _reload,
              );
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // --- En-tête premium : logo + salut ---
                _homeHeader(subtitle),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppDimens.pagePadding, 4, AppDimens.pagePadding, 4),
                  child: AppSearchField(
                    hintText: 'Rechercher un plat, un ingrédient…',
                    readOnly: true,
                    onTap: () => context.push('/client/search'),
                  ),
                ),
                if (data.categories.isNotEmpty)
                  _CategoryStrip(categories: data.categories, onSelect: (id) {
                    if (id.isNotEmpty) {
                      context.push('/client/search', extra: {'category': id});
                    }
                  }),
                if (data.featuredProducts.isNotEmpty) ...[
                  const SectionHeader(title: 'Plats du jour'),
                  ProductGrid(
                    products: data.featuredProducts,
                    shrinkWrap: true,
                    onTap: (p) => context.push('/client/product/${p.id}'),
                    onAdd: _addToCart,
                  ),
                ],
                if (data.vendors.isNotEmpty) ...[
                  const SectionHeader(title: 'Boutiques'),
                  SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: data.vendors.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final v = data.vendors[index];
                        return _VendorCard(
                          vendor: v,
                          onTap: () => context.push('/client/shop/${v.id}'),
                        );
                      },
                    ),
                  ),
                ],
                if (data.vendors.isEmpty && data.featuredProducts.isEmpty)
                  const EmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Aucune boutique pour le moment'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.categories, required this.onSelect});

  final List<dynamic> categories;
  final ValueChanged<String> onSelect;

  static const _icons = [
    Icons.ramen_dining,
    Icons.soup_kitchen,
    Icons.icecream,
    Icons.local_cafe,
    Icons.lunch_dining,
    Icons.kebab_dining,
    Icons.bakery_dining,
    Icons.rice_bowl,
    Icons.local_pizza,
    Icons.fastfood,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final c = categories[index] as dynamic;
          final name = _stringOf(c['name']);
          final id = _stringOf(c['id']);
          final icon = _icons[index % _icons.length];
          return InkWell(
            onTap: () => onSelect(id),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            child: SizedBox(
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: AppColors.green, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
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

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.vendor, required this.onTap});

  final HomeVendor vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 100,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(url: vendor.coverUrl ?? vendor.logoUrl, icon: Icons.storefront),
                    if (vendor.isOpen != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: StatusBadge(
                          label: vendor.isOpen! ? 'Ouvert' : 'Fermé',
                          color: vendor.isOpen! ? AppColors.green : AppColors.textSecondary,
                          small: true,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: AppNetworkImage(url: vendor.logoUrl, icon: Icons.storefront),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vendor.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    if (vendor.city != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              vendor.city!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _stringOf(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;