import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/stat_charts.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../widgets/driver_bottom_bar.dart';

const _ink = Color(0xFF18231F);
const _muted = Color(0xFF6B7670);
const _line = Color(0xFFEDEFEA);

/// Tableau de bord statistique du livreur : gains, missions, répartition
/// commandes / colis et dernières livraisons sur la période choisie.
class DriverStatisticsScreen extends StatefulWidget {
  const DriverStatisticsScreen({
    super.key,
    required this.marketplace,
    this.onOpenDrawer,
    this.onSelectShellTab,
  });

  final MarketplaceApi marketplace;

  /// Ouvre le menu latéral livreur (fourni par le shell).
  final VoidCallback? onOpenDrawer;

  /// Ouvre un onglet du shell livreur depuis le footer d'actions rapides.
  /// Par défaut la navigation passe par le routeur (`/driver?tab=…`).
  final ValueChanged<int>? onSelectShellTab;

  @override
  State<DriverStatisticsScreen> createState() => _DriverStatisticsScreenState();
}

class _DriverStatisticsScreenState extends State<DriverStatisticsScreen>
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
      (_stats['breakdown'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .toList() ??
      const [];
  List<Map<String, dynamic>> get _recent =>
      (_stats['recent'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
      const [];
  String get _granularity =>
      (_stats['period'] as Map<String, dynamic>?)?['granularity']?.toString() ??
      'day';

  int _int(String key) => (_kpis[key] as num?)?.toInt() ?? 0;
  double _double(String key) => (_kpis[key] as num?)?.toDouble() ?? 0;
  double? _num(Object? value) => value is num ? value.toDouble() : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
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
      final stats = await widget.marketplace.driverStats(period: _period.key);
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

  /// Ouvre un onglet du shell livreur (footer d'actions rapides).
  void _onShellTab(int index) {
    final callback = widget.onSelectShellTab;
    if (callback != null) {
      callback(index);
      return;
    }
    context.go('/driver?tab=$index');
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
                    context.go('/driver');
                  }
                },
            api: widget.marketplace,
            audience: NotificationAudience.driver,
          ),
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
                  'Vos gains et vos livraisons en un coup d\'œil',
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
                            backgroundColor: AppColors.orangeLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.orange,
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
      // Footer livreur : barre d'actions rapides vers les sections du shell.
      bottomNavigationBar: DriverBottomBar(
        activeIndex: null,
        onSelect: _onShellTab,
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
    final distance = _double('distance_km');

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
          _EarningsCard(
            earnings: _int('earnings'),
            ordersEarnings: _int('orders_earnings'),
            parcelsEarnings: _int('parcels_earnings'),
            delta: _num(_comparison['earnings_pct']),
            chart: _series.isEmpty
                ? const StatEmpty(message: 'Aucune livraison sur la période.')
                : StatTrendChart(
                    values: [
                      for (final point in _series) _num(point['earnings']) ?? 0,
                    ],
                    labels: _series
                        .map(
                          (e) => _seriesLabel(
                            e['label']?.toString() ?? '',
                            _granularity,
                          ),
                        )
                        .toList(),
                    color: AppColors.orange,
                    valueFormatter: formatCompactAmount,
                  ),
          ),
          const SizedBox(height: AppDimens.lg),
          Row(
            children: [
              Expanded(
                child: _MiniKpi(
                  icon: Icons.delivery_dining_outlined,
                  label: 'Missions',
                  value: _int('missions_completed').toString(),
                  animatedValue: _int('missions_completed'),
                  valueFormatter: (value) => value.round().toString(),
                  delta: _num(_comparison['missions_pct']),
                  accent: AppColors.green,
                  tint: AppColors.greenLight,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: _MiniKpi(
                  icon: Icons.route_outlined,
                  label: 'Distance colis',
                  value: distance <= 0 ? '—' : formatDistance(distance),
                  animatedValue: distance > 0 ? distance : null,
                  valueFormatter: (value) => formatDistance(value.toDouble()),
                  accent: AppColors.blue,
                  tint: const Color(0xFFE8E8FF),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: _MiniKpi(
                  icon: Icons.star_rounded,
                  label: 'Note',
                  value: ratingAvg == null
                      ? '—'
                      : '${'$ratingAvg'.replaceAll('.', ',')} / 5',
                  animatedValue: ratingAvg is num ? ratingAvg : null,
                  valueFormatter: (value) =>
                      '${value.toStringAsFixed(1).replaceAll('.', ',')} / 5',
                  accent: AppColors.goldDark,
                  tint: AppColors.goldLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.lg),
          _Panel(
            title: 'Performance',
            child: Column(
              children: [
                _MetricRow(
                  icon: Icons.check_circle_outline,
                  color: AppColors.green,
                  label: 'Missions terminées',
                  value: _int('missions_completed').toString(),
                  hint:
                      '${_int('orders_delivered')} commande(s) · ${_int('parcels_delivered')} colis',
                ),
                const _RowDivider(),
                _MetricRow(
                  icon: Icons.trending_up_rounded,
                  color: AppColors.blue,
                  label: 'Taux de réussite',
                  value: '${_kpis['completion_rate'] ?? 0} %',
                ),
                const _RowDivider(),
                _MetricRow(
                  icon: Icons.cancel_outlined,
                  color: AppColors.red,
                  label: 'Missions annulées',
                  value: _int('missions_cancelled').toString(),
                ),
                const _RowDivider(),
                _MetricRow(
                  icon: Icons.payments_outlined,
                  color: AppColors.goldDark,
                  label: 'Gain moyen / mission',
                  value: formatAmount(_int('average_per_mission')),
                ),
                const _RowDivider(),
                _MetricRow(
                  icon: Icons.star_outline_rounded,
                  color: AppColors.goldDark,
                  label: 'Avis reçus',
                  value: '${rating['count'] ?? 0}',
                  hint: ratingAvg == null
                      ? 'Pas encore de note'
                      : '${'$ratingAvg'.replaceAll('.', ',')} / 5',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          _Panel(
            title: 'Répartition des missions',
            subtitle: 'Commandes et colis livrés sur la période',
            child: _MissionsBreakdown(entries: _breakdown),
          ),
          const SizedBox(height: AppDimens.lg),
          _Panel(
            title: 'Dernières livraisons',
            subtitle: 'Vos 5 dernières missions terminées',
            child: _RecentMissions(missions: _recent),
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

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.earnings,
    required this.ordersEarnings,
    required this.parcelsEarnings,
    required this.delta,
    required this.chart,
  });

  final int earnings;
  final int ordersEarnings;
  final int parcelsEarnings;
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
                  'Gains sur la période',
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
            value: earnings,
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
              color: AppColors.orangeLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SplitStat(
                    color: AppColors.orangeDark,
                    label: 'Commandes',
                    amount: ordersEarnings,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: AppColors.orange.withValues(alpha: 0.25),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: _SplitStat(
                    color: AppColors.green,
                    label: 'Colis',
                    amount: parcelsEarnings,
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

class _MissionsBreakdown extends StatelessWidget {
  const _MissionsBreakdown({required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final row in entries)
        (
          type: row['type']?.toString() ?? '',
          count: (row['count'] as num?)?.toInt() ?? 0,
          earnings: (row['earnings'] as num?)?.toInt() ?? 0,
        ),
    ];
    final total = rows.fold<int>(0, (sum, row) => sum + row.count);

    if (total == 0) {
      return const StatEmpty(message: 'Aucune mission sur la période.');
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
                for (final row in rows)
                  if (row.count > 0)
                    Expanded(
                      flex: row.count,
                      child: Container(
                        margin: const EdgeInsets.only(right: 2),
                        color: row.type == 'parcels'
                            ? AppColors.green
                            : AppColors.orange,
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        Row(
          children: [
            Expanded(
              child: _BreakdownTile(
                color: AppColors.orange,
                label: 'Commandes',
                count: rows
                    .where((row) => row.type == 'orders')
                    .fold<int>(0, (sum, row) => sum + row.count),
                earnings: rows
                    .where((row) => row.type == 'orders')
                    .fold<int>(0, (sum, row) => sum + row.earnings),
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: _BreakdownTile(
                color: AppColors.green,
                label: 'Colis',
                count: rows
                    .where((row) => row.type == 'parcels')
                    .fold<int>(0, (sum, row) => sum + row.count),
                earnings: rows
                    .where((row) => row.type == 'parcels')
                    .fold<int>(0, (sum, row) => sum + row.earnings),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  const _BreakdownTile({
    required this.color,
    required this.label,
    required this.count,
    required this.earnings,
  });

  final Color color;
  final String label;
  final int count;
  final int earnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
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
              Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: const TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatAmount(earnings),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentMissions extends StatelessWidget {
  const _RecentMissions({required this.missions});

  final List<Map<String, dynamic>> missions;

  @override
  Widget build(BuildContext context) {
    if (missions.isEmpty) {
      return const StatEmpty(
        message: 'Aucune livraison terminée pour le moment.',
      );
    }

    return Column(
      children: [
        for (var i = 0; i < missions.length; i++) ...[
          if (i > 0) const _RowDivider(),
          _RecentMissionTile(mission: missions[i]),
        ],
      ],
    );
  }
}

class _RecentMissionTile extends StatelessWidget {
  const _RecentMissionTile({required this.mission});

  final Map<String, dynamic> mission;

  @override
  Widget build(BuildContext context) {
    final isParcel = mission['type'] == 'parcel';
    final color = isParcel ? AppColors.green : AppColors.orange;
    final earnings = (mission['earnings'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isParcel ? Icons.inventory_2_outlined : Icons.delivery_dining,
              size: 19,
              color: color,
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission['label']?.toString() ?? 'Livraison',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDateTime(mission['delivered_at']?.toString()),
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            formatAmount(earnings),
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
