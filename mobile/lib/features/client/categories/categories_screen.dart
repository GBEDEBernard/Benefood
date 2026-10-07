import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/notification_bell.dart';

/// Catégories (J151) : grille 2 colonnes d'exploration visuelle.
///
/// En-tête branded, recherche, grille de 8 cartes (icône colorée, titre,
/// nombre de restaurants, visuel) et bannière promotionnelle.
///
/// Les visuels sont dynamiques : à l'ouverture, le catalogue est chargé et
/// chaque carte affiche la première photo produit de la catégorie mappée
/// (repli emoji tant qu'aucune photo n'existe).
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  /// Slugs des catégories API → visuel résolu (photo produit ou icon_path).
  Map<String, String> _visualsBySlug = const {};

  @override
  void initState() {
    super.initState();
    _loadVisuals();
  }

  Future<void> _loadVisuals() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.marketplace.categories(),
        widget.marketplace.products(perPage: 100),
      ]);
      final categories = results[0] as List<Category>;
      final products = results[1] as List<Product>;

      final idBySlug = <String, String>{};
      final iconPathById = <String, String>{};
      void collect(List<Category> nodes) {
        for (final category in nodes) {
          idBySlug[category.slug] = category.id;
          final iconPath = category.iconPath;
          if (iconPath != null && iconPath.isNotEmpty) {
            iconPathById[category.id] = iconPath;
          }
          collect(category.children);
        }
      }

      collect(categories);

      final productImageByCategoryId = <String, String>{};
      for (final product in products) {
        final url = product.imageUrl;
        if (url == null || url.isEmpty) {
          continue;
        }
        productImageByCategoryId.putIfAbsent(product.categoryId, () => url);
      }

      final visuals = <String, String>{};
      for (final entry in idBySlug.entries) {
        final image =
            productImageByCategoryId[entry.value] ?? iconPathById[entry.value];
        if (image != null) {
          visuals[entry.key] = image;
        }
      }

      if (!mounted) {
        return;
      }
      setState(() => _visualsBySlug = visuals);
    } catch (_) {
      // Visuels optionnels : la grille reste affichée avec les emojis.
    }
  }

  /// Premier visuel disponible parmi les catégories mappées de la carte.
  String? _visualFor(_CategoryData card) {
    for (final slug in card.slugs) {
      final visual = _visualsBySlug[slug];
      if (visual != null) {
        return visual;
      }
    }
    return null;
  }

  void _openSearch(BuildContext context) => context.push('/client/search');

  @override
  Widget build(BuildContext context) {
    final visuals = {
      for (final card in _categories) card.title: _visualFor(card),
    };

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
                  const SizedBox(width: 44),
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
                  NotificationBell(api: widget.marketplace),
                ],
              ),
            ),
          ),
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
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _SectionHeader(onSeeAll: () => _openSearch(context)),
                _CategoryGrid(
                  visuals: visuals,
                  onOpen: () => _openSearch(context),
                ),
                _PromoBanner(onExplore: () => _openSearch(context)),
                const SizedBox(height: AppDimens.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

/// Données d'une carte de la grille (spec J151).
///
/// [slugs] : catégories réelles de l'API vers lesquelles la carte est
/// mappée (la spec et la base de données n'ont pas les mêmes libellés) ;
/// le premier slug avec un visuel disponible est retenu.
class _CategoryData {
  const _CategoryData({
    required this.title,
    required this.restaurants,
    required this.emoji,
    required this.icon,
    required this.tint,
    required this.accent,
    required this.slugs,
  });

  final String title;
  final String restaurants;
  final String emoji;
  final IconData icon;
  final List<String> slugs;

  /// Fond du cercle / du visuel.
  final Color tint;

  /// Couleur de l'icône.
  final Color accent;
}

const _categories = <_CategoryData>[
  _CategoryData(
    title: 'Plats locaux',
    restaurants: '124 restaurants',
    emoji: '🍚',
    icon: Icons.local_dining,
    tint: AppColors.orangeLight,
    accent: AppColors.orange,
    slugs: ['snacks-et-restauration'],
  ),
  _CategoryData(
    title: 'Fast-food',
    restaurants: '98 restaurants',
    emoji: '🍔',
    icon: Icons.fastfood,
    tint: AppColors.greenLight,
    accent: AppColors.green,
    slugs: ['snacks-et-restauration', 'boulangerie'],
  ),
  _CategoryData(
    title: 'Maquis',
    restaurants: '156 restaurants',
    emoji: '🍢',
    icon: Icons.room_service,
    tint: AppColors.goldLight,
    accent: AppColors.goldDark,
    slugs: ['snacks-et-restauration'],
  ),
  _CategoryData(
    title: 'Poulet',
    restaurants: '87 restaurants',
    emoji: '🍗',
    icon: Icons.lunch_dining,
    tint: AppColors.redLight,
    accent: AppColors.red,
    slugs: ['viandes-et-poissons', 'snacks-et-restauration'],
  ),
  _CategoryData(
    title: 'Soupes & Sauce',
    restaurants: '63 restaurants',
    emoji: '🍲',
    icon: Icons.soup_kitchen,
    tint: AppColors.greenLight,
    accent: AppColors.green,
    slugs: ['epicerie', 'snacks-et-restauration'],
  ),
  _CategoryData(
    title: 'Riz & Accompagnements',
    restaurants: '72 restaurants',
    emoji: '🍛',
    icon: Icons.rice_bowl,
    tint: AppColors.goldLight,
    accent: AppColors.goldDark,
    slugs: ['snacks-et-restauration'],
  ),
  _CategoryData(
    title: 'Boissons',
    restaurants: '54 restaurants',
    emoji: '🥤',
    icon: Icons.local_bar,
    tint: AppColors.orangeLight,
    accent: AppColors.orange,
    slugs: ['boissons-et-frais', 'snacks-et-restauration'],
  ),
  _CategoryData(
    title: 'Desserts',
    restaurants: '29 restaurants',
    emoji: '🍰',
    icon: Icons.cake,
    tint: AppColors.greenLight,
    accent: AppColors.green,
    slugs: ['boulangerie', 'snacks-et-restauration'],
  ),
];

/// Grille 2 colonnes des catégories.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.visuals, required this.onOpen});

  /// Titre de carte → visuel dynamique (null = repli emoji).
  final Map<String, String?> visuals;
  final VoidCallback onOpen;

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
          for (final category in _categories)
            _CategoryCard(
              category: category,
              imageUrl: visuals[category.title],
              onTap: onOpen,
            ),
        ],
      ),
    );
  }
}

/// Carte catégorie : icône ronde, visuel, titre et nombre de restaurants.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.imageUrl,
    required this.onTap,
  });

  final _CategoryData category;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                  // Cercle coloré + icône (haut gauche).
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: category.tint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      category.icon,
                      size: 21,
                      color: category.accent,
                    ),
                  ),
                  const Spacer(),
                  // Visuel (haut droit) : photo dynamique ou emoji.
                  Container(
                    width: 54,
                    height: 54,
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: category.tint,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: imageUrl == null
                        ? Text(
                            category.emoji,
                            style: const TextStyle(fontSize: 28, height: 1),
                          )
                        : AppNetworkImage(
                            url: imageUrl,
                            icon: category.icon,
                            iconColor: category.accent,
                            iconBackground: category.tint,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                category.title,
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
                category.restaurants,
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
          // Tracé pointillé orange (itinéraire).
          Positioned.fill(child: CustomPaint(painter: _DashedCurvePainter())),
          // Repère de localisation vert.
          const Positioned(
            left: 0,
            top: 0,
            child: Icon(Icons.location_on, size: 30, color: AppColors.green),
          ),
          // Visuel du plat.
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
