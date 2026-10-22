import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/navigation/notification_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/widgets/beninfood_header.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/food_decor.dart';
import '../restaurant_palette.dart';

/// Tableau de bord vendeur (mobile) — « Béninfood ».
///
/// Une page d'accueil dense et vivante : salutation + statut de la boutique,
/// chiffre d'affaires mis en avant, quatre indicateurs colorés, actions
/// rapides, courbe des ventes, répartition des commandes, dernières
/// commandes à traiter et produits les plus vendus.
///
/// Toutes les valeurs sont calculées à partir des commandes fournies par le
/// shell (aucun chiffre codé en dur hors du mode démonstration) et les
/// périodes « Aujourd'hui / Cette semaine / Ce mois » recalculent l'ensemble
/// de la page. Les animations d'entrée, les compteurs et les graphiques
/// donnent le rythme sans jamais bloquer l'interface.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.isOpen,
    required this.onOpenDrawer,
    required this.onToggleOpen,
    this.orders = const [],
    this.pendingCount = 0,
    this.rating = '4,6',
    this.reviewCount = '128 avis',
    this.newOrders = const [],
    this.onAccept,
    this.onRefuse,
    this.onAddProduct,
    this.onGoToShop,
    this.onOpenOrder,
    this.onOpenOrders,
    this.onOpenProducts,
    this.onOpenStats,
    this.onOpenReviews,
    this.onRefresh,
    this.userName,
    this.marketplace,
  });

  final bool isOpen;
  final VoidCallback onOpenDrawer;
  final ValueChanged<bool> onToggleOpen;

  /// Toutes les commandes du vendeur (source des KPI et graphiques).
  final List<Order> orders;

  /// Commandes en attente d'action (badge de la barre inférieure).
  final int pendingCount;

  final String rating;
  final String reviewCount;

  /// Commandes à accepter / refuser, affichées en haut du flux.
  final List<Order> newOrders;

  final ValueChanged<Order>? onAccept;
  final ValueChanged<Order>? onRefuse;
  final VoidCallback? onAddProduct;
  final VoidCallback? onGoToShop;
  final ValueChanged<Order>? onOpenOrder;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenStats;
  final VoidCallback? onOpenReviews;
  final Future<void> Function()? onRefresh;

  /// Nom de la personne connectée (le prénom est affiché dans la salutation).
  final String? userName;

  /// API du vendeur : null en mode démonstration.
  final MarketplaceApi? marketplace;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  )..forward();

  _SalesRange _range = _SalesRange.today;
  int? _selectedSale;

  bool get _isLive => widget.marketplace != null;

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  // ── Données ────────────────────────────────────────────────────────────

  static DateTime? _createdAt(Order order) =>
      DateTime.tryParse(order.createdAt ?? '')?.toLocal();

  static bool _countsRevenue(Order order) =>
      order.status != 'cancelled' &&
      order.status != 'refunded' &&
      order.status != 'awaiting_payment';

  List<Order> _ordersIn(_SalesRange range, {bool previous = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final (start, end) = switch (range) {
      _SalesRange.today =>
        previous
            ? (today.subtract(const Duration(days: 1)), today)
            : (today, today.add(const Duration(days: 1))),
      _SalesRange.week => (
        today.subtract(Duration(days: previous ? 13 : 6)),
        today.add(Duration(days: previous ? -6 : 1)),
      ),
      _SalesRange.month =>
        previous
            ? (
                DateTime(now.year, now.month - 1, 1),
                DateTime(now.year, now.month, 1),
              )
            : (
                DateTime(now.year, now.month, 1),
                DateTime(now.year, now.month + 1, 1),
              ),
    };
    return widget.orders.where((order) {
      final date = _createdAt(order);
      return date != null && !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }

  static int _revenue(List<Order> orders) => orders
      .where(_countsRevenue)
      .fold<int>(0, (sum, order) => sum + order.subtotal);

  int _dayRevenue(DateTime day) => widget.orders
      .where((order) {
        final date = _createdAt(order);
        return date != null &&
            date.year == day.year &&
            date.month == day.month &&
            date.day == day.day &&
            _countsRevenue(order);
      })
      .fold<int>(0, (sum, order) => sum + order.subtotal);

  /// Série des sept derniers jours affichée dans la courbe.
  ///
  /// En mode démonstration, les jours précédents sont extrapolés à partir du
  /// CA du jour pour montrer une courbe réaliste ; en production, chaque
  /// point est la somme réelle des commandes du jour.
  List<_SalePoint> _salesSeries() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );
    var values = [for (final day in days) _dayRevenue(day)];

    if (!_isLive && values.last > 0) {
      const ratios = [0.58, 0.71, 0.52, 0.88, 0.67, 0.84];
      values = [
        for (var index = 0; index < ratios.length; index++)
          (values.last * ratios[index]).round(),
        values.last,
      ];
    }

    return [
      for (var index = 0; index < days.length; index++)
        _SalePoint(
          label: _weekdayLetter(days[index].weekday),
          fullLabel: '${_weekdayShort(days[index].weekday)} ${days[index].day}',
          value: values[index],
        ),
    ];
  }

  List<_StatusSlice> _statusSlices(List<Order> orders) {
    int count(Set<String> statuses) =>
        orders.where((order) => statuses.contains(order.status)).length;

    return [
      _StatusSlice(
        label: 'Livrées',
        count: count(const {'delivered'}),
        color: _DashColors.green,
      ),
      _StatusSlice(
        label: 'En préparation',
        count: count(const {
          'accepted',
          'preparing',
          'ready',
          'assigned',
          'picked_up',
          'in_delivery',
        }),
        color: RestaurantPalette.orange,
      ),
      _StatusSlice(
        label: 'En attente',
        count: count(const {'awaiting_payment', 'paid'}),
        color: _DashColors.gold,
      ),
      _StatusSlice(
        label: 'Annulées',
        count: count(const {'cancelled', 'refunded'}),
        color: RestaurantPalette.danger,
      ),
    ];
  }

  /// Meilleures ventes : agrégées depuis les lignes de commande. En mode
  /// démonstration, un catalogue vitrine évite les libellés génériques.
  List<_ProductStat> _topProducts() {
    if (!_isLive) {
      return const [
        _ProductStat(
          name: 'Alloco poulet',
          quantity: 42,
          unitPrice: 2000,
          icon: Icons.lunch_dining_rounded,
        ),
        _ProductStat(
          name: 'Riz sauce tomate',
          quantity: 36,
          unitPrice: 1500,
          icon: Icons.rice_bowl_rounded,
        ),
        _ProductStat(
          name: 'Poulet braisé',
          quantity: 28,
          unitPrice: 3500,
          icon: Icons.set_meal_rounded,
        ),
        _ProductStat(
          name: 'Jus de bissap',
          quantity: 24,
          unitPrice: 500,
          icon: Icons.local_drink_rounded,
        ),
      ];
    }

    final stats = <String, _ProductStat>{};
    for (final order in widget.orders) {
      if (!_countsRevenue(order)) continue;
      for (final item in order.items) {
        final key = item.productId.isNotEmpty ? item.productId : item.name;
        final existing = stats[key];
        stats[key] = existing == null
            ? _ProductStat(
                name: item.name,
                quantity: item.quantity,
                unitPrice: item.quantity > 0
                    ? item.subtotal ~/ item.quantity
                    : item.unitPrice,
                imageUrl: item.imageUrl,
                icon: _iconForProduct(item.name),
              )
            : existing.merge(
                quantity: item.quantity,
                unitPrice: item.quantity > 0
                    ? item.subtotal ~/ item.quantity
                    : item.unitPrice,
                imageUrl: item.imageUrl,
              );
      }
    }
    final list = stats.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    return list.take(6).toList();
  }

  String get _firstName {
    final raw = widget.userName?.trim() ?? '';
    if (raw.isEmpty) {
      return _isLive ? '' : 'Marion';
    }
    return raw.split(RegExp(r'\s+')).first;
  }

  String get _greeting =>
      _firstName.isEmpty ? 'Bonjour 👋' : 'Bonjour, $_firstName 👋';

  // ── Interactions ───────────────────────────────────────────────────────

  Future<void> _refresh() async {
    await widget.onRefresh?.call();
  }

  Future<void> _pickRange() async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<_SalesRange>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _RangeSheet(selected: _range),
    );
    if (picked == null || !mounted || picked == _range) return;
    setState(() {
      _range = picked;
      _selectedSale = null;
    });
  }

  Future<void> _pickStatus() async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _StatusSheet(isOpen: widget.isOpen),
    );
    if (picked == null || !mounted || picked == widget.isOpen) return;
    widget.onToggleOpen(picked);
  }

  Future<void> _showRevenueInfo() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _RevenueInfoSheet(rangeLabel: _range.chip),
    );
  }

  void _openStats() {
    final callback = widget.onOpenStats;
    if (callback != null) {
      callback();
    } else {
      showToast(
        context,
        'Les statistiques sont disponibles une fois connecté.',
      );
    }
  }

  void _openPromo() {
    HapticFeedback.selectionClick();
    showToast(
      context,
      'Bientôt : créez et programmez vos promotions directement ici.',
    );
  }

  void _openReviews() {
    final callback = widget.onOpenReviews;
    if (callback != null) {
      callback();
    } else {
      showToast(context, 'Vos avis clients seront bientôt disponibles.');
    }
  }

  void _openOrder(Order order) {
    final callback = widget.onOpenOrder;
    if (callback != null) {
      callback(order);
    } else {
      showToast(context, 'Détail de ${order.reference} bientôt disponible.');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentOrders = _ordersIn(_range);
    final previousOrders = _ordersIn(_range, previous: true);
    final revenue = _revenue(currentOrders);
    final previousRevenue = _revenue(previousOrders);
    final revenueTrend = _growth(revenue, previousRevenue);
    final ordersTrend = _growth(currentOrders.length, previousOrders.length);
    final previousLabel = _range.previousLabel;
    final sales = _salesSeries();
    final slices = _statusSlices(currentOrders);
    final products = _topProducts();

    return Material(
      color: RestaurantPalette.background,
      child: Column(
        children: [
          BeninfoodAppBar(
            onMenu: widget.onOpenDrawer,
            api: widget.marketplace,
            audience: NotificationAudience.vendor,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: RestaurantPalette.orange,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                children: [
                  _stagger(
                    0,
                    _DashboardHeader(
                      greeting: _greeting,
                      isOpen: widget.isOpen,
                      onStatusTap: _pickStatus,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _stagger(
                    1,
                    _RevenueHero(
                      title: _range.heroTitle,
                      rangeLabel: _range.chip,
                      amount: revenue,
                      trend: revenueTrend,
                      comparison: _trendCaption(
                        revenueTrend,
                        revenue,
                        previousLabel,
                      ),
                      onPickRange: _pickRange,
                      onInfo: _showRevenueInfo,
                      onStats: _openStats,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _stagger(
                    2,
                    _StatsGrid(
                      range: _range,
                      orders: currentOrders.length,
                      pending: widget.pendingCount,
                      revenue: revenue,
                      rating: widget.rating,
                      reviewCount: widget.reviewCount,
                      ordersTrend: ordersTrend,
                      revenueTrend: revenueTrend,
                      previousLabel: previousLabel,
                      onOpenOrders: widget.onOpenOrders,
                      onOpenStats: _openStats,
                      onOpenReviews: _openReviews,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _stagger(
                    3,
                    _QuickActions(
                      onAddProduct: widget.onAddProduct,
                      onEditShop: widget.onGoToShop,
                      onCreatePromo: _openPromo,
                      onStats: _openStats,
                      onSeeAll: _openStats,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _stagger(
                    4,
                    _ChartsRow(
                      sales: sales,
                      slices: slices,
                      selected: _selectedSale,
                      onSelect: (index) =>
                          setState(() => _selectedSale = index),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _stagger(
                    5,
                    _NewOrdersSection(
                      orders: widget.newOrders,
                      onAccept: widget.onAccept,
                      onRefuse: widget.onRefuse,
                      onOpenOrder: _openOrder,
                      onSeeAll: widget.onOpenOrders,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _stagger(
                    6,
                    _TopProductsSection(
                      products: products,
                      onSeeAll: widget.onOpenProducts ?? widget.onGoToShop,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stagger(int index, Widget child) =>
      _Stagger(animation: _entrance, index: index, child: child);

  static String _trendCaption(
    _Growth? growth,
    int current,
    String previousLabel,
  ) {
    if (growth == null) {
      return current == 0
          ? 'Aucune vente sur la période'
          : 'Premières ventes sur la période';
    }
    return '${growth.label} par rapport à $previousLabel';
  }
}

// ───────────────────────── Modèles & périodes ─────────────────────────

enum _SalesRange {
  today('Aujourd’hui', 'du jour', 'hier'),
  week('Cette semaine', 'de la semaine', 'la semaine dernière'),
  month('Ce mois', 'du mois', 'le mois dernier');

  const _SalesRange(this.chip, this.suffix, this.previousLabel);

  final String chip;
  final String suffix;
  final String previousLabel;

  String get heroTitle => 'Chiffre d’affaires $suffix';
  String get ordersLabel => 'Commandes $suffix';
  String get revenueLabel => 'CA $suffix';
}

class _Growth {
  const _Growth({required this.label, required this.up});

  final String label;
  final bool up;
}

/// Croissance en pourcentage ; `null` si la période précédente est vide.
_Growth? _growth(int current, int previous) {
  if (previous <= 0) return null;
  final pct = (current - previous) * 100 / previous;
  return _Growth(label: '${pct >= 0 ? '+' : ''}${pct.round()} %', up: pct >= 0);
}

class _SalePoint {
  const _SalePoint({
    required this.label,
    required this.fullLabel,
    required this.value,
  });

  final String label;
  final String fullLabel;
  final int value;
}

class _StatusSlice {
  const _StatusSlice({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}

class _ProductStat {
  const _ProductStat({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
    this.icon = Icons.lunch_dining_rounded,
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final String? imageUrl;
  final IconData icon;

  _ProductStat merge({
    required int quantity,
    required int unitPrice,
    String? imageUrl,
  }) {
    return _ProductStat(
      name: name,
      quantity: this.quantity + quantity,
      unitPrice: unitPrice,
      imageUrl: this.imageUrl ?? imageUrl,
      icon: icon,
    );
  }
}

const _weekdayLetters = ['', 'L', 'M', 'M', 'J', 'V', 'S', 'D'];
const _weekdayShortNames = [
  '',
  'Lun.',
  'Mar.',
  'Mer.',
  'Jeu.',
  'Ven.',
  'Sam.',
  'Dim.',
];

String _weekdayLetter(int weekday) => _weekdayLetters[weekday];
String _weekdayShort(int weekday) => _weekdayShortNames[weekday];

IconData _iconForProduct(String name) {
  final value = name.toLowerCase();
  if (value.contains('jus') ||
      value.contains('bissap') ||
      value.contains('boisson') ||
      value.contains('eau')) {
    return Icons.local_drink_rounded;
  }
  if (value.contains('pizza')) return Icons.local_pizza_rounded;
  if (value.contains('poisson') || value.contains('attiéké')) {
    return Icons.set_meal_rounded;
  }
  if (value.contains('riz')) return Icons.rice_bowl_rounded;
  if (value.contains('glace')) return Icons.icecream_rounded;
  if (value.contains('salade')) return Icons.eco_rounded;
  if (value.contains('burger') || value.contains('poulet')) {
    return Icons.lunch_dining_rounded;
  }
  return Icons.restaurant_rounded;
}

// ───────────────────────── Couleurs locales ─────────────────────────

abstract final class _DashColors {
  static const Color forest = Color(0xFF0B3320);
  static const Color forestDeep = Color(0xFF072516);
  static const Color mint = Color(0xFFA9EDC3);
  static const Color green = Color(0xFF16A34A);
  static const Color greenWash = Color(0xFFE2F8EC);
  static const Color mintWash = Color(0xFFD5F7E5);
  static const Color emerald = Color(0xFF0F9D58);
  static const Color peach = Color(0xFFFFE9D5);
  static const Color peachDeep = Color(0xFFE97A1A);
  static const Color yellowWash = Color(0xFFFEF3C7);
  static const Color amber = Color(0xFFD97706);
  static const Color gold = Color(0xFFF4B83F);
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetWash = Color(0xFFF1EAFE);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueWash = Color(0xFFE8F0FE);
  static const Color roseWash = Color(0xFFFDE8EC);
  static const Color orangeWash = Color(0xFFFFF0E3);
  static const Color ink = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color line = Color(0xFFEDEFEA);

  static const List<List<Color>> thumbGradients = [
    [Color(0xFFFFE3C2), Color(0xFFFFC98E)],
    [Color(0xFFDFF7E7), Color(0xFFB6EAC7)],
    [Color(0xFFE9E2FF), Color(0xFFCFC0FF)],
    [Color(0xFFFFE1E7), Color(0xFFFFC0CD)],
  ];
}

// ───────────────────────── En-tête ─────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.greeting,
    required this.isOpen,
    required this.onStatusTap,
  });

  final String greeting;
  final bool isOpen;
  final VoidCallback onStatusTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: RestaurantPalette.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text(
                      'Tableau de bord',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _DashColors.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                greeting,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _DashColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Voici l’activité de votre boutique aujourd’hui.',
                maxLines: 2,
                style: TextStyle(
                  color: _DashColors.muted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _StatusPill(isOpen: isOpen, onTap: onStatusTap),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isOpen, required this.onTap});

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? _DashColors.green : RestaurantPalette.danger;
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 0,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Text(
              isOpen ? 'Ouvert' : 'Fermé',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 1),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: color.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Carte CA ─────────────────────────

class _RevenueHero extends StatelessWidget {
  const _RevenueHero({
    required this.title,
    required this.rangeLabel,
    required this.amount,
    required this.trend,
    required this.comparison,
    required this.onPickRange,
    required this.onInfo,
    required this.onStats,
  });

  final String title;
  final String rangeLabel;
  final int amount;
  final _Growth? trend;
  final String comparison;
  final VoidCallback onPickRange;
  final VoidCallback onInfo;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_DashColors.forest, _DashColors.forestDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: _DashColors.forest.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Repas photographique fondu sur la droite de la carte.
          Positioned(
            top: 0,
            bottom: 0,
            right: -26,
            width: 196,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.92,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.white, Colors.white],
                    stops: [0.0, 0.48, 1.0],
                  ).createShader(bounds),
                  child: Image.asset(
                    FoodDecor.bowlAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerRight,
                    cacheWidth: 520,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -50,
            top: -60,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _DashColors.mint.withValues(alpha: 0.18),
                    _DashColors.mint.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              title.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFB9D8C6),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.05,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _Pressable(
                            onTap: onInfo,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _Pressable(
                      onTap: onPickRange,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              rangeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _CountUp(
                          value: amount,
                          formatter: (value) =>
                              formatAmount(value.round(), showSymbol: false),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.1,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'FCFA',
                      style: TextStyle(
                        color: Color(0xFFD6EBDD),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _DashColors.mint.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        trend == null || trend!.up
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 12,
                        color: trend == null || trend!.up
                            ? _DashColors.mint
                            : const Color(0xFFFFB4B4),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        comparison,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFCDE6D8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Pressable(
                  onTap: onStats,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Voir les statistiques',
                            style: TextStyle(
                              color: _DashColors.forest,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: RestaurantPalette.orange,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Indicateurs ─────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.range,
    required this.orders,
    required this.pending,
    required this.revenue,
    required this.rating,
    required this.reviewCount,
    required this.ordersTrend,
    required this.revenueTrend,
    required this.previousLabel,
    this.onOpenOrders,
    required this.onOpenStats,
    required this.onOpenReviews,
  });

  final _SalesRange range;
  final int orders;
  final int pending;
  final int revenue;
  final String rating;
  final String reviewCount;
  final _Growth? ordersTrend;
  final _Growth? revenueTrend;
  final String previousLabel;
  final VoidCallback? onOpenOrders;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenReviews;

  @override
  Widget build(BuildContext context) {
    final ratingValue = double.tryParse(rating.replaceAll(',', '.')) ?? 0;

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.shopping_bag_outlined,
                  tint: _DashColors.greenWash,
                  accent: _DashColors.green,
                  label: range.ordersLabel,
                  value: _CountUp(
                    value: orders,
                    formatter: (value) => '${value.round()}',
                    style: _valueStyle,
                  ),
                  footer: _FooterTrend(
                    trend: ordersTrend,
                    fallback: '$orders au total',
                    previousLabel: previousLabel,
                  ),
                  onTap: onOpenOrders,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.schedule_rounded,
                  tint: _DashColors.peach,
                  accent: _DashColors.peachDeep,
                  label: 'En attente d’action',
                  value: _CountUp(
                    value: pending,
                    formatter: (value) => '${value.round()}',
                    style: _valueStyle,
                  ),
                  footer: _FooterText(
                    icon: pending > 0
                        ? Icons.priority_high_rounded
                        : Icons.check_circle_outline_rounded,
                    text: pending > 0
                        ? 'à traiter maintenant'
                        : 'tout est traité',
                    color: pending > 0
                        ? _DashColors.peachDeep
                        : _DashColors.green,
                  ),
                  onTap: onOpenOrders,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.account_balance_wallet_outlined,
                  tint: _DashColors.mintWash,
                  accent: _DashColors.emerald,
                  label: range.revenueLabel,
                  value: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        _CountUp(
                          value: revenue,
                          formatter: (value) =>
                              formatAmount(value.round(), showSymbol: false),
                          style: _valueStyle,
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          'FCFA',
                          style: TextStyle(
                            color: _DashColors.muted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  footer: _FooterTrend(
                    trend: revenueTrend,
                    fallback: 'sur la période',
                    previousLabel: previousLabel,
                  ),
                  onTap: onOpenStats,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.star_rounded,
                  tint: _DashColors.yellowWash,
                  accent: _DashColors.amber,
                  label: 'Note moyenne',
                  value: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(rating, style: _valueStyle),
                        const SizedBox(width: 2),
                        const Text(
                          '/5',
                          style: TextStyle(
                            color: _DashColors.muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  footer: Row(
                    children: [
                      _Stars(rating: ratingValue),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          reviewCount,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _DashColors.muted,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: onOpenReviews,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const TextStyle _valueStyle = TextStyle(
    color: _DashColors.ink,
    fontSize: 19,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.05,
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.tint,
    required this.accent,
    required this.label,
    required this.value,
    required this.footer,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color accent;
  final String label;
  final Widget value;
  final Widget footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 15, color: accent),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 9,
                  color: accent.withValues(alpha: 0.55),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent.withValues(alpha: 0.9),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            value,
            const SizedBox(height: 4),
            footer,
          ],
        ),
      ),
    );
  }
}

class _FooterTrend extends StatelessWidget {
  const _FooterTrend({
    required this.trend,
    required this.fallback,
    required this.previousLabel,
  });

  final _Growth? trend;
  final String fallback;
  final String previousLabel;

  @override
  Widget build(BuildContext context) {
    final growth = trend;
    if (growth == null) {
      return Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: _DashColors.muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              fallback,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _DashColors.muted,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    final color = growth.up ? _DashColors.green : RestaurantPalette.danger;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                growth.up
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 8,
                color: color,
              ),
              const SizedBox(width: 1),
              Text(
                growth.label,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'vs $previousLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _DashColors.muted,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterText extends StatelessWidget {
  const _FooterText({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final full = rating.floor();
    final hasHalf = rating - full >= 0.3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 5; index++)
          Icon(
            index < full
                ? Icons.star_rounded
                : index == full && hasHalf
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: 9,
            color: _DashColors.gold,
          ),
      ],
    );
  }
}

// ───────────────────────── Actions rapides ─────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAddProduct,
    required this.onEditShop,
    required this.onCreatePromo,
    required this.onStats,
    required this.onSeeAll,
  });

  final VoidCallback? onAddProduct;
  final VoidCallback? onEditShop;
  final VoidCallback onCreatePromo;
  final VoidCallback onStats;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Actions rapides', onSeeAll: onSeeAll),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              _QuickAction(
                label: 'Ajouter un produit',
                icon: Icons.add_rounded,
                accent: _DashColors.green,
                tint: _DashColors.greenWash,
                onTap: onAddProduct,
              ),
              const SizedBox(width: 8),
              _QuickAction(
                label: 'Modifier la boutique',
                icon: Icons.storefront_outlined,
                accent: _DashColors.peachDeep,
                tint: _DashColors.orangeWash,
                onTap: onEditShop,
              ),
              const SizedBox(width: 8),
              _QuickAction(
                label: 'Créer une promo',
                icon: Icons.percent_rounded,
                accent: _DashColors.violet,
                tint: _DashColors.violetWash,
                onTap: onCreatePromo,
              ),
              const SizedBox(width: 8),
              _QuickAction(
                label: 'Voir les statistiques',
                icon: Icons.insights_rounded,
                accent: _DashColors.blue,
                tint: _DashColors.blueWash,
                onTap: onStats,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.accent,
    required this.tint,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _DashColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: _DashColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Graphiques ─────────────────────────

class _ChartsRow extends StatelessWidget {
  const _ChartsRow({
    required this.sales,
    required this.slices,
    required this.selected,
    required this.onSelect,
  });

  final List<_SalePoint> sales;
  final List<_StatusSlice> slices;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final salesCard = _SalesCard(
      points: sales,
      selected: selected,
      onSelect: onSelect,
    );
    final donutCard = _DonutCard(slices: slices);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return Column(
            children: [salesCard, const SizedBox(height: 12), donutCard],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: salesCard),
              const SizedBox(width: 12),
              Expanded(child: donutCard),
            ],
          ),
        );
      },
    );
  }
}

class _SalesCard extends StatelessWidget {
  const _SalesCard({
    required this.points,
    required this.selected,
    required this.onSelect,
  });

  final List<_SalePoint> points;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final total = points.fold<int>(0, (sum, point) => sum + point.value);

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Aperçu des ventes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _DashColors.ink,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _DashColors.greenWash,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '7 j',
                  style: TextStyle(
                    color: _DashColors.green,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 132,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 950),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) => _SalesSparkline(
                points: points,
                progress: progress,
                selected: selected,
                onSelect: onSelect,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _DashColors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  '7 derniers jours',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _DashColors.muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatCompactAmount(total),
                style: const TextStyle(
                  color: _DashColors.ink,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesSparkline extends StatelessWidget {
  const _SalesSparkline({
    required this.points,
    required this.progress,
    required this.selected,
    required this.onSelect,
  });

  final List<_SalePoint> points;
  final double progress;
  final int? selected;
  final ValueChanged<int?> onSelect;

  static const double _leftPad = 27;
  static const double _rightPad = 5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (points.isEmpty) return;
            final plotWidth = math.max(width - _leftPad - _rightPad, 1);
            final ratio = ((details.localPosition.dx - _leftPad) / plotWidth)
                .clamp(0.0, 0.999);
            final index = (ratio * points.length).floor().clamp(
              0,
              points.length - 1,
            );
            onSelect(selected == index ? null : index);
          },
          child: CustomPaint(
            size: Size(width, constraints.maxHeight),
            painter: _LineChartPainter(
              points: points,
              progress: progress,
              selected: selected,
            ),
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.progress,
    required this.selected,
  });

  final List<_SalePoint> points;
  final double progress;
  final int? selected;

  static const double _left = 27;
  static const double _right = 5;
  static const double _top = 20;
  static const double _bottom = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _left,
      _top,
      size.width - _right,
      size.height - _bottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final maxValue = _niceMax(
      points.fold<double>(
        0,
        (value, point) => math.max(value, point.value.toDouble()),
      ),
    );

    final grid = Paint()
      ..color = _DashColors.line
      ..strokeWidth = 1;
    for (var index = 0; index <= 2; index++) {
      final y = plot.top + plot.height * index / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final label = TextPainter(
        text: TextSpan(
          text: formatCompactAmount(maxValue * (1 - index / 2)),
          style: const TextStyle(
            color: Color(0xFF9AA49D),
            fontSize: 7,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _left - 3);
      label.paint(
        canvas,
        Offset(_left - 3 - label.width, y - label.height / 2),
      );
    }

    if (points.isEmpty) return;

    final step = points.length == 1 ? 0.0 : plot.width / (points.length - 1);
    final offsets = <Offset>[
      for (var index = 0; index < points.length; index++)
        Offset(
          plot.left + step * index,
          plot.bottom -
              plot.height * (points[index].value / maxValue).clamp(0.0, 1.0),
        ),
    ];

    final line = _smoothPath(offsets);
    final area = Path.from(line)
      ..lineTo(offsets.last.dx, plot.bottom)
      ..lineTo(offsets.first.dx, plot.bottom)
      ..close();

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        plot.left,
        plot.top - 10,
        plot.left + plot.width * progress,
        plot.bottom + 1,
      ),
    );
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _DashColors.green.withValues(alpha: 0.30),
            _DashColors.green.withValues(alpha: 0.02),
          ],
        ).createShader(plot),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _DashColors.green,
    );
    for (var index = 0; index < offsets.length; index++) {
      final offset = offsets[index];
      final radius = index == selected ? 4.2 : 2.6;
      canvas.drawCircle(offset, radius, Paint()..color = Colors.white);
      canvas.drawCircle(
        offset,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = index == selected
              ? RestaurantPalette.orange
              : _DashColors.green,
      );
    }
    canvas.restore();

    for (var index = 0; index < points.length; index++) {
      final painter = TextPainter(
        text: TextSpan(
          text: points[index].label,
          style: TextStyle(
            color: index == selected
                ? RestaurantPalette.orange
                : const Color(0xFF9AA49D),
            fontSize: 7.5,
            fontWeight: index == selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = math.min(
        math.max(offsets[index].dx - painter.width / 2, plot.left - 2),
        size.width - painter.width - 1,
      );
      painter.paint(canvas, Offset(x, size.height - 10));
    }

    final index = selected;
    if (index != null && index >= 0 && index < points.length) {
      _drawTooltip(canvas, size, offsets[index], points[index]);
    }
  }

  Path _smoothPath(List<Offset> offsets) {
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    if (offsets.length == 1) return path;
    for (var index = 0; index < offsets.length - 1; index++) {
      final p0 = index == 0 ? offsets[index] : offsets[index - 1];
      final p1 = offsets[index];
      final p2 = offsets[index + 1];
      final p3 = index + 2 < offsets.length ? offsets[index + 2] : p2;
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  void _drawTooltip(Canvas canvas, Size size, Offset point, _SalePoint data) {
    final painter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${data.fullLabel}\n',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 7,
              fontWeight: FontWeight.w600,
              height: 1.6,
            ),
          ),
          TextSpan(
            text: formatAmount(data.value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 100);

    const padding = 6.0;
    final width = painter.width + padding * 2;
    final height = painter.height + padding * 1.2;
    final left = (point.dx - width / 2).clamp(2.0, size.width - width - 2);
    var top = point.dy - height - 7;
    if (top < 1) top = point.dy + 7;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = _DashColors.forest.withValues(alpha: 0.96),
    );
    painter.paint(canvas, Offset(left + padding, top + padding * 0.5));
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.selected != selected ||
      oldDelegate.points != points;
}

class _DonutCard extends StatelessWidget {
  const _DonutCard({required this.slices});

  final List<_StatusSlice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.count);

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _DashColors.ink,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: SizedBox(
              width: 92,
              height: 92,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1050),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, _) => CustomPaint(
                      size: const Size.square(92),
                      painter: _DonutPainter(
                        slices: slices,
                        progress: progress,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: const TextStyle(
                          color: _DashColors.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Total',
                        style: TextStyle(
                          color: _DashColors.muted,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          for (final slice in slices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.6),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: slice.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      slice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _DashColors.muted,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    total > 0
                        ? '${(slice.count * 100 / total).round()}%'
                        : '0%',
                    style: const TextStyle(
                      color: _DashColors.ink,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.slices, required this.progress});

  final List<_StatusSlice> slices;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.count);
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    const stroke = 12.0;

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = _DashColors.line,
    );
    if (total <= 0) return;

    const gap = 0.05;
    var start = -math.pi / 2;
    for (final slice in slices) {
      if (slice.count <= 0) continue;
      final sweep = math.pi * 2 * slice.count / total;
      final visible = math.max((sweep - gap) * progress, 0.0);
      canvas.drawArc(
        rect,
        start + gap / 2,
        visible,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = slice.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.slices != slices;
}

double _niceMax(double value) {
  if (value <= 0) return 1000;
  final exponent = (math.log(value) / math.ln10).floor();
  final magnitude = math.pow(10, exponent).toDouble();
  for (final factor in const [1.0, 1.5, 2.0, 2.5, 5.0, 7.5, 10.0]) {
    final candidate = factor * magnitude;
    if (candidate >= value) return candidate;
  }
  return 10 * magnitude;
}

// ───────────────────────── Nouvelles commandes ─────────────────────────

class _NewOrdersSection extends StatelessWidget {
  const _NewOrdersSection({
    required this.orders,
    required this.onAccept,
    required this.onRefuse,
    required this.onOpenOrder,
    required this.onSeeAll,
  });

  final List<Order> orders;
  final ValueChanged<Order>? onAccept;
  final ValueChanged<Order>? onRefuse;
  final ValueChanged<Order> onOpenOrder;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Nouvelles commandes',
          onSeeAll: onSeeAll,
          badge: orders.isEmpty ? null : '${orders.length}',
        ),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          const _EmptyCard(
            icon: Icons.receipt_long_outlined,
            title: 'Aucune nouvelle commande',
            subtitle:
                'Les prochaines commandes apparaîtront ici en temps réel.',
          )
        else
          for (final order in orders) ...[
            _NewOrderCard(
              order: order,
              onAccept: onAccept == null ? null : () => onAccept!(order),
              onRefuse: onRefuse == null ? null : () => onRefuse!(order),
              onDetails: () => onOpenOrder(order),
            ),
            if (order != orders.last) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _NewOrderCard extends StatelessWidget {
  const _NewOrderCard({
    required this.order,
    required this.onAccept,
    required this.onRefuse,
    required this.onDetails,
  });

  final Order order;
  final VoidCallback? onAccept;
  final VoidCallback? onRefuse;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final articles = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final isNew = order.status == 'paid' || order.status == 'awaiting_payment';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrderThumbnail(order: order),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.reference,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _DashColors.ink,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _DashColors.orangeWash,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Nouveau',
                              style: TextStyle(
                                color: RestaurantPalette.orange,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_timeAgo(order.createdAt)} · $articles article${articles > 1 ? 's' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _DashColors.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatAmount(order.total),
                    maxLines: 1,
                    style: const TextStyle(
                      color: _DashColors.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OrderAction(
                  label: 'Accepter',
                  icon: Icons.check_rounded,
                  color: _DashColors.green,
                  filled: true,
                  onTap: onAccept,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _OrderAction(
                  label: 'Refuser',
                  icon: Icons.close_rounded,
                  color: RestaurantPalette.danger,
                  background: _DashColors.roseWash,
                  onTap: onRefuse,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _OrderAction(
                  label: 'Détails',
                  icon: Icons.visibility_outlined,
                  color: RestaurantPalette.orange,
                  background: _DashColors.orangeWash,
                  onTap: onDetails,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderThumbnail extends StatelessWidget {
  const _OrderThumbnail({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final item = order.items.isEmpty ? null : order.items.first;
    final image = item?.imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 48,
        height: 48,
        child: image == null || image.isEmpty
            ? _thumbFallback(item?.name ?? '')
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _thumbFallback(item?.name ?? ''),
              ),
      ),
    );
  }

  Widget _thumbFallback(String name) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE3C2), Color(0xFFFFC98E)],
        ),
      ),
      child: Icon(
        _iconForProduct(name),
        size: 23,
        color: _DashColors.peachDeep,
      ),
    );
  }
}

class _OrderAction extends StatelessWidget {
  const _OrderAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
    this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color : (background ?? color.withValues(alpha: 0.10));
    final fg = filled ? Colors.white : color;

    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: 33,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _timeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return 'à l’instant';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return 'à l’instant';
  final diff = DateTime.now().difference(parsed.toLocal());
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  return 'il y a ${diff.inDays} j';
}

// ───────────────────────── Meilleurs produits ─────────────────────────

class _TopProductsSection extends StatelessWidget {
  const _TopProductsSection({required this.products, required this.onSeeAll});

  final List<_ProductStat> products;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Produits les plus vendus', onSeeAll: onSeeAll),
        const SizedBox(height: 8),
        if (products.isEmpty)
          const _EmptyCard(
            icon: Icons.restaurant_menu_rounded,
            title: 'Pas encore de ventes',
            subtitle:
                'Vos meilleures ventes s’afficheront dès la première commande.',
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (var index = 0; index < products.length; index++) ...[
                  _ProductCard(product: products[index], index: index),
                  if (index != products.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.index});

  final _ProductStat product;
  final int index;

  @override
  Widget build(BuildContext context) {
    final gradient =
        _DashColors.thumbGradients[index % _DashColors.thumbGradients.length];
    final image = product.imageUrl;

    return _Pressable(
      onTap: () => HapticFeedback.selectionClick(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 142,
        clipBehavior: Clip.antiAlias,
        decoration: RestaurantPalette.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 84,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null && image.isNotEmpty)
                    Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _ProductThumb(icon: product.icon, gradient: gradient),
                    )
                  else
                    _ProductThumb(icon: product.icon, gradient: gradient),
                  Positioned(
                    top: 7,
                    left: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${product.quantity} vendus',
                        style: const TextStyle(
                          color: _DashColors.forest,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _DashColors.ink,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 11,
                        color: RestaurantPalette.orange,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          '${product.quantity} commandes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _DashColors.muted,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatAmount(product.unitPrice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RestaurantPalette.orange,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.icon, required this.gradient});

  final IconData icon;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -8,
            child: Icon(
              icon,
              size: 62,
              color: Colors.white.withValues(alpha: 0.20),
            ),
          ),
          Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 24, color: _DashColors.peachDeep),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Éléments partagés ─────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
    this.badge,
  });

  final String title;
  final VoidCallback? onSeeAll;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _DashColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _DashColors.orangeWash,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: RestaurantPalette.orange,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null)
          _Pressable(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Voir tout',
                    style: TextStyle(
                      color: RestaurantPalette.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: RestaurantPalette.orange,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: RestaurantPalette.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _DashColors.orangeWash,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: RestaurantPalette.orange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _DashColors.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _DashColors.muted,
                    fontSize: 9.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stagger extends StatelessWidget {
  const _Stagger({
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.07).clamp(0.0, 0.55);
    final curve = CurvedAnimation(
      parent: animation,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curve.value) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _CountUp extends StatelessWidget {
  const _CountUp({
    required this.value,
    required this.formatter,
    required this.style,
  });

  final int value;
  final String Function(double value) formatter;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, current, _) =>
          Text(formatter(current), maxLines: 1, style: style),
    );
  }
}

/// Zone cliquable avec un léger enfoncement : la page répond au doigt sans
/// faire clignoter de ripple sur les cartes colorées.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, this.onTap, this.borderRadius});

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ───────────────────────── Feuilles modales ─────────────────────────

class _RangeSheet extends StatelessWidget {
  const _RangeSheet({required this.selected});

  final _SalesRange selected;

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Période',
      subtitle: 'Les indicateurs se recalculent sur la période choisie.',
      children: [
        for (final range in _SalesRange.values)
          _SheetOption(
            icon: switch (range) {
              _SalesRange.today => Icons.today_rounded,
              _SalesRange.week => Icons.view_week_rounded,
              _SalesRange.month => Icons.calendar_month_rounded,
            },
            title: range.chip,
            selected: range == selected,
            onTap: () => Navigator.of(context).pop(range),
          ),
      ],
    );
  }
}

class _StatusSheet extends StatelessWidget {
  const _StatusSheet({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Statut de la boutique',
      subtitle: 'Votre boutique reçoit-elle des commandes en ce moment ?',
      children: [
        _SheetOption(
          icon: Icons.storefront_rounded,
          title: 'Ouvrir la boutique',
          subtitle: 'Vous acceptez de nouvelles commandes.',
          tint: _DashColors.greenWash,
          accent: _DashColors.green,
          selected: isOpen,
          onTap: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 8),
        _SheetOption(
          icon: Icons.pause_circle_outline_rounded,
          title: 'Fermer la boutique',
          subtitle: 'Vous suspendez temporairement les commandes.',
          tint: _DashColors.roseWash,
          accent: RestaurantPalette.danger,
          selected: !isOpen,
          onTap: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

class _RevenueInfoSheet extends StatelessWidget {
  const _RevenueInfoSheet({required this.rangeLabel});

  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Votre chiffre d’affaires',
      subtitle: 'Ce montant correspond aux ventes validées sur la période.',
      children: [
        const _InfoRow(
          icon: Icons.receipt_long_rounded,
          title: 'Commandes prises en compte',
          text:
              'Toutes les commandes payées, hors commandes annulées, remboursées ou en attente de paiement.',
        ),
        const SizedBox(height: 10),
        const _InfoRow(
          icon: Icons.local_shipping_outlined,
          title: 'Hors frais de livraison',
          text:
              'Les frais de livraison reviennent aux livreurs et ne sont pas inclus dans votre CA.',
        ),
        const SizedBox(height: 10),
        _InfoRow(
          icon: Icons.trending_up_rounded,
          title: 'Comparaison automatique',
          text:
              'Chaque période est comparée à la précédente ($rangeLabel) pour suivre votre progression.',
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _DashColors.greenWash,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: _DashColors.green),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _DashColors.ink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(
                  color: _DashColors.muted,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _DashColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: _DashColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _DashColors.muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.tint = _DashColors.greenWash,
    this.accent = _DashColors.green,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
        decoration: BoxDecoration(
          color: selected ? tint.withValues(alpha: 0.55) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.35) : _DashColors.line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _DashColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: _DashColors.muted,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 18,
              color: selected ? accent : _DashColors.line,
            ),
          ],
        ),
      ),
    );
  }
}
