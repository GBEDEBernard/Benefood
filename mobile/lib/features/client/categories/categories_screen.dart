import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/category.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../home/home_screen.dart' show categoryIcon;

/// Catégories (J151) : grille 2 colonnes d'exploration visuelle.
///
/// Les catégories proviennent du catalogue (`GET /categories`) : chaque carte
/// affiche le libellé réel, le nombre de produits associés et un visuel
/// (première photo produit de la catégorie, sinon l'icône). Un appui ouvre la
/// recherche filtrée sur cette catégorie.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({
    super.key,
    required this.marketplace,
    this.onOpenMenu,
  });

  final MarketplaceApi marketplace;

  /// Ouvre le tiroir latéral (menu hamburger) — géré par le shell client.
  final VoidCallback? onOpenMenu;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<_CategoriesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CategoriesData> _load() async {
    final categories = await widget.marketplace.categories();

    final visuals = <String, String>{};
    try {
      final products = await widget.marketplace.products(perPage: 100);
      for (final product in products) {
        final url = product.imageUrl;
        if (url == null || url.isEmpty) {
          continue;
        }
        visuals.putIfAbsent(product.categoryId, () => url);
      }
    } catch (_) {
      // Visuels optionnels : on retombe sur l'icône de la catégorie.
    }

    return _CategoriesData(categories: categories, visualByCategoryId: visuals);
  }

  void _reload() => setState(() => _future = _load());

  void _openSearch(BuildContext context) => context.push('/client/search');

  void _openCategory(BuildContext context, Category category) {
    context.push('/client/search', extra: {'category': category.id});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BeninfoodAppBar(onMenu: widget.onOpenMenu, api: widget.marketplace),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              10,
              AppDimens.pagePadding,
              0,
            ),
            child: AppSearchField(
              hintText: 'Rechercher un plat, un restaurant...',
              readOnly: true,
              onTap: () => _openSearch(context),
            ),
          ),
          Expanded(
            child: FutureBuilder<_CategoriesData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const ListSkeleton();
                }
                if (snapshot.hasError) {
                  return ErrorState(
                    message: snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : 'Catégories indisponibles.',
                    onRetry: _reload,
                  );
                }
                final data = snapshot.data!;
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _SectionHeader(onSeeAll: () => _openSearch(context)),
                    if (data.categories.isEmpty)
                      const _EmptyCategories()
                    else
                      _CategoryGrid(
                        categories: data.categories,
                        visuals: data.visualByCategoryId,
                        onOpen: (category) => _openCategory(context, category),
                      ),
                    _PromoBanner(onExplore: () => _openSearch(context)),
                    const SizedBox(height: AppDimens.xl),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Catégories chargées + visuel (URL photo) par identifiant de catégorie.
class _CategoriesData {
  const _CategoriesData({
    required this.categories,
    required this.visualByCategoryId,
  });

  final List<Category> categories;
  final Map<String, String> visualByCategoryId;
}

/// Titre de section + lien « Voir tout → ».
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        20,
        AppDimens.pagePadding,
        12,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Catégories',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.4,
              ),
            ),
          ),
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Voir tout',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.orange,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 15, color: AppColors.orange),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Palette de repli appliquée cycliquement aux cartes.
const _cardPalette = <(Color, Color)>[
  (AppColors.orangeLight, AppColors.orange),
  (AppColors.greenLight, AppColors.green),
  (AppColors.goldLight, AppColors.goldDark),
  (AppColors.redLight, AppColors.red),
];

/// Grille 2 colonnes des catégories.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.visuals,
    required this.onOpen,
  });

  final List<Category> categories;

  /// Identifiant de catégorie → visuel dynamique (null = repli icône).
  final Map<String, String> visuals;

  final ValueChanged<Category> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppDimens.md,
        mainAxisSpacing: AppDimens.md,
        childAspectRatio: 1.12,
        children: [
          for (var i = 0; i < categories.length; i++)
            _CategoryCard(
              category: categories[i],
              imageUrl: visuals[categories[i].id],
              tint: _cardPalette[i % _cardPalette.length].$1,
              accent: _cardPalette[i % _cardPalette.length].$2,
              onTap: () => onOpen(categories[i]),
            ),
        ],
      ),
    );
  }
}

/// Carte catégorie : icône ronde, visuel, titre et nombre de produits.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.imageUrl,
    required this.tint,
    required this.accent,
    required this.onTap,
  });

  final Category category;
  final String? imageUrl;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = categoryIcon(category.name);
    final count = category.productsCount;
    final countLabel = count == null
        ? 'Explorer'
        : '$count ${count > 1 ? 'produits' : 'produit'}';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.softShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 21, color: accent),
                  ),
                  const Spacer(),
                  Container(
                    width: 54,
                    height: 54,
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: imageUrl == null
                        ? Icon(icon, size: 26, color: accent)
                        : AppNetworkImage(
                            url: imageUrl,
                            icon: icon,
                            iconColor: accent,
                            iconBackground: tint,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                countLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Message affiché lorsqu'aucune catégorie n'est disponible.
class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimens.pagePadding,
        vertical: 40,
      ),
      child: Text(
        'Aucune catégorie disponible pour le moment.',
        style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
      ),
    );
  }
}

/// Bannière promotionnelle : texte + bouton à gauche, décor à droite.
class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.lg),
        decoration: BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Envie de découvrir de nouveaux plats ?',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Explorez nos meilleures adresses à Cotonou.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onExplore,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.surface,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusPill,
                        ),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explorer',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(Icons.arrow_forward, size: 15),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const _PromoIllustration(),
          ],
        ),
      ),
    );
  }
}

/// Décor de droite : pin vert, itinéraire pointillé orange, plat.
class _PromoIllustration extends StatelessWidget {
  const _PromoIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 120,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DashedCurvePainter())),
          const Positioned(
            left: 0,
            top: 0,
            child: Icon(Icons.location_on, size: 30, color: AppColors.green),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                '🍛',
                style: TextStyle(fontSize: 32, height: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Arc pointillé reliant le repère au plat.
class _DashedCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.14, size.height * 0.25)
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.20,
        size.width * 0.66,
        size.height * 0.50,
      );

    final paint = Paint()
      ..color = AppColors.orange
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const dash = 6.0;
    const gap = 6.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCurvePainter oldDelegate) => false;
}
