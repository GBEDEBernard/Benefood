import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/navigation/notification_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/widgets/beninfood_header.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../restaurant_palette.dart';

/// Écran « Revenus » : solde disponible, répartition net / commission,
/// ventes validées, attente de reversement et dernières transactions.
///
/// Dynamique : sélecteur de mois fonctionnel (chargement via [MarketplaceApi],
/// 12 derniers mois), compteurs animés, barre de répartition animée,
/// apparition en cascade, squelette de chargement, indicateur « Mis à jour »,
/// rafraîchissement silencieux au retour sur l'app et tiré-pour-actualiser.
class RevenusScreen extends StatefulWidget {
  const RevenusScreen({
    super.key,
    required this.orders,
    this.revenue,
    this.onOpenDrawer,
    this.marketplace,
    this.onSeeAllTap,
    this.onRefresh,
  });

  /// Commandes du vendeur (source de vérité gérée par le shell).
  final List<Order> orders;

  /// Données financières renvoyées par l'API (J21 §8). Utilisées pour le mois
  /// courant tant qu'aucune autre période n'a été sélectionnée.
  final Map<String, dynamic>? revenue;

  final VoidCallback? onOpenDrawer;
  final MarketplaceApi? marketplace;
  final VoidCallback? onSeeAllTap;
  final Future<void> Function()? onRefresh;

  @override
  State<RevenusScreen> createState() => _RevenusScreenState();
}

class _RevenusScreenState extends State<RevenusScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const List<String> _months = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  DateTime _selectedMonth = _startOfMonth(DateTime.now());
  final Map<DateTime, Map<String, dynamic>> _cache = {};
  bool _loading = false;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _autoRefresh;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.revenue != null) {
      _lastUpdated = DateTime.now();
    }
    _autoRefresh =
        Timer.periodic(const Duration(seconds: 60), (_) => _silentRefresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefresh?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  static DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month);
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  String _label(DateTime m) => '${_months[m.month - 1]} ${m.year}';
  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic>? get _data {
    if (_cache.containsKey(_selectedMonth)) return _cache[_selectedMonth];
    if (_isCurrentMonth) return widget.revenue;
    return null;
  }

  Future<void> _load({bool silent = false}) async {
    final api = widget.marketplace;
    if (api == null) return;
    final from = _selectedMonth;
    final to = DateTime(from.year, from.month + 1, 0);

    if (!silent && _data == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await api.vendorRevenues(from: _iso(from), to: _iso(to));
      if (!mounted) return;
      setState(() {
        _cache[_selectedMonth] = res;
        _loading = false;
        _error = null;
        _lastUpdated = DateTime.now();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (silent && _cache.containsKey(_selectedMonth)) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _silentRefresh() async {
    if (_data == null && !_loading) return;
    await _load(silent: true);
  }

  Future<void> _pullToRefresh() async {
    await widget.onRefresh?.call();
    await _load(silent: true);
    if (mounted) setState(() => _lastUpdated = DateTime.now());
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final months =
        List.generate(12, (i) => DateTime(now.year, now.month - i)).toList();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => _MonthSheet(
        months: months,
        label: _label,
        selected: _selectedMonth,
      ),
    );
    if (picked == null || !mounted) return;
    if (picked.year == _selectedMonth.year && picked.month == _selectedMonth.month) {
      return;
    }
    setState(() => _selectedMonth = picked);
    _entrance.forward(from: 0);
    await _load();
  }

  List<Order> _ordersForMonth() {
    final now = DateTime.now();
    final recent = now.subtract(const Duration(hours: 24));
    return widget.orders.where((o) {
      final created = DateTime.tryParse(o.createdAt ?? '');
      if (created == null) return true;
      final same = created.year == _selectedMonth.year &&
          created.month == _selectedMonth.month;
      if (same) return true;
      return _isCurrentMonth && created.isAfter(recent);
    }).toList();
  }

  (RevenuSummary, List<RevenuTransaction>, int) _compute(
      List<Order> monthOrders) {
    var validated = 0;
    var pending = 0;
    var delivered = 0;
    var completed = 0;
    final tx = <RevenuTransaction>[];
    final sorted = [...monthOrders];
    sorted.sort((a, b) => _cmp(a.createdAt, b.createdAt));

    for (final o in sorted) {
      final status = o.status;
      if (status == 'cancelled' || status == 'refunded') continue;
      if (status == 'awaiting_payment') {
        pending += o.total;
        continue;
      }
      validated += o.total;
      completed++;
      if (status == 'delivered') delivered += o.total;
      if (status == 'paid' ||
          status == 'accepted' ||
          status == 'preparing' ||
          status == 'ready' ||
          status == 'assigned' ||
          status == 'picked_up' ||
          status == 'in_delivery') {
        pending += o.total;
      }
      final t = _txLabel(o.createdAt);
      tx.add(RevenuTransaction(
        label: 'Vente ${o.reference}',
        dateLabel: t,
        amount: o.total,
        type: RevenuTransactionType.sale,
      ));
      tx.add(RevenuTransaction(
        label: 'Commission',
        dateLabel: t,
        amount: -(o.total * 0.10).round(),
        type: RevenuTransactionType.commission,
      ));
    }

    final commission = (validated * 0.10).round();
    final wallet = delivered - (delivered * 0.10).round();
    return (
      RevenuSummary(
        walletBalance: wallet,
        validatedSales: validated,
        commission: commission,
        pendingPayout: pending,
      ),
      tx.take(6).toList(),
      completed,
    );
  }

  (RevenuSummary, List<RevenuTransaction>, int) _fromApi(
      Map<String, dynamic> revenue) {
    int a(String k) => (revenue[k] as num?)?.toInt() ?? 0;
    final summary = RevenuSummary(
      walletBalance: a('available_balance'),
      validatedSales: a('gross_sales'),
      commission: a('commission'),
      pendingPayout: a('pending_amount'),
    );
    final tx = <RevenuTransaction>[];
    final raw = revenue['transactions'];
    if (raw is List) {
      for (final item in raw.whereType<Map<String, dynamic>>()) {
        final date = item['date'] as String?;
        tx.add(RevenuTransaction(
          label: 'Vente ${item['reference'] ?? ''}'.trim(),
          dateLabel: _txLabel(date),
          amount: (item['net'] as num?)?.toInt() ?? 0,
          type: RevenuTransactionType.sale,
        ));
        final c = (item['commission'] as num?)?.toInt() ?? 0;
        if (c > 0) {
          tx.add(RevenuTransaction(
            label: 'Commission',
            dateLabel: _txLabel(date),
            amount: -c,
            type: RevenuTransactionType.commission,
          ));
        }
      }
    }
    return (summary, tx.take(6).toList(), a('orders_count'));
  }

  static int _cmp(String? x, String? y) {
    final dx = DateTime.tryParse(x ?? '');
    final dy = DateTime.tryParse(y ?? '');
    if (dx == null || dy == null) return 0;
    return dy.compareTo(dx);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RestaurantPalette.background,
      child: Column(
        children: [
          BeninfoodAppBar(
            onMenu: widget.onOpenDrawer,
            api: widget.marketplace,
            audience: NotificationAudience.vendor,
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _data == null) {
      return const _Skeleton();
    }
    if (_error != null && _data == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final data = _data;
  final (summary, transactions, orderCount) =
      data != null ? _fromApi(data) : _compute(_ordersForMonth());

    return RefreshIndicator(
      onRefresh: _pullToRefresh,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.03), end: Offset.zero)
                .animate(anim),
            child: child,
          ),
        ),
        child: ListView(
          key: ValueKey('rev-${_selectedMonth.year}-${_selectedMonth.month}'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _stagger(
              0,
              _Header(
                monthLabel: _label(_selectedMonth),
                lastUpdated: _lastUpdated,
                onTap: _pickMonth,
              ),
            ),
            const SizedBox(height: 16),
            _stagger(1, _BalanceCard(summary: summary, orderCount: orderCount)),
            const SizedBox(height: 12),
            _stagger(
              2,
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.trending_up_rounded,
                        color: RestaurantPalette.success,
                        label: 'Ventes validées',
                        value: _CountUp(
                          value: summary.validatedSales,
                          formatter: (v) => formatAmount(v.round()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.hourglass_bottom_rounded,
                        color: RestaurantPalette.orange,
                        label: 'En attente de reversement',
                        value: _CountUp(
                          value: summary.pendingPayout,
                          formatter: (v) => formatAmount(v.round()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              3,
              _TransactionsCard(
                transactions: transactions,
                onSeeAllTap: widget.onSeeAllTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stagger(int i, Widget child) => _Stagger(anim: _entrance, index: i, child: child);
}

// ───────────────────────── Animations ─────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget box(double h) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Shimmer(
            child: Container(
              height: h,
              decoration: BoxDecoration(
                color: RestaurantPalette.borderColor,
                borderRadius: BorderRadius.circular(RestaurantPalette.radius),
              ),
            ),
          ),
        );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [box(64), box(210), box(124), box(228)],
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (ctx, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (b) {
          final s = _c.value;
          return LinearGradient(colors: const [
            Color(0xFFE9ECE8),
            Color(0xFFF7F9F6),
            Color(0xFFE9ECE8),
          ]).createShader(
            Rect.fromLTWH(b.width * (s - 0.4), 0, b.width * 0.8, b.height),
          );
        },
        child: child,
      ),
    );
  }
}

class _Stagger extends StatelessWidget {
  const _Stagger({required this.anim, required this.index, required this.child});

  final Animation<double> anim;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.09).clamp(0.0, 0.6);
    final c =
        CurvedAnimation(parent: anim, curve: Interval(start, start + 0.34, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: c,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(c),
        child: child,
      ),
    );
  }
}

class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.formatter, this.style});

  final num value;
  final String Function(num) formatter;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(
        formatter(value),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

// ───────────────────────── Widgets ─────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.monthLabel, required this.onTap, this.lastUpdated});

  final String monthLabel;
  final VoidCallback onTap;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Revenus',
                style: TextStyle(
                  color: RestaurantPalette.darkText,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Votre argent, en toute clarté',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: RestaurantPalette.grayText, fontSize: 13),
              ),
              if (lastUpdated != null) ...[
                const SizedBox(height: 3),
                Text(
                  'Mis à jour à ${_clock(lastUpdated!)}',
                  style: const TextStyle(
                    color: RestaurantPalette.grayText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        _MonthChip(label: monthLabel, onTap: onTap),
      ],
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: RestaurantPalette.orange.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 16, color: RestaurantPalette.orange),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: RestaurantPalette.orange,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: RestaurantPalette.orange),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSheet extends StatelessWidget {
  const _MonthSheet({required this.months, required this.label, required this.selected});

  final List<DateTime> months;
  final String Function(DateTime) label;
  final DateTime selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Période',
                style: TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text('Revenus par mois',
                style: TextStyle(color: RestaurantPalette.grayText, fontSize: 12.5)),
            const SizedBox(height: 6),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: months.length,
                itemBuilder: (_, i) {
                  final m = months[i];
                  final sel = m.year == selected.year && m.month == selected.month;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        sel ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 20,
                        color: sel ? RestaurantPalette.orange : RestaurantPalette.grayText),
                    title: Text(
                      label(m),
                      style: TextStyle(
                        color: sel ? RestaurantPalette.orange : RestaurantPalette.darkText,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, m),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.orderCount});

  final RevenuSummary summary;
  final int orderCount;

  @override
  Widget build(BuildContext context) {
    final gross = summary.validatedSales;
    final commission = summary.commission.clamp(0, gross);
    final net = gross - commission;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: RestaurantPalette.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    size: 19, color: RestaurantPalette.success),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Solde disponible',
                    style: TextStyle(
                        color: RestaurantPalette.grayText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
              ),
              if (orderCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: RestaurantPalette.background,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '$orderCount commande${orderCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: RestaurantPalette.darkText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _CountUp(
              value: summary.walletBalance,
              formatter: (v) => formatAmount(v.round()),
              style: const TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: RestaurantPalette.borderColor),
          const SizedBox(height: 16),
          const Text('Répartition des ventes validées',
              style: TextStyle(
                  color: RestaurantPalette.darkText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _SplitBar(net: net, commission: commission),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Legend(
                  color: RestaurantPalette.success,
                  label: 'Net vendeur',
                  value: _CountUp(
                    value: net,
                    formatter: (v) => formatAmount(v.round()),
                    style: const TextStyle(
                        color: RestaurantPalette.darkText,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Legend(
                  color: RestaurantPalette.orange,
                  label: 'Commission',
                  value: _CountUp(
                    value: commission,
                    formatter: (v) => formatAmount(v.round()),
                    style: const TextStyle(
                        color: RestaurantPalette.darkText,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.net, required this.commission});

  final int net;
  final int commission;

  @override
  Widget build(BuildContext context) {
    final total = net + commission;
    if (net <= 0 && commission <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: const SizedBox(
            height: 10, child: ColoredBox(color: RestaurantPalette.borderColor)),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final gap = net > 0 && commission > 0 ? 2.0 : 0.0;
        final usable = w - gap;
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (net > 0)
                  _Seg(width: usable * net / total, color: RestaurantPalette.success),
                if (gap > 0) const SizedBox(width: 2),
                if (commission > 0)
                  _Seg(width: usable * commission / total, color: RestaurantPalette.orange),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: width.clamp(0, double.infinity)),
      duration: const Duration(milliseconds: 920),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Container(width: v, color: color),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final Widget value;

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
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label,
                style:
                    const TextStyle(color: RestaurantPalette.grayText, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 3),
        value,
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  final IconData icon;
  final Color color;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(height: 12),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: value),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: RestaurantPalette.grayText, fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.transactions, this.onSeeAllTap});

  final List<RevenuTransaction> transactions;
  final VoidCallback? onSeeAllTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Dernières transactions',
                    style: TextStyle(
                        color: RestaurantPalette.darkText,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800)),
              ),
              InkWell(
                onTap: onSeeAllTap,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Voir tout',
                          style: TextStyle(
                              color: RestaurantPalette.orange,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      Icon(Icons.chevron_right,
                          size: 18, color: RestaurantPalette.orange),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (transactions.isEmpty)
            const _Empty()
          else
            for (var i = 0; i < transactions.length; i++)
              TweenAnimationBuilder<double>(
                key: ValueKey('${transactions[i].label}-$i'),
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 320 + i * 60),
                curve: Curves.easeOutCubic,
        builder: (context, v, child) => Opacity(opacity: v.clamp(0, 1), child: child),
                child: Column(
                  children: [
                    _Row(tx: transactions[i]),
                    if (i < transactions.length - 1)
                      const Divider(
                          height: 1,
                          indent: 54,
                          color: RestaurantPalette.borderColor),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: RestaurantPalette.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_outlined,
                  size: 28, color: RestaurantPalette.orange),
            ),
            const SizedBox(height: 12),
            const Text('Aucune transaction ce mois-ci',
                style: TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Les ventes validées apparaîtront ici dès leur encaissement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: RestaurantPalette.grayText, fontSize: 12.5, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.tx});

  final RevenuTransaction tx;

  @override
  Widget build(BuildContext context) {
    final sale = tx.type == RevenuTransactionType.sale;
    final tint = sale ? RestaurantPalette.success : RestaurantPalette.orange;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(
                sale ? Icons.south_west_rounded : Icons.percent_rounded,
                size: 19,
                color: tint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: RestaurantPalette.darkText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(tx.dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: RestaurantPalette.grayText, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(tx.amountText,
              style: TextStyle(
                  color: tx.amountColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ───────────────────────── Modèles ─────────────────────────

class RevenuSummary {
  const RevenuSummary({
    required this.walletBalance,
    required this.validatedSales,
    required this.commission,
    required this.pendingPayout,
  });

  final int walletBalance;
  final int validatedSales;
  final int commission;
  final int pendingPayout;
}

enum RevenuTransactionType { sale, commission }

class RevenuTransaction {
  const RevenuTransaction({
    required this.label,
    required this.dateLabel,
    required this.amount,
    required this.type,
  });

  final String label;
  final String dateLabel;
  final int amount;
  final RevenuTransactionType type;

  Color get amountColor =>
      amount >= 0 ? RestaurantPalette.success : RestaurantPalette.danger;

  String get amountText =>
      '${amount >= 0 ? '+' : '-'}${formatAmount(amount.abs())}';
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _txLabel(String? iso) {
  final date = DateTime.tryParse(iso ?? '')?.toLocal();
  if (date == null) return '';
  final now = DateTime.now();
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  final same =
      date.year == now.year && date.month == now.month && date.day == now.day;
  return same ? "Aujourd'hui, $time" : '${date.day}/${date.month} $time';
}
