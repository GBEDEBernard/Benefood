import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/fedapay_checkout_screen.dart';
import '../../../shared/widgets/food_decor.dart';
import '../../../shared/widgets/stat_charts.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../vendor/restaurant/restaurant_palette.dart';
import '../../wallet/widgets/payout_request_sheet.dart';

abstract final class _WalletColors {
  static const Color forest = Color(0xFF0B3320);
  static const Color forestDeep = Color(0xFF072516);
  static const Color mint = Color(0xFFA9EDC3);
  static const Color orangeWash = Color(0xFFFFF0E3);
  static const Color greenWash = Color(0xFFE8F7EE);
  static const Color blueWash = Color(0xFFEAF1FA);
  static const Color goldWash = Color(0xFFFFF6DE);
  static const Color gold = Color(0xFFF4B83F);
  static const Color goldDark = Color(0xFF9A6A08);
  static const Color navy = Color(0xFF1D4E89);
}

/// Devise d'affichage du portefeuille. Les retraits restent en FCFA : l'euro
/// n'est qu'une conversion indicative à la parité fixe.
enum _DisplayCurrency { xof, eur }

const List<String> _periodKeys = ['day', 'week', 'month'];
const List<String> _periodLabels = ['Jour', 'Semaine', 'Mois'];
const List<String> _periodComparisonLabels = [
  'vs hier',
  'vs sem. dernière',
  'vs mois dernier',
];

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({
    super.key,
    required this.marketplace,
    this.onOpenDrawer,
  });

  final MarketplaceApi marketplace;
  final VoidCallback? onOpenDrawer;

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic> _wallet = const {};
  Map<String, dynamic> _float = const {};
  Map<String, dynamic> _earnings = const {};
  List<Map<String, dynamic>> _payouts = const [];
  bool _loading = true;
  String? _error;
  bool _requesting = false;
  bool _floatBusy = false;
  bool _hideAmounts = false;
  int _tab = 0;
  int _earningsPeriod = 1;
  _DisplayCurrency _displayCurrency = _DisplayCurrency.xof;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 860),
  )..forward();

  int get _pending => (_wallet['pending_balance'] as num?)?.toInt() ?? 0;
  int get _available => (_wallet['available_balance'] as num?)?.toInt() ?? 0;
  int get _minPayout => (_wallet['min_payout'] as num?)?.toInt() ?? 1000;
  int get _floatBalance => (_float['prepaid_balance'] as num?)?.toInt() ?? 0;
  int get _commissionTotal =>
      (_wallet['commission_total'] as num?)?.toInt() ?? 0;
  int get _commissionRate =>
      (_wallet['commission_rate'] as num?)?.toInt() ?? 20;

  String? get _phone {
    final phone = (_wallet['phone'] as String?)?.trim();
    return (phone == null || phone.isEmpty) ? null : phone;
  }

  List<Map<String, dynamic>> get _transactions =>
      (_wallet['transactions'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .toList() ??
      const [];

  double get _eurRate =>
      (_earnings['eur_rate'] as num?)?.toDouble() ?? kXofPerEuro;

  Map<String, dynamic> get _earningsPeriods =>
      (_earnings['periods'] as Map<String, dynamic>?) ?? const {};

  List<Map<String, dynamic>> get _activeEarningsSeries {
    final series = _earnings['series'];
    if (series is! Map<String, dynamic>) return const [];
    return (series[_periodKeys[_earningsPeriod]] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const [];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallet = await widget.marketplace.driverWallet();
      Map<String, dynamic> floatData = const {};
      try {
        floatData = await widget.marketplace.driverFloat();
      } on ApiException {
        floatData = const {};
      }
      List<Map<String, dynamic>> payouts = const [];
      try {
        payouts = await widget.marketplace.driverPayouts();
      } on ApiException {
        payouts = const [];
      }
      Map<String, dynamic> earnings = const {};
      try {
        earnings = await widget.marketplace.driverEarnings();
      } on ApiException {
        earnings = const {};
      }
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _float = floatData;
        _earnings = earnings;
        _payouts = payouts;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _openPayoutSheet() async {
    if (_available < _minPayout) {
      showToast(
        context,
        'Solde disponible insuffisant (minimum ${formatAmount(_minPayout)}).',
        isError: true,
      );
      return;
    }
    final result = await showPayoutRequestSheet(
      context,
      available: _available,
      minPayout: _minPayout,
      phone: _phone,
    );
    if (result == null || !mounted) return;
    setState(() => _requesting = true);
    try {
      final payout = await widget.marketplace.requestDriverPayout(
        result.amount,
        method: result.method,
        destination: result.destination,
      );
      if (!mounted) return;
      final status = payout['status']?.toString();
      final message = switch (status) {
        'executed' => 'Retrait versé sur votre Mobile Money.',
        'failed' =>
          'Retrait échoué : le montant a été recrédité sur votre solde.',
        _ => 'Demande de retrait enregistrée, en cours de traitement.',
      };
      showToast(context, message, isError: status == 'failed');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _openFloatSheet() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => const _FloatSheet(),
    );
    if (result == null || !mounted) return;
    setState(() => _floatBusy = true);
    try {
      final payload = await widget.marketplace.topUpFloat(result);
      final checkoutUrl = payload['checkout_url'] as String?;
      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        if (!mounted) return;
        final paid = await startFedaPayCheckout(
          context,
          marketplace: widget.marketplace,
          checkoutUrl: checkoutUrl,
          transactionId: payload['transaction_id'] as String?,
        );
        if (!mounted) return;
        showToast(
          context,
          paid ? 'Flottant rechargé.' : 'Paiement non confirmé.',
          isError: !paid,
        );
      } else if (mounted) {
        showToast(context, 'Flottant rechargé.');
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _floatBusy = false);
    }
  }

  Future<void> _showPayoutHistory() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _PayoutHistorySheet(payouts: _payouts),
    );
  }

  void _showHelp() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) =>
          _HelpSheet(minPayout: _minPayout, commissionRate: _commissionRate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RestaurantPalette.background,
      child: Column(
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
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      color: RestaurantPalette.orange,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _stagger(0, _PageHeader(onHelp: _showHelp)),
          const SizedBox(height: 16),
          _stagger(
            1,
            _BalanceBanner(
              available: _available,
              pending: _pending,
              hidden: _hideAmounts,
              currency: _displayCurrency,
              eurRate: _eurRate,
              withdrawBusy: _requesting,
              onToggleHidden: () =>
                  setState(() => _hideAmounts = !_hideAmounts),
              onWithdraw: _openPayoutSheet,
            ),
          ),
          const SizedBox(height: 14),
          _stagger(
            2,
            _EarningsCard(
              period: _earningsPeriod,
              periods: _earningsPeriods,
              series: _activeEarningsSeries,
              comparisonLabel: _periodComparisonLabels[_earningsPeriod],
              displayCurrency: _displayCurrency,
              eurRate: _eurRate,
              hidden: _hideAmounts,
              onPeriod: (period) => setState(() => _earningsPeriod = period),
            ),
          ),
          const SizedBox(height: 14),
          _stagger(
            3,
            _CurrencyWidget(
              available: _available,
              rate: _eurRate,
              selected: _displayCurrency,
              hidden: _hideAmounts,
              onSelect: (currency) =>
                  setState(() => _displayCurrency = currency),
            ),
          ),
          const SizedBox(height: 14),
          _stagger(
            4,
            _StatsGrid(
              pending: _pending,
              commissionTotal: _commissionTotal,
              commissionRate: _commissionRate,
              minPayout: _minPayout,
            ),
          ),
          const SizedBox(height: 14),
          _stagger(
            5,
            _FloatCard(
              balance: _floatBalance,
              busy: _floatBusy,
              onTopUp: _openFloatSheet,
            ),
          ),
          const SizedBox(height: 14),
          _stagger(
            6,
            _MovementsCard(
              tabs: const ['Mouvements', 'Retraits'],
              selected: _tab,
              onSelect: (i) => setState(() => _tab = i),
              transactions: _tab == 0 ? _transactions : const [],
              payouts: _tab == 1 ? _payouts : const [],
              onSeeAllPayouts: _showPayoutHistory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stagger(int i, Widget child) => AnimatedBuilder(
    animation: _entrance,
    builder: (context, _) {
      final t = Curves.easeOutCubic.transform(
        (_entrance.value - i * 0.08).clamp(0.0, 1.0),
      );
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      );
    },
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onHelp});
  final VoidCallback onHelp;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Portefeuille',
                style: TextStyle(
                  color: RestaurantPalette.darkText,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Gérez vos fonds, commissions et retraits',
                style: TextStyle(
                  color: RestaurantPalette.grayText,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        _Pressable(
          onTap: onHelp,
          borderRadius: BorderRadius.circular(20),
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
                Icon(
                  Icons.help_outline_rounded,
                  size: 15,
                  color: RestaurantPalette.orange,
                ),
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

class _BalanceBanner extends StatelessWidget {
  const _BalanceBanner({
    required this.available,
    required this.pending,
    required this.hidden,
    required this.currency,
    required this.eurRate,
    required this.onToggleHidden,
    required this.onWithdraw,
    this.withdrawBusy = false,
  });
  final int available;
  final int pending;
  final bool hidden;
  final _DisplayCurrency currency;
  final double eurRate;
  final bool withdrawBusy;
  final VoidCallback onToggleHidden;
  final VoidCallback onWithdraw;
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
          // Visuels « food » en filigrane derrière la barrière du portefeuille :
          // le bol se fond sur la droite, les herbes effleurent le coin gauche.
          Positioned(
            top: 0,
            bottom: 0,
            right: -26,
            width: 176,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.42,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.white, Colors.white],
                    stops: [0.0, 0.62, 1.0],
                  ).createShader(bounds),
                  child: Image.asset(
                    FoodDecor.bowlAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerRight,
                    cacheWidth: 480,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -26,
            top: -30,
            width: 130,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.16,
                child: Image.asset(
                  FoodDecor.herbsAsset,
                  fit: BoxFit.contain,
                  cacheWidth: 320,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
                Icons.moped_rounded,
                size: 132,
                color: Colors.white.withValues(alpha: 0.06),
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
                        child: Icon(
                          hidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Text(
                        'Béninfood Pay',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                hidden
                    ? const Text(
                        '••• •••',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _moneyText(available, currency, eurRate),
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
                          Text(
                            _moneySymbol(currency),
                            style: const TextStyle(
                              color: Color(0xFFD6EBDD),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: _WalletColors.mint,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        currency == _DisplayCurrency.eur
                            ? 'Équivalent indicatif — retraits versés en FCFA'
                            : 'Retirable vers votre Mobile Money',
                        style: const TextStyle(
                          color: _WalletColors.mint,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
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
                          onTap: withdrawBusy
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  onWithdraw();
                                },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF8A3D),
                                  RestaurantPalette.orange,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: RestaurantPalette.orange.withValues(
                                    alpha: 0.42,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (withdrawBusy)
                                  const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 17,
                                    color: Colors.white,
                                  ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    withdrawBusy
                                        ? 'Demande en cours…'
                                        : 'Faire un retrait',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
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
                              : _moneyText(pending, currency, eurRate),
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

/// Carte des gains : total du jour, de la semaine ou du mois et tendance.
class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.period,
    required this.periods,
    required this.series,
    required this.comparisonLabel,
    required this.displayCurrency,
    required this.eurRate,
    required this.hidden,
    required this.onPeriod,
  });

  final int period;
  final Map<String, dynamic> periods;
  final List<Map<String, dynamic>> series;
  final String comparisonLabel;
  final _DisplayCurrency displayCurrency;
  final double eurRate;
  final bool hidden;
  final ValueChanged<int> onPeriod;

  @override
  Widget build(BuildContext context) {
    final data =
        (periods[_periodKeys[period]] as Map<String, dynamic>?) ?? const {};
    final earnings = (data['earnings'] as num?)?.toInt() ?? 0;
    final missions = (data['missions'] as num?)?.toInt() ?? 0;
    final comparison = (data['comparison'] as num?)?.toDouble();
    final values = [
      for (final point in series)
        displayCurrency == _DisplayCurrency.eur
            ? ((point['earnings'] as num?)?.toDouble() ?? 0) / eurRate
            : (point['earnings'] as num?)?.toDouble() ?? 0,
    ];
    final labels = [
      for (final point in series) (point['label'] ?? '').toString(),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: RestaurantPalette.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _WalletColors.greenWash,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  size: 19,
                  color: RestaurantPalette.success,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gains',
                      style: TextStyle(
                        color: RestaurantPalette.darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Vos revenus encaissés',
                      style: TextStyle(
                        color: RestaurantPalette.grayText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _ComparisonPill(
                value: comparison,
                label: comparisonLabel,
                hidden: hidden,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _periodLabels[period].toUpperCase(),
                      style: const TextStyle(
                        color: RestaurantPalette.grayText,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (hidden)
                      const Text(
                        '•••',
                        style: TextStyle(
                          color: RestaurantPalette.darkText,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: earnings.toDouble(),
                              ),
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) => FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _moneyText(
                                    value.round(),
                                    displayCurrency,
                                    eurRate,
                                  ),
                                  style: const TextStyle(
                                    color: RestaurantPalette.darkText,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _moneySymbol(displayCurrency),
                            style: const TextStyle(
                              color: RestaurantPalette.grayText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: RestaurantPalette.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'MISSIONS',
                      style: TextStyle(
                        color: RestaurantPalette.grayText,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hidden ? '•••' : '$missions',
                      style: const TextStyle(
                        color: RestaurantPalette.darkText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PeriodSelector(selected: period, onSelect: onPeriod),
          const SizedBox(height: 10),
          if (series.isEmpty)
            const SizedBox(
              height: 72,
              child: Center(
                child: Text(
                  'Aucun gain sur cette période',
                  style: TextStyle(
                    color: RestaurantPalette.grayText,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            StatTrendChart(
              values: values,
              labels: labels,
              color: RestaurantPalette.orange,
              height: 92,
              valueFormatter: (value) => formatCompactAmount(value),
            ),
        ],
      ),
    );
  }
}

class _ComparisonPill extends StatelessWidget {
  const _ComparisonPill({
    required this.value,
    required this.label,
    required this.hidden,
  });

  final double? value;
  final String label;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final showValue = !hidden && value != null;
    final positive = (value ?? 0) >= 0;
    final accent = positive
        ? RestaurantPalette.success
        : RestaurantPalette.danger;
    final background = positive
        ? _WalletColors.greenWash
        : const Color(0xFFFDECEC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: showValue ? background : const Color(0xFFF4F5F2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                showValue
                    ? (positive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded)
                    : Icons.remove_rounded,
                size: 13,
                color: showValue ? accent : RestaurantPalette.grayText,
              ),
              const SizedBox(width: 3),
              Text(
                showValue
                    ? '${positive ? '+' : ''}${value!.toStringAsFixed(1).replaceAll('.', ',')} %'
                    : '—',
                style: TextStyle(
                  color: showValue ? accent : RestaurantPalette.grayText,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: RestaurantPalette.grayText,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _periodLabels.length; i++)
            Expanded(
              child: _Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(i);
                },
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == i ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: selected == i
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _periodLabels[i],
                    style: TextStyle(
                      color: selected == i
                          ? RestaurantPalette.darkText
                          : RestaurantPalette.grayText,
                      fontSize: 12,
                      fontWeight: selected == i
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Carte « billets » : solde du portefeuille lisible en FCFA et en euros.
class _CurrencyWidget extends StatelessWidget {
  const _CurrencyWidget({
    required this.available,
    required this.rate,
    required this.selected,
    required this.hidden,
    required this.onSelect,
  });

  final int available;
  final double rate;
  final _DisplayCurrency selected;
  final bool hidden;
  final ValueChanged<_DisplayCurrency> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: RestaurantPalette.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _WalletColors.blueWash,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.currency_exchange_rounded,
                  size: 19,
                  color: _WalletColors.navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Devises',
                      style: TextStyle(
                        color: RestaurantPalette.darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '1 € = ${rate.toStringAsFixed(3).replaceAll('.', ',')} FCFA · parité fixe',
                      style: const TextStyle(
                        color: RestaurantPalette.grayText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BanknoteCard(
                  code: 'FCFA',
                  label: 'Solde disponible',
                  amount: hidden
                      ? '•••'
                      : formatAmount(available, showSymbol: false),
                  icon: Icons.payments_rounded,
                  colors: const [Color(0xFF12945B), Color(0xFF0B5C39)],
                  selected: selected == _DisplayCurrency.xof,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(_DisplayCurrency.xof);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BanknoteCard(
                  code: 'EUR',
                  label: 'Équivalent indicatif',
                  amount: hidden
                      ? '•••'
                      : formatEuroFromXof(available, rate: rate),
                  icon: Icons.euro_rounded,
                  colors: const [Color(0xFF2C6BB0), Color(0xFF153E6B)],
                  selected: selected == _DisplayCurrency.eur,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(_DisplayCurrency.eur);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: RestaurantPalette.grayText,
              ),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Conversion indicative à l\'affichage : les retraits sont versés en FCFA.',
                  style: TextStyle(
                    color: RestaurantPalette.grayText,
                    fontSize: 10.5,
                    height: 1.3,
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

class _BanknoteCard extends StatelessWidget {
  const _BanknoteCard({
    required this.code,
    required this.label,
    required this.amount,
    required this.icon,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final String amount;
  final IconData icon;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedScale(
        scale: selected ? 1 : 0.97,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 112,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.18),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _BanknotePainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
                          size: 17,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          code,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        AnimatedOpacity(
                          opacity: selected ? 1 : 0.35,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        amount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

/// Motifs discrets de billet (cercles et lignes guillochées).
class _BanknotePainter extends CustomPainter {
  const _BanknotePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.13);
    final center = Offset(size.width * 0.84, size.height * 0.42);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, size.width * 0.11 * i, line);
    }

    final wave = Path()..moveTo(0, size.height * 0.74);
    final step = size.width / 8;
    for (var x = 0.0; x <= size.width; x += step) {
      wave.quadraticBezierTo(
        x + step / 2,
        size.height * 0.66,
        x + step,
        size.height * 0.74,
      );
    }
    canvas.drawPath(wave, line);
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      line,
    );
  }

  @override
  bool shouldRepaint(_BanknotePainter oldDelegate) => false;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.pending,
    required this.commissionTotal,
    required this.commissionRate,
    required this.minPayout,
  });
  final int pending, commissionTotal, commissionRate, minPayout;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.hourglass_bottom_rounded,
            tint: _WalletColors.orangeWash,
            accent: RestaurantPalette.orange,
            label: 'En attente',
            value: formatAmount(pending, showSymbol: false),
            caption: 'Non encaissées',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.percent_rounded,
            tint: _WalletColors.goldWash,
            accent: _WalletColors.goldDark,
            label: 'Commissions',
            value: formatAmount(commissionTotal, showSymbol: false),
            caption: '$commissionRate % prélevé',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.south_west_rounded,
            tint: _WalletColors.greenWash,
            accent: RestaurantPalette.success,
            label: 'Retrait min.',
            value: formatAmount(minPayout, showSymbol: false),
            caption: 'FCFA',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.tint,
    required this.accent,
    required this.label,
    required this.value,
    required this.caption,
  });
  final IconData icon;
  final Color tint, accent;
  final String label, value, caption;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(height: 9),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent.withValues(alpha: 0.9),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent.withValues(alpha: 0.75),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatCard extends StatelessWidget {
  const _FloatCard({
    required this.balance,
    required this.busy,
    required this.onTopUp,
  });
  final int balance;
  final bool busy;
  final VoidCallback onTopUp;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _WalletColors.goldWash,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _WalletColors.gold.withValues(alpha: 0.4)),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _WalletColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_rounded,
              size: 20,
              color: _WalletColors.goldDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flottant espèces',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: RestaurantPalette.darkText,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  formatAmount(balance),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _WalletColors.goldDark,
                  ),
                ),
              ],
            ),
          ),
          _Pressable(
            onTap: busy ? null : onTopUp,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _WalletColors.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  const SizedBox(width: 6),
                  const Text(
                    'Recharger',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
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
}

class _MovementsCard extends StatelessWidget {
  const _MovementsCard({
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.transactions,
    required this.payouts,
    required this.onSeeAllPayouts,
  });
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> payouts;
  final VoidCallback onSeeAllPayouts;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tabs[selected],
                    style: const TextStyle(
                      color: RestaurantPalette.darkText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selected == 1 && payouts.isNotEmpty)
                  TextButton(
                    onPressed: onSeeAllPayouts,
                    child: const Text(
                      'Voir tout',
                      style: TextStyle(
                        color: RestaurantPalette.orange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++) ...[
                  Expanded(
                    child: _TabButton(
                      label: tabs[i],
                      active: selected == i,
                      onTap: () => onSelect(i),
                    ),
                  ),
                  if (i != tabs.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (selected == 0)
            _TransactionsList(transactions: transactions)
          else
            _PayoutsList(payouts: payouts),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? RestaurantPalette.orange.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? RestaurantPalette.orange
                : RestaurantPalette.borderColor,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? RestaurantPalette.orange
                : RestaurantPalette.grayText,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TransactionsList extends StatelessWidget {
  const _TransactionsList({required this.transactions});
  final List<Map<String, dynamic>> transactions;
  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: _EmptyInline(
          icon: Icons.receipt_long_outlined,
          message: 'Aucun mouvement pour le moment',
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < transactions.take(10).length; i++) ...[
          _TransactionTile(tx: transactions[i]),
          if (i != transactions.take(10).length - 1)
            const Divider(
              height: 1,
              indent: 62,
              color: RestaurantPalette.borderColor,
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});
  final Map<String, dynamic> tx;
  @override
  Widget build(BuildContext context) {
    final isCredit = (tx['type'] ?? 'credit') == 'credit';
    final amount = (tx['amount'] as num?)?.toInt() ?? 0;
    final description = (tx['description'] as String?)?.trim();
    final createdAt = tx['created_at'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isCredit
                  ? _WalletColors.greenWash
                  : _WalletColors.orangeWash,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 19,
              color: isCredit
                  ? RestaurantPalette.success
                  : RestaurantPalette.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description?.isNotEmpty == true
                      ? description!
                      : (isCredit ? 'Crédit' : 'Débit'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: RestaurantPalette.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateLabel(createdAt),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: RestaurantPalette.grayText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${isCredit ? '+' : '-'}${formatAmount(amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isCredit
                  ? RestaurantPalette.success
                  : RestaurantPalette.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutsList extends StatelessWidget {
  const _PayoutsList({required this.payouts});
  final List<Map<String, dynamic>> payouts;
  @override
  Widget build(BuildContext context) {
    if (payouts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: _EmptyInline(
          icon: Icons.savings_outlined,
          message: 'Aucun retrait pour le moment',
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < payouts.take(5).length; i++) ...[
          _PayoutTile(payout: payouts[i]),
          if (i != payouts.take(5).length - 1)
            const Divider(
              height: 1,
              indent: 16,
              color: RestaurantPalette.borderColor,
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout});
  final Map<String, dynamic> payout;
  @override
  Widget build(BuildContext context) {
    final status = (payout['status'] ?? '').toString();
    final palette = _payoutPalette(status);
    final amount = (payout['amount'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatAmount(amount),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: RestaurantPalette.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateLabel(payout['created_at'] as String?),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: RestaurantPalette.grayText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.$2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              palette.$1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: palette.$3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

(String, Color, Color) _payoutPalette(String status) => switch (status) {
  'executed' => ('Versé', _WalletColors.greenWash, RestaurantPalette.success),
  'failed' => ('Échec', const Color(0xFFFDECEC), RestaurantPalette.danger),
  'processing' => ('En cours', _WalletColors.goldWash, _WalletColors.goldDark),
  _ => ('En attente', _WalletColors.orangeWash, RestaurantPalette.orange),
};

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RestaurantPalette.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: RestaurantPalette.grayText),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              color: RestaurantPalette.grayText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(String? iso) => formatDateTime(iso, fallback: '');

String _moneyText(int amount, _DisplayCurrency currency, double rate) =>
    currency == _DisplayCurrency.xof
    ? formatAmount(amount, showSymbol: false)
    : formatEuroFromXof(amount, rate: rate, showSymbol: false);

String _moneySymbol(_DisplayCurrency currency) =>
    currency == _DisplayCurrency.xof ? 'FCFA' : '€';

class _PayoutHistorySheet extends StatelessWidget {
  const _PayoutHistorySheet({required this.payouts});
  final List<Map<String, dynamic>> payouts;
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: RestaurantPalette.borderColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Historique des retraits',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: RestaurantPalette.darkText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Suivez le statut de vos demandes',
            style: TextStyle(fontSize: 12.5, color: RestaurantPalette.grayText),
          ),
          const SizedBox(height: 16),
          if (payouts.isEmpty)
            const _EmptyInline(
              icon: Icons.savings_outlined,
              message: 'Aucun retrait pour le moment',
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: payouts.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  color: RestaurantPalette.borderColor,
                ),
                itemBuilder: (context, index) {
                  final payout = payouts[index];
                  final status = (payout['status'] ?? '').toString();
                  final palette = _payoutPalette(status);
                  final amount = (payout['amount'] as num?)?.toInt() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatAmount(amount),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: RestaurantPalette.darkText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _dateLabel(payout['created_at'] as String?),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: RestaurantPalette.grayText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.$2,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            palette.$1,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: palette.$3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet({required this.minPayout, required this.commissionRate});
  final int minPayout, commissionRate;
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: RestaurantPalette.borderColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aide - Portefeuille livreur',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: RestaurantPalette.darkText,
            ),
          ),
          const SizedBox(height: 12),
          _HelpRow(
            icon: Icons.south_west_rounded,
            title: 'Retrait minimum',
            value: '${formatAmount(minPayout)} par demande',
          ),
          _HelpRow(
            icon: Icons.percent_rounded,
            title: 'Commission plateforme',
            value: '$commissionRate % prélevée sur le prix de livraison',
          ),
          _HelpRow(
            icon: Icons.payments_rounded,
            title: 'Flottant espèces',
            value: 'À recharger pour honorer les commandes cash',
          ),
          _HelpRow(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Solde disponible',
            value: 'Montant retirable vers votre Mobile Money',
          ),
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title, value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _WalletColors.orangeWash,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: RestaurantPalette.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: RestaurantPalette.darkText,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: RestaurantPalette.grayText,
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

class _FloatSheet extends StatefulWidget {
  const _FloatSheet();
  @override
  State<_FloatSheet> createState() => _FloatSheetState();
}

class _FloatSheetState extends State<_FloatSheet> {
  final _amount = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_amount.text.trim());
    if (value == null || value < 100) {
      setState(() => _error = 'Montant minimum : ${formatAmount(100)}.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: RestaurantPalette.borderColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recharger le flottant',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: RestaurantPalette.darkText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Paiement sécurisé FedaPay - crédité après confirmation',
            style: TextStyle(fontSize: 12.5, color: RestaurantPalette.grayText),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              labelText: 'Montant (F CFA)',
              prefixIcon: const Icon(Icons.payments_outlined),
              suffixText: 'FCFA',
              errorText: _error,
              hintText: 'Minimum 100',
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: RestaurantPalette.borderColor,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: RestaurantPalette.borderColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: RestaurantPalette.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Recharger',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _pressed = false),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
