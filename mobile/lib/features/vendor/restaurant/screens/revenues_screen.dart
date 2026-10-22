import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/navigation/notification_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/widgets/beninfood_header.dart';
import '../../../../shared/widgets/food_decor.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../../../wallet/wallet_screen.dart';
import '../restaurant_palette.dart';

/// Écran « Portefeuille » du vendeur.
///
/// Bannière du solde disponible (décor food), quatre indicateurs clés,
/// répartition animée des fonds, journal des mouvements par onglets et
/// historique des retraits. Les montants proviennent de
/// `GET /vendors/me/revenues` (mois sélectionné, cache local, rafraîchissement
/// silencieux) et les retraits sont gérés par [WalletScreen].
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

  /// Données financières du mois courant (`vendorRevenues`).
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

  static const List<String> _tabs = [
    'Mouvements',
    'Séquentrés libérés',
    'Commissions',
    'Retraits',
  ];

  /// Statuts dont les fonds sont encore retenus (aligné sur le backend).
  static const Set<String> _pendingStatuses = {
    'paid',
    'accepted',
    'preparing',
    'ready',
    'assigned',
    'picked_up',
    'in_delivery',
  };

  DateTime _selectedMonth = _startOfMonth(DateTime.now());
  final Map<DateTime, Map<String, dynamic>> _cache = {};
  bool _loading = false;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _autoRefresh;

  bool _hideAmounts = false;
  int _tab = 0;
  final GlobalKey _tabsKey = GlobalKey();

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 860),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.revenue != null) {
      _lastUpdated = DateTime.now();
    }
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _silentRefresh(),
    );
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
    final months = List.generate(12, (i) => DateTime(now.year, now.month - i)).toList();
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
      final same =
          created.year == _selectedMonth.year && created.month == _selectedMonth.month;
      if (same) return true;
      return _isCurrentMonth && created.isAfter(recent);
    }).toList();
  }

  _Overview get _overview {
    final data = _data;
    return data != null ? _fromApi(data) : _demoOverview();
  }

  /// Données vivantes (`/vendors/me/revenues`).
  _Overview _fromApi(Map<String, dynamic> data) {
    int n(String key) => (data[key] as num?)?.toInt() ?? 0;

    final txs = <_Tx>[];
    final raw = data['transactions'];
    if (raw is List) {
      for (final item in raw.whereType<Map<String, dynamic>>()) {
        final at = DateTime.tryParse(item['date'] as String? ?? '');
        final ref = (item['reference'] as String? ?? '').trim();
        final net = (item['net'] as num?)?.toInt() ?? 0;
        final commission = (item['commission'] as num?)?.toInt() ?? 0;
        final delivered = item['status'] == 'delivered';
        final subtitle = 'Commande ${ref.isEmpty ? '—' : ref} · ${_when(at)}';
        if (net > 0) {
          txs.add(_Tx(
            kind: _TxKind.release,
            title: delivered ? 'Séquestre libéré' : 'Vente en cours',
            subtitle: subtitle,
            amount: net,
            status: delivered ? _TxStatus.success : _TxStatus.pending,
            at: at,
          ));
        }
        if (commission > 0) {
          txs.add(_Tx(
            kind: _TxKind.commission,
            title: 'Commission prélevée',
            subtitle: subtitle,
            amount: -commission,
            status: delivered ? _TxStatus.success : _TxStatus.pending,
            at: at,
          ));
        }
      }
    }

    final payouts = _parsePayouts(data['payouts']);
    txs.addAll(payouts.map(_payoutTx));

    final orders = _ordersForMonth();
    final gross = n('gross_sales');
    final commission = n('commission');

    return _Overview(
      available: n('available_balance'),
      pending: n('pending_amount'),
      released: n('net_sales'),
      commission: commission,
      gross: gross,
      commissionRate: gross > 0 ? (commission * 100 / gross).round() : 10,
      pendingOrders: orders.where((o) => _pendingStatuses.contains(o.status)).length,
      minPayout: n('min_payout'),
      payouts: payouts,
      txs: _sorted(txs),
    );
  }

  /// Données de démonstration (aucun backend branché).
  _Overview _demoOverview() {
    final orders = _ordersForMonth();
    var gross = 0;
    var commissionTotal = 0;
    var released = 0;
    var pending = 0;
    final txs = <_Tx>[];

    for (final order in orders) {
      if (order.status == 'cancelled' ||
          order.status == 'refunded' ||
          order.status == 'awaiting_payment') {
        continue;
      }
      final commission = order.financials?.commissionAmount ?? order.subtotal * 10 ~/ 100;
      final net = order.financials?.vendorAmount ?? order.subtotal - commission;
      final delivered = order.status == 'delivered';
      final at = DateTime.tryParse(order.createdAt ?? '');
      final subtitle = 'Commande ${order.reference} · ${_when(at)}';

      gross += order.subtotal;
      commissionTotal += commission;
      if (delivered) {
        released += net;
      } else {
        pending += net;
      }

      txs.add(_Tx(
        kind: _TxKind.release,
        title: delivered ? 'Séquestre libéré' : 'Vente en cours',
        subtitle: subtitle,
        amount: net,
        status: delivered ? _TxStatus.success : _TxStatus.pending,
        at: at,
      ));
      if (commission > 0) {
        txs.add(_Tx(
          kind: _TxKind.commission,
          title: 'Commission prélevée',
          subtitle: subtitle,
          amount: -commission,
          status: delivered ? _TxStatus.success : _TxStatus.pending,
          at: at,
        ));
      }
    }

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month);
    DateTime inMonth(int daysAgo) {
      final d = now.subtract(Duration(days: daysAgo));
      return d.isBefore(startOfMonth) ? startOfMonth : d;
    }

    // Les retraits de démonstration suivent le mois consulté.
    final payouts = [
      _Payout(
        amount: 4500,
        method: 'moov',
        status: 'processing',
        at: inMonth(0),
      ),
      _Payout(
        amount: 2500,
        method: 'mtn_open',
        status: 'executed',
        at: inMonth(4),
      ),
    ].where((p) {
      final at = p.at;
      return at != null &&
          at.year == _selectedMonth.year &&
          at.month == _selectedMonth.month;
    }).toList();
    txs.addAll(payouts.map(_payoutTx));

    final executed = payouts
        .where((p) => p.status == 'executed')
        .fold<int>(0, (sum, p) => sum + p.amount);

    return _Overview(
      available: math.max(released - executed, 0),
      pending: pending,
      released: released,
      commission: commissionTotal,
      gross: gross,
      commissionRate: gross > 0 ? (commissionTotal * 100 / gross).round() : 10,
      pendingOrders: orders.where((o) => _pendingStatuses.contains(o.status)).length,
      minPayout: 1000,
      payouts: payouts,
      txs: _sorted(txs),
    );
  }

  static List<_Tx> _sorted(List<_Tx> txs) {
    txs.sort((a, b) {
      final da = a.at;
      final db = b.at;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return txs;
  }

  List<_Payout> _parsePayouts(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((p) => _Payout(
              amount: (p['amount'] as num?)?.toInt() ?? 0,
              method: (p['method'] as String?) ?? '',
              status: (p['status'] as String?) ?? 'pending',
              at: DateTime.tryParse(
                (p['executed_at'] ?? p['created_at']) as String? ?? '',
              ),
            ))
        .toList();
  }

  _Tx _payoutTx(_Payout payout) {
    return _Tx(
      kind: _TxKind.payout,
      title: 'Retrait demandé',
      subtitle: 'vers ${_methodLabel(payout.method)} · ${_when(payout.at)}',
      amount: -payout.amount,
      status: switch (payout.status) {
        'executed' => _TxStatus.success,
        'failed' => _TxStatus.failed,
        _ => _TxStatus.pending,
      },
      at: payout.at,
    );
  }

  void _selectTab(int tab) {
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
    final ctx = _tabsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
  }

  Future<void> _openWallet() async {
    if (widget.marketplace == null) {
      showToast(
        context,
        'Les retraits sont disponibles une fois connecté à votre espace vendeur.',
      );
      return;
    }
    HapticFeedback.selectionClick();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      await router.push('/vendor/wallet');
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WalletScreen(
            marketplace: widget.marketplace!,
            role: WalletRole.vendor,
          ),
        ),
      );
    }
    if (mounted) await _silentRefresh();
  }

  Future<void> _showHelp() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => _HelpSheet(
        commissionRate: _overview.commissionRate,
        minPayout: _overview.minPayout,
      ),
    );
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

    final overview = _overview;

    return RefreshIndicator(
      onRefresh: _pullToRefresh,
      color: RestaurantPalette.orange,
      // Pas d'AnimatedSwitcher ici : la carte des mouvements porte une
      // GlobalKey et deux listes simultanées la dupliqueraient pendant la
      // transition. Les animations `_Stagger`/`_Reveal` suffisent.
      child: ListView(
        key: ValueKey('wallet-${_selectedMonth.year}-${_selectedMonth.month}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
            _stagger(
              0,
              _PageHeader(
                lastUpdated: _lastUpdated,
                onHelp: _showHelp,
              ),
            ),
            const SizedBox(height: 16),
            _stagger(
              1,
              _BalanceBanner(
                available: overview.available,
                pending: overview.pending,
                hidden: _hideAmounts,
                onToggleHidden: () => setState(() => _hideAmounts = !_hideAmounts),
                onDetails: widget.onSeeAllTap,
                onWithdraw: _openWallet,
              ),
            ),
            const SizedBox(height: 14),
            _stagger(
              2,
              _StatsGrid(
                overview: overview,
                monthLabel: _label(_selectedMonth),
                onTap: _selectTab,
              ),
            ),
            const SizedBox(height: 14),
            _stagger(
              3,
              _AllocationCard(
                overview: overview,
                monthLabel: _label(_selectedMonth),
                onPickMonth: _pickMonth,
              ),
            ),
            const SizedBox(height: 14),
            _stagger(
              4,
              _MovementsCard(
                key: _tabsKey,
                tabs: _tabs,
                selected: _tab,
                onSelect: (index) => setState(() => _tab = index),
                txs: switch (_tab) {
                  1 => overview.txs.where((t) => t.kind == _TxKind.release).toList(),
                  2 => overview.txs.where((t) => t.kind == _TxKind.commission).toList(),
                  3 => overview.txs.where((t) => t.kind == _TxKind.payout).toList(),
                  _ => overview.txs,
                },
                onSeeAll: widget.onSeeAllTap,
              ),
            ),
            const SizedBox(height: 14),
            _stagger(
              5,
              _PayoutsCard(
                payouts: overview.payouts,
                onSeeAll: _openWallet,
              ),
            ),
          ],
      ),
    );
  }

  Widget _stagger(int i, Widget child) =>
      _Stagger(anim: _entrance, index: i, child: child);
}

// ───────────────────────── Modèles ─────────────────────────

enum _TxKind { release, commission, payout }

enum _TxStatus { success, pending, failed }

class _Tx {
  const _Tx({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    this.at,
  });

  final _TxKind kind;
  final String title;
  final String subtitle;
  final int amount;
  final _TxStatus status;
  final DateTime? at;
}

class _Payout {
  const _Payout({
    required this.amount,
    required this.method,
    required this.status,
    this.at,
  });

  final int amount;
  final String method;
  final String status;
  final DateTime? at;
}

class _Overview {
  const _Overview({
    required this.available,
    required this.pending,
    required this.released,
    required this.commission,
    required this.gross,
    required this.commissionRate,
    required this.pendingOrders,
    required this.minPayout,
    required this.payouts,
    required this.txs,
  });

  final int available;
  final int pending;
  final int released;
  final int commission;
  final int gross;
  final int commissionRate;
  final int pendingOrders;
  final int minPayout;
  final List<_Payout> payouts;
  final List<_Tx> txs;
}

// ───────────────────────── Couleurs locales ─────────────────────────

abstract final class _WalletColors {
  static const Color forest = Color(0xFF0B3320);
  static const Color forestDeep = Color(0xFF072516);
  static const Color mint = Color(0xFFA9EDC3);
  static const Color orangeWash = Color(0xFFFFF0E3);
  static const Color greenWash = Color(0xFFE8F7EE);
  static const Color redWash = Color(0xFFFDECEC);
  static const Color goldWash = Color(0xFFFFF6DE);
  static const Color gold = Color(0xFFF4B83F);
  static const Color goldDark = Color(0xFF9A6A08);
  static const Color lightGreen = Color(0xFF3DD68C);
}

// ───────────────────────── Page ─────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onHelp, this.lastUpdated});

  final VoidCallback onHelp;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Portefeuille',
                style: TextStyle(
                  color: RestaurantPalette.darkText,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Gérez vos fonds et suivez vos transactions',
                maxLines: 2,
                style: TextStyle(
                  color: RestaurantPalette.grayText,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              if (lastUpdated != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: RestaurantPalette.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mis à jour à ${_clock(lastUpdated!)}',
                      style: const TextStyle(
                        color: RestaurantPalette.grayText,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        _Pressable(
          onTap: onHelp,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: RestaurantPalette.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline_rounded, size: 15, color: RestaurantPalette.orange),
                SizedBox(width: 5),
                Text(
                  'Aide',
                  style: TextStyle(
                    color: RestaurantPalette.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Bannière solde ─────────────────────────

class _BalanceBanner extends StatelessWidget {
  const _BalanceBanner({
    required this.available,
    required this.pending,
    required this.hidden,
    required this.onToggleHidden,
    required this.onWithdraw,
    this.onDetails,
  });

  final int available;
  final int pending;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final Future<void> Function() onWithdraw;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_WalletColors.forest, _WalletColors.forestDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: _WalletColors.forest.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Motif de fond : halo, pièce filigrane et décor food (bannières).
          Positioned(
            right: -46,
            top: -54,
            child: Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _WalletColors.mint.withValues(alpha: 0.16),
                    _WalletColors.mint.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -18,
            bottom: -26,
            child: Transform.rotate(
              angle: -0.18,
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 132,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: FoodDecor(
                bowlLeft: -34,
                bowlBottom: -42,
                bowlWidth: 176,
                bowlOpacity: 0.26,
                herbsRight: -18,
                herbsTop: -26,
                herbsWidth: 118,
                herbsOpacity: 0.20,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'SOLDE DISPONIBLE',
                        style: TextStyle(
                          color: Color(0xFFB9D8C6),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                    _Pressable(
                      onTap: onToggleHidden,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: Icon(
                            hidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            key: ValueKey(hidden),
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _Pressable(
                      onTap: onDetails,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Détails',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                size: 15, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                  child: hidden
                      ? const Text(
                          '••• •••',
                          key: ValueKey('hidden'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        )
                      : Row(
                          key: const ValueKey('visible'),
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: _CountUp(
                                  value: available,
                                  formatter: (v) => formatAmount(v.round(), showSymbol: false),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
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
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 3),
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 13, color: _WalletColors.mint),
                    SizedBox(width: 5),
                    Text(
                      'Disponible au retrait',
                      style: TextStyle(
                        color: _WalletColors.mint,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _Pressable(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onWithdraw();
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8A3D), RestaurantPalette.orange],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: RestaurantPalette.orange.withValues(alpha: 0.42),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance_wallet_rounded,
                                    size: 17, color: Colors.white),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Faire un retrait',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'EN ATTENTE',
                          style: TextStyle(
                            color: Color(0xFF9FBFAE),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hidden
                              ? '•••'
                              : formatAmount(pending, showSymbol: false),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Statistiques ─────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.overview,
    required this.monthLabel,
    required this.onTap,
  });

  final _Overview overview;
  final String monthLabel;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.local_shipping_outlined,
                  tint: _WalletColors.orangeWash,
                  accent: RestaurantPalette.orange,
                  label: 'Livraisons en attente',
                  value: Text(
                    formatAmount(overview.pending, showSymbol: false),
                    style: _valueStyle,
                  ),
                  caption:
                      '${overview.pendingOrders} commande${overview.pendingOrders > 1 ? 's' : ''}',
                  onTap: () => onTap(0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.savings_outlined,
                  tint: _WalletColors.greenWash,
                  accent: RestaurantPalette.success,
                  label: 'Total gagné',
                  value: _CountUp(
                    value: overview.gross,
                    formatter: (v) => formatAmount(v.round(), showSymbol: false),
                    style: _valueStyle,
                  ),
                  caption: monthLabel,
                  onTap: () => onTap(1),
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
                child: _StatCard(
                  icon: Icons.percent_rounded,
                  tint: _WalletColors.redWash,
                  accent: RestaurantPalette.danger,
                  label: 'Taux de commission',
                  value: Text('${overview.commissionRate} %', style: _valueStyle),
                  caption: 'Sur chaque commande',
                  onTap: () => onTap(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.paid_outlined,
                  tint: _WalletColors.goldWash,
                  accent: _WalletColors.goldDark,
                  label: 'Commissions payées',
                  value: _CountUp(
                    value: overview.commission,
                    formatter: (v) => formatAmount(v.round(), showSymbol: false),
                    style: _valueStyle,
                  ),
                  caption: monthLabel,
                  onTap: () => onTap(2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const TextStyle _valueStyle = TextStyle(
    color: RestaurantPalette.darkText,
    fontSize: 16.5,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.1,
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.tint,
    required this.accent,
    required this.label,
    required this.value,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color accent;
  final String label;
  final Widget value;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 11, 12),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: accent.withValues(alpha: 0.55),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent.withValues(alpha: 0.9),
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: value,
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent.withValues(alpha: 0.75),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Répartition (donut) ─────────────────────────

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({
    required this.overview,
    required this.monthLabel,
    required this.onPickMonth,
  });

  final _Overview overview;
  final String monthLabel;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    final slices = [
      _Slice('Disponible', overview.available, _WalletColors.forest),
      _Slice('En attente', overview.pending, RestaurantPalette.orange),
      _Slice('Séquentrés libérés', overview.released, _WalletColors.lightGreen),
      _Slice('Commissions', overview.commission, _WalletColors.gold),
    ];
    final total = slices.fold<int>(0, (sum, s) => sum + math.max(s.value, 0));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'RÉPARTITION DES FONDS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _MonthChip(label: monthLabel, onTap: onPickMonth),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1050),
                      curve: Curves.easeOutCubic,
                      builder: (context, progress, _) => CustomPaint(
                        size: const Size.square(128),
                        painter: _DonutPainter(slices: slices, progress: progress),
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: RestaurantPalette.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 24,
                        color: _WalletColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    for (final slice in slices)
                      _LegendRow(
                        slice: slice,
                        percent: total > 0
                            ? (math.max(slice.value, 0) * 100 / total).round()
                            : 0,
                        empty: total == 0,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slice {
  const _Slice(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.percent, required this.empty});

  final _Slice slice;
  final int percent;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RestaurantPalette.grayText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            empty ? '0' : formatAmount(math.max(slice.value, 0), showSymbol: false),
            style: const TextStyle(
              color: RestaurantPalette.darkText,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 34,
            child: Text(
              '$percent %',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: RestaurantPalette.grayText,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.slices, required this.progress});

  final List<_Slice> slices;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, s) => sum + math.max(s.value, 0));
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    final stroke = 14.0;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = RestaurantPalette.borderColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    if (total <= 0) return;
    const gap = 0.045;
    var start = -math.pi / 2;
    for (final slice in slices) {
      final value = math.max(slice.value, 0);
      if (value == 0) continue;
      final sweep = math.pi * 2 * value / total;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = slice.color;
      final visible = (sweep - gap) * progress;
      if (visible > 0) {
        canvas.drawArc(rect, start + gap / 2, visible, false, paint);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.slices != slices;
}

// ───────────────────────── Mouvements ─────────────────────────

class _MovementsCard extends StatelessWidget {
  const _MovementsCard({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.txs,
    this.onSeeAll,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  final List<_Tx> txs;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final visible = txs.take(6).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mouvements',
                  style: TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (txs.isNotEmpty)
                Text(
                  '${txs.length} opération${txs.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: RestaurantPalette.grayText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  _TabButton(
                    label: tabs[i],
                    active: selected == i,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
          const Divider(height: 18, color: RestaurantPalette.borderColor),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                    .animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(selected),
              child: visible.isEmpty
                  ? _EmptyTab(index: selected)
                  : Column(
                      children: [
                        for (var i = 0; i < visible.length; i++) ...[
                          _Reveal(index: i, child: _TxTile(tx: visible[i])),
                          if (i < visible.length - 1)
                            const Divider(
                              height: 1,
                              indent: 56,
                              color: RestaurantPalette.borderColor,
                            ),
                        ],
                      ],
                    ),
            ),
          ),
          if (visible.isNotEmpty && onSeeAll != null) ...[
            const Divider(height: 1, color: RestaurantPalette.borderColor),
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Voir tous les mouvements',
                      style: TextStyle(
                        color: RestaurantPalette.orange,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: RestaurantPalette.orange),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.only(top: 6, bottom: 5),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? RestaurantPalette.orange : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              color: active ? RestaurantPalette.orange : RestaurantPalette.grayText,
              fontSize: 12,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});

  final _Tx tx;

  @override
  Widget build(BuildContext context) {
    final (icon, tint, amountColor) = switch (tx.kind) {
      _TxKind.release => (
          Icons.lock_open_rounded,
          RestaurantPalette.success,
          RestaurantPalette.success,
        ),
      _TxKind.commission => (
          Icons.percent_rounded,
          RestaurantPalette.danger,
          RestaurantPalette.danger,
        ),
      _TxKind.payout => (
          Icons.account_balance_wallet_rounded,
          _WalletColors.goldDark,
          RestaurantPalette.darkText,
        ),
    };
    final (badgeLabel, badgeColor) = switch (tx.status) {
      _TxStatus.success => ('Réussi', RestaurantPalette.success),
      _TxStatus.pending => ('En cours', RestaurantPalette.orange),
      _TxStatus.failed => ('Échoué', RestaurantPalette.danger),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: tint),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RestaurantPalette.grayText,
                    fontSize: 10.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tx.amount >= 0 ? '+' : '-'}${formatAmount(tx.amount.abs(), showSymbol: false)}',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              _StatusBadge(label: badgeLabel, color: badgeColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final (title, hint) = switch (index) {
      1 => ('Aucun séquestre libéré', 'Les fonds sont libérés après chaque livraison.'),
      2 => ('Aucune commission prélevée', 'Les commissions apparaissent après livraison.'),
      3 => ('Aucun retrait pour l’instant', 'Vos demandes de retrait seront listées ici.'),
      _ => (
          'Aucune transaction ce mois-ci',
          'Les ventes validées apparaîtront ici dès leur encaissement.',
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: RestaurantPalette.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 26,
                color: RestaurantPalette.orange,
              ),
            ),
            const SizedBox(height: 11),
            Text(
              title,
              style: const TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: RestaurantPalette.grayText,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + (index * 45).clamp(0, 240)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ───────────────────────── Retraits ─────────────────────────

class _PayoutsCard extends StatelessWidget {
  const _PayoutsCard({required this.payouts, required this.onSeeAll});

  final List<_Payout> payouts;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final visible = payouts.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Historique des retraits',
                  style: TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InkWell(
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Voir tout',
                        style: TextStyle(
                          color: RestaurantPalette.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 17, color: RestaurantPalette.orange),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Aucun retrait enregistré.',
                  style: TextStyle(
                    color: RestaurantPalette.grayText,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < visible.length; i++) ...[
              _PayoutTile(payout: visible[i], onTap: onSeeAll),
              if (i < visible.length - 1)
                const Divider(
                  height: 1,
                  indent: 54,
                  color: RestaurantPalette.borderColor,
                ),
            ],
        ],
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout, required this.onTap});

  final _Payout payout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (payout.status) {
      'executed' => ('Réussi', RestaurantPalette.success),
      'failed' => ('Échoué', RestaurantPalette.danger),
      _ => ('En cours', RestaurantPalette.orange),
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _WalletColors.goldWash,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smartphone_rounded,
                size: 19,
                color: _WalletColors.goldDark,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatAmount(payout.amount)} vers ${_methodLabel(payout.method)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RestaurantPalette.darkText,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _when(payout.at),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RestaurantPalette.grayText,
                      fontSize: 10.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(label: label, color: color),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: RestaurantPalette.grayText,
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Aide ─────────────────────────

class _HelpSheet extends StatelessWidget {
  const _HelpSheet({required this.commissionRate, required this.minPayout});

  final int commissionRate;
  final int minPayout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: RestaurantPalette.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: RestaurantPalette.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      size: 21, color: RestaurantPalette.orange),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aide & portefeuille',
                        style: TextStyle(
                          color: RestaurantPalette.darkText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tout savoir sur vos fonds',
                        style: TextStyle(
                          color: RestaurantPalette.grayText,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _HelpRow(
              icon: Icons.lock_clock_rounded,
              title: 'Séquestre',
              text:
                  'Le montant d’une commande est retenu jusqu’à sa livraison, puis libéré sur votre solde.',
            ),
            _HelpRow(
              icon: Icons.percent_rounded,
              title: 'Commission Béninfood',
              text:
                  '$commissionRate % sont prélevés sur chaque commande livrée ; le reste vous est reversé.',
            ),
            _HelpRow(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Retrait',
              text:
                  'Retirez votre solde vers MTN, Moov ou Celtiis. Minimum ${formatAmount(minPayout <= 0 ? 1000 : minPayout)}.',
            ),
            _HelpRow(
              icon: Icons.schedule_rounded,
              title: 'Délais',
              text:
                  'Les demandes sont traitées sous 24 h ouvrées. Le statut reste visible dans l’historique.',
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: RestaurantPalette.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Compris',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: RestaurantPalette.background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: RestaurantPalette.forest),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    color: RestaurantPalette.grayText,
                    fontSize: 11.5,
                    height: 1.4,
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

// ───────────────────────── Sélecteur de mois ─────────────────────────

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: RestaurantPalette.orange.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 14, color: RestaurantPalette.orange),
              const SizedBox(width: 5),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: RestaurantPalette.orange,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: RestaurantPalette.orange),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSheet extends StatelessWidget {
  const _MonthSheet({
    required this.months,
    required this.label,
    required this.selected,
  });

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
            const Text(
              'Période',
              style: TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Portefeuille par mois',
              style: TextStyle(color: RestaurantPalette.grayText, fontSize: 12.5),
            ),
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
                      color: sel
                          ? RestaurantPalette.orange
                          : RestaurantPalette.grayText,
                    ),
                    title: Text(
                      label(m),
                      style: TextStyle(
                        color: sel
                            ? RestaurantPalette.orange
                            : RestaurantPalette.darkText,
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

// ───────────────────────── Squelette ─────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget box(double h, {double radius = 18}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Shimmer(
            child: Container(
              height: h,
              decoration: BoxDecoration(
                color: RestaurantPalette.borderColor,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
        );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [box(62, radius: 14), box(198, radius: 24), box(210), box(180)],
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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

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
        shaderCallback: (bounds) {
          final s = _c.value;
          return LinearGradient(colors: const [
            Color(0xFFE9ECE8),
            Color(0xFFF7F9F6),
            Color(0xFFE9ECE8),
          ]).createShader(
            Rect.fromLTWH(
              bounds.width * (s - 0.4),
              0,
              bounds.width * 0.8,
              bounds.height,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

// ───────────────────────── Animations ─────────────────────────

class _Stagger extends StatelessWidget {
  const _Stagger({required this.anim, required this.index, required this.child});

  final Animation<double> anim;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.08).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: anim,
      curve: Interval(start, start + 0.34, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
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

/// Effet d'appui : léger enfoncement élastique (boutons, cartes, chips).
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ───────────────────────── Helpers ─────────────────────────

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const List<String> _shortMonths = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

String _when(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final now = DateTime.now();
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  final sameDay =
      local.year == now.year && local.month == now.month && local.day == now.day;
  if (sameDay) return "Aujourd'hui, $time";
  return '${local.day} ${_shortMonths[local.month - 1]}, $time';
}

String _methodLabel(String method) {
  return switch (method) {
    'moov' => 'Moov Money',
    'mtn_open' => 'MTN Mobile Money',
    'sbin' => 'Celtiis Cash',
    '' => 'Mobile Money',
    _ => method,
  };
}
