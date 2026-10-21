import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/navigation/notification_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/beninfood_header.dart';
import '../../../../shared/widgets/stat_charts.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../widgets/vendor_bottom_bar.dart';

const _ink = Color(0xFF18231F);
const _muted = Color(0xFF6B7670);
const _line = Color(0xFFEDEFEA);

/// Tableau de bord statistique du vendeur : revenus, performance, statuts
/// des commandes et meilleurs produits sur la période choisie.
class VendorStatisticsScreen extends StatefulWidget {
  const VendorStatisticsScreen({
    super.key,
    required this.marketplace,
    this.onOpenDrawer,
    this.onSelectShellTab,
  });

  final MarketplaceApi marketplace;

  /// Ouvre le menu latéral vendeur (fourni par le shell).
  final VoidCallback? onOpenDrawer;

  /// Ouvre un onglet du shell vendeur depuis le footer d'actions rapides.
  /// Par défaut la navigation passe par le routeur (`/vendor?tab=…`).
  final ValueChanged<int>? onSelectShellTab;

  @override
  State<VendorStatisticsScreen> createState() => _VendorStatisticsScreenState();
}

class _VendorStatisticsScreenState extends State<VendorStatisticsScreen>
    with WidgetsBindingObserver {
  static const _autoRefreshInterval = Duration(seconds: 45);

  StatPeriod _period = StatPeriod.month;
  Map<String, dynamic> _stats = const {};
  bool _loading = true;
  bool _refreshing = false;
  DateTime? _lastUpdated;
  String? _error;
  String? _syncError;
  int _requestId = 0;
  Timer? _autoRefresh;

  Map<String, dynamic> get _kpis =>
      (_stats['kpis'] as Map<String, dynamic>?) ?? const {};
  Map<String, dynamic> get _comparison =>
      (_stats['comparison'] as Map<String, dynamic>?) ?? const {};
  List<Map<String, dynamic>> get _series =>
      (_stats['series'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
      const [];
  List<Map<String, dynamic>> get _breakdown =>
      (_stats['status_breakdown'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .toList() ??
      const [];
  List<Map<String, dynamic>> get _topProducts =>
      (_stats['top_products'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .toList() ??
      const [];
  String get _granularity =>
      (_stats['period'] as Map<String, dynamic>?)?['granularity']?.toString() ??
      'day';

  int _int(String key) => (_kpis[key] as num?)?.toInt() ?? 0;
  double? _num(Object? value) => value is num ? value.toDouble() : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Les commandes arrivent en continu : les chiffres se rafraîchissent seuls.
    _autoRefresh = Timer.periodic(_autoRefreshInterval, (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour dans l'app : on récupère les dernières ventes sans attendre.
    if (state == AppLifecycleState.resumed) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final requestId = ++_requestId;
    final hasData = _stats.isNotEmpty;
    setState(() {
      _error = null;
      if (!silent && !hasData) _loading = true;
      _refreshing = true;
    });
    try {
      final stats = await widget.marketplace.vendorStats(period: _period.key);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _stats = stats;
        _loading = false;
        _refreshing = false;
        _syncError = null;
        _lastUpdated = DateTime.now();
      });
    } on ApiException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        // Une actualisation silencieuse ratée ne vide jamais le tableau.
        if (_stats.isEmpty) {
          _error = e.message;
        } else {
          _syncError = e.message;
        }
      });
    }
  }

  void _onPeriod(StatPeriod period) {
    if (period == _period) return;
    setState(() => _period = period);
    _load();
  }

  /// Ouvre un onglet du shell vendeur (footer d'actions rapides).
  void _onShellTab(int index) {
    final callback = widget.onSelectShellTab;
    if (callback != null) {
      callback(index);
      return;
    }
    context.go('/vendor?tab=$index');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          BeninfoodAppBar(
            onMenu:
                widget.onOpenDrawer ??
                () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/vendor');
                  }
                },
            api: widget.marketplace,
            audience: NotificationAudience.vendor,
          ),
          // En-tête fixe : titre + sélecteur de période toujours visibles.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.lg,
              AppDimens.pagePadding,
              AppDimens.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistiques',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Suivez les performances de votre boutique',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 6),
                StatLiveStatus(
                  updatedAt: _lastUpdated,
                  refreshing: _refreshing,
                  onRefresh: () => _load(silent: true),
                ),
                const SizedBox(height: AppDimens.sm),
                StatPeriodSelector(period: _period, onChanged: _onPeriod),
                const SizedBox(height: 6),
                SizedBox(
                  height: 2,
                  child: _refreshing
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusPill,
                          ),
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            backgroundColor: AppColors.greenLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.green,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      // Footer vendeur : barre d'actions rapides vers les sections du shell.
      bottomNavigationBar: VendorBottomBar(
        currentIndex: -1,
        onSelect: _onShellTab,
        pendingOrders: _int('pending_orders'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _stats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stats.isEmpty) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final rating = (_kpis['rating'] as Map<String, dynamic>?) ?? const {};
    final ratingAvg = rating['average'];

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          AppDimens.md,
          AppDimens.pagePadding,
          AppDimens.xxl,
        ),
        children: [
          if (_syncError != null)
            StatSyncBanner(
              message: _syncError!,
              refreshing: _refreshing,
              onRetry: () => _load(silent: true),
            ),
          // ── Revenus + courbe dans une seule carte claire ──
          _RevenueCard(
            revenue: _int('revenue'),
            net: _int('net_revenue'),
            commission: _int('commission'),
            delta: _num(_comparison['revenue_pct']),
            chart: _series.isEmpty
                ? const StatEmpty(message: 'Aucune vente sur la période.')
                : StatTrendChart(
                    values: [
                      for (final point in _series) _num(point['revenue']) ?? 0,
                    ],
                    labels: _series
                        .map(
                          (e) => _seriesLabel(
                            e['label']?.toString() ?? '',
                            _granularity,
                          ),
                        )
                        .toList(),
                    color: AppColors.green,
                    valueFormatter: formatCompactAmount,
                  ),
          ),
          const SizedBox(height: AppDimens.lg),

          // ── Trois indicateurs clés ──
          Row(
            children: [
              Expanded(
                child: _MiniKpi(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Livrées',
                  value: _int('orders_delivered').toString(),
                  animatedValue: _int('orders_delivered'),
                  valueFormatter: (value) => value.round().toString(),
                  delta: _num(_comparison['orders_pct']),
                  accent: AppColors.orange,
                  tint: AppColors.orangeLight,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: _MiniKpi(
                  icon: Icons.payments_outlined,
                  label: 'Panier moyen',
                  value: formatCompactAmount(_int('average_basket')),
                  animatedValue: _int('average_basket'),
                  valueFormatter: formatCompactAmount,
                  accent: AppColors.green,
                  tint: AppColors.greenLight,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: _MiniKpi(
                  icon: Icons.groups_outlined,
                  label: 'Clients',
                  value: _int('unique_clients').toString(),
                  animatedValue: _int('unique_clients'),
                  valueFormatter: (value) => value.round().toString(),
                  accent: AppColors.blue,
                  tint: const Color(0xFFE8E8FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.lg),

          // ── Détails de performance en liste ──
          _Panel(
            title: 'Performance',
            child: Column(
              children: [
                _MetricRow(
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.blue,
                  label: 'Commandes totales',
                  value: _int('orders_total').toString(),
                  hint: '${_int('orders_cancelled')} annulée(s)',
                ),
                const _RowDivider(),
                _MetricRow(
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.goldDark,
                  label: 'Articles vendus',
                  value: _int('items_sold').toString(),
                ),
                const _RowDivider(),
                _MetricRow(
                  icon: Icons.star_rounded,
                  color: AppColors.goldDark,
                  label: 'Note moyenne',
                  value: ratingAvg == null
                      ? '—'
                      : '${'$ratingAvg'.replaceAll('.', ',')} / 5',
                  hint: '${rating['count'] ?? 0} avis',
                ),
                const _RowDivider(),
                _MetricRow(
                  icon: Icons.cancel_outlined,
                  color: AppColors.red,
                  label: 'Taux d\'annulation',
                  value: '${_kpis['cancellation_rate'] ?? 0} %',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.lg),

          // ── Statuts : barre segmentée + légende ──
          _Panel(
            title: 'Commandes par statut',
            subtitle: 'Répartition sur la période',
            child: _StatusBreakdown(
              entries: [
                for (final row in _breakdown)
                  _StatusEntry(
                    label: _statusLabel(row['status']?.toString() ?? ''),
                    count: (row['count'] as num?)?.toInt() ?? 0,
                    color: _statusColor(row['status']?.toString() ?? ''),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.lg),

          // ── Meilleurs produits avec barres de progression ──
          _Panel(
            title: 'Meilleurs produits',
            subtitle: 'Classés par quantité vendue',
            child: _TopProducts(products: _topProducts),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Widgets ─────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: AppDimens.md),
          child,
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
  border: Border.all(color: _line),
  boxShadow: const [
    BoxShadow(color: Color(0x0F18231F), blurRadius: 14, offset: Offset(0, 5)),
  ],
);

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.revenue,
    required this.net,
    required this.commission,
    required this.delta,
    required this.chart,
  });

  final int revenue;
  final int net;
  final int commission;
  final double? delta;
  final Widget chart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Chiffre d\'affaires',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (delta != null) _DeltaChip(delta: delta!),
            ],
          ),
          const SizedBox(height: 6),
          StatAnimatedAmount(
            value: revenue,
            formatter: (value) => formatAmount(value.round()),
            style: const TextStyle(
              color: _ink,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'vs période précédente',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: AppDimens.lg),
          chart,
          const SizedBox(height: AppDimens.lg),
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SplitStat(
                    color: AppColors.green,
                    label: 'Net vendeur',
                    amount: net,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: AppColors.green.withValues(alpha: 0.2),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: _SplitStat(
                    color: AppColors.orangeDark,
                    label: 'Commission',
                    amount: commission,
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

class _SplitStat extends StatelessWidget {
  const _SplitStat({
    required this.color,
    required this.label,
    required this.amount,
  });

  final Color color;
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: _muted, fontSize: 11.5)),
          ],
        ),
        const SizedBox(height: 3),
        StatAnimatedAmount(
          value: amount,
          formatter: (value) => formatAmount(value.round()),
          duration: const Duration(milliseconds: 900),
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final up = delta >= 0;
    final color = up ? AppColors.green : AppColors.red;
    final bg = up ? AppColors.greenLight : AppColors.redLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${up ? '+' : ''}${delta.toStringAsFixed(delta % 1 == 0 ? 0 : 1).replaceAll('.', ',')} %',
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.tint,
    this.delta,
    this.animatedValue,
    this.valueFormatter,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color tint;
  final double? delta;
  final num? animatedValue;
  final String Function(num value)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: AppDimens.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: animatedValue != null && valueFormatter != null
                ? StatAnimatedAmount(
                    value: animatedValue!,
                    formatter: valueFormatter!,
                    duration: const Duration(milliseconds: 900),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11.5),
          ),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Text(
              '${delta! >= 0 ? '▲' : '▼'} ${delta!.abs().toStringAsFixed(delta! % 1 == 0 ? 0 : 1).replaceAll('.', ',')} %',
              style: TextStyle(
                color: delta! >= 0 ? AppColors.green : AppColors.red,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: const TextStyle(color: _muted, fontSize: 11.5),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: _line);
}

class _StatusEntry {
  const _StatusEntry({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}

class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.entries});

  final List<_StatusEntry> entries;

  @override
  Widget build(BuildContext context) {
    final visible = entries.where((e) => e.count > 0).toList();
    final total = visible.fold<int>(0, (sum, e) => sum + e.count);

    if (total == 0) {
      return const StatEmpty(message: 'Aucune commande sur la période.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final e in visible)
                  Expanded(
                    flex: e.count,
                    child: Container(
                      margin: const EdgeInsets.only(right: 2),
                      color: e.color,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        for (final e in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: e.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Text(
                    e.label,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${e.count}',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${(e.count * 100 / total).round()} %',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.products});

  final List<Map<String, dynamic>> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const StatEmpty(message: 'Aucun produit vendu sur la période.');
    }

    final maxQty = products
        .map((p) => (p['quantity'] as num?)?.toInt() ?? 0)
        .fold<int>(1, (a, b) => b > a ? b : a);

    return Column(
      children: [
        for (var i = 0; i < products.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDimens.md),
          _ProductRow(
            rank: i + 1,
            name: (products[i]['name'] as String?) ?? 'Produit',
            quantity: (products[i]['quantity'] as num?)?.toInt() ?? 0,
            revenue: (products[i]['revenue'] as num?)?.toInt() ?? 0,
            ratio: ((products[i]['quantity'] as num?)?.toInt() ?? 0) / maxQty,
          ),
        ],
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.rank,
    required this.name,
    required this.quantity,
    required this.revenue,
    required this.ratio,
  });

  final int rank;
  final String name;
  final int quantity;
  final int revenue;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final podium = rank <= 3;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: podium ? AppColors.goldLight : const Color(0xFFF3F4F1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              color: podium ? AppColors.goldDark : _muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Text(
                    formatAmount(revenue),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.04, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F3EF),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    podium ? AppColors.orange : AppColors.green,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$quantity vendu(s)',
                style: const TextStyle(color: _muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Helpers ─────────────────────────

String _seriesLabel(String raw, String granularity) {
  final parts = raw.split('-');
  if (parts.length < 2) return raw;
  if (granularity == 'month') {
    final year = parts[0].length >= 2 ? parts[0].substring(2) : parts[0];
    return '${parts[1]}/$year';
  }
  if (parts.length < 3) return raw;
  return '${parts[2]}/${parts[1]}';
}

String _statusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'En attente';
    case 'confirmed':
      return 'Confirmées';
    case 'preparing':
      return 'En préparation';
    case 'ready':
      return 'Prêtes';
    case 'delivering':
      return 'En livraison';
    case 'delivered':
      return 'Livrées';
    case 'cancelled':
      return 'Annulées';
    case 'refunded':
      return 'Remboursées';
    default:
      return status.isEmpty ? 'Inconnu' : status;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'delivered':
      return AppColors.green;
    case 'cancelled':
    case 'refunded':
      return AppColors.red;
    case 'preparing':
    case 'ready':
      return AppColors.orange;
    default:
      return AppColors.goldDark;
  }
}
