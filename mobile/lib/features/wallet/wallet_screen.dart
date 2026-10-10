import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/marketplace_api.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/feedback_widgets.dart';
import '../../shared/widgets/state_widgets.dart';

/// Rôle propriétaire du wallet : le libellé et les endpoints diffèrent.
enum WalletRole { vendor, driver }

/// Écran **Wallet & retraits** — vendeur ou livreur (cahier de conception v1.0).
///
/// Design premium : carte gradient avec solde disponible, séquestre « en
/// attente », demande de retrait vers Mobile Money et journal des mouvements.
/// Les données proviennent de `GET /{vendors|driver}/me/wallet[/payouts]`.
class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.marketplace,
    required this.role,
    this.onOpenDrawer,
  });

  final MarketplaceApi marketplace;
  final WalletRole role;
  final VoidCallback? onOpenDrawer;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic> _wallet = const {};
  List<Map<String, dynamic>> _payouts = const [];
  bool _loading = true;
  String? _error;
  bool _requesting = false;

  int get _pending => (_wallet['pending_balance'] as num?)?.toInt() ?? 0;
  int get _available => (_wallet['available_balance'] as num?)?.toInt() ?? 0;
  int get _minPayout => (_wallet['min_payout'] as num?)?.toInt() ?? 1000;

  List<Map<String, dynamic>> get _transactions =>
      (_wallet['transactions'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallet = widget.role == WalletRole.vendor
          ? await widget.marketplace.vendorWallet()
          : await widget.marketplace.driverWallet();
      List<Map<String, dynamic>> payouts = const [];
      if (widget.role == WalletRole.vendor) {
        try {
          payouts = await widget.marketplace.vendorPayouts();
        } on ApiException {
          payouts = const [];
        }
      }
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
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

    final result = await showModalBottomSheet<_PayoutRequest>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PayoutSheet(
        available: _available,
        minPayout: _minPayout,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _requesting = true);
    try {
      if (widget.role == WalletRole.vendor) {
        await widget.marketplace.requestVendorPayout(result.amount, method: result.method);
      } else {
        await widget.marketplace.requestDriverPayout(result.amount, method: result.method);
      }
      if (!mounted) return;
      showToast(context, 'Demande de retrait envoyée.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.role == WalletRole.vendor ? 'Portefeuille' : 'Mes gains';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(title: title, onOpenDrawer: widget.onOpenDrawer),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          AppDimens.md,
          AppDimens.pagePadding,
          AppDimens.xxl,
        ),
        children: [
          _BalanceCard(
            available: _available,
            pending: _pending,
            busy: _requesting,
            onWithdraw: _openPayoutSheet,
          ),
          const SizedBox(height: AppDimens.lg),
          _QuickFacts(minPayout: _minPayout, role: widget.role),
          const SizedBox(height: AppDimens.xl),
          _SectionTitle(
            title: 'Mouvements',
            subtitle: 'Séquestres libérés, commissions et retraits',
          ),
          const SizedBox(height: AppDimens.sm),
          if (_transactions.isEmpty)
            const _EmptyCard(
              icon: Icons.receipt_long_outlined,
              message: 'Aucun mouvement pour le moment.',
            )
          else
            _TransactionsCard(transactions: _transactions),
          const SizedBox(height: AppDimens.xl),
          _SectionTitle(title: 'Retraits', subtitle: 'Historique des demandes'),
          const SizedBox(height: AppDimens.sm),
          if (_payouts.isEmpty)
            const _EmptyCard(
              icon: Icons.savings_outlined,
              message: 'Aucun retrait pour le moment.',
            )
          else
            _PayoutsCard(payouts: _payouts),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Header

class _Header extends StatelessWidget {
  const _Header({required this.title, this.onOpenDrawer});

  final String title;
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: AppDimens.lg, top: AppDimens.sm, bottom: AppDimens.sm),
      child: Row(
        children: [
          if (onOpenDrawer != null)
            IconButton(
              onPressed: onOpenDrawer,
              icon: const Icon(Icons.menu, color: AppColors.text),
              tooltip: 'Ouvrir le menu',
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Balance card

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.available,
    required this.pending,
    required this.busy,
    required this.onWithdraw,
  });

  final int available;
  final int pending;
  final bool busy;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F3D22), AppColors.green],
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        boxShadow: const [
          BoxShadow(color: Color(0x2618231F), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 21),
                ),
                const SizedBox(width: AppDimens.md),
                const Text(
                  'Solde disponible',
                  style: TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                ),
                const Spacer(),
                const _GoldDot(),
              ],
            ),
            const SizedBox(height: AppDimens.lg),
            Text(
              formatAmount(available),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Retirable vers votre Mobile Money',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12.5),
            ),
            const SizedBox(height: AppDimens.lg),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_bottom, size: 17, color: AppColors.gold),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'En attente de livraison',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    formatAmount(pending),
                    style: const TextStyle(color: AppColors.gold, fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.goldDark,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: busy ? null : onWithdraw,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.goldDark),
                      )
                    : const Icon(Icons.arrow_downward_rounded, size: 20),
                label: const Text('Retirer', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldDot extends StatelessWidget {
  const _GoldDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: const Text(
        'Béninfood Pay',
        style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    );
  }
}

// ------------------------------------------------------------- Quick facts

class _QuickFacts extends StatelessWidget {
  const _QuickFacts({required this.minPayout, required this.role});

  final int minPayout;
  final WalletRole role;

  @override
  Widget build(BuildContext context) {
    final commission = role == WalletRole.vendor ? '10 %' : '20 %';

    return Row(
      children: [
        Expanded(
          child: _FactCard(
            icon: Icons.south_west,
            tint: AppColors.greenLight,
            accent: AppColors.green,
            label: 'Retrait minimum',
            value: formatAmount(minPayout),
          ),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: _FactCard(
            icon: Icons.percent,
            tint: AppColors.orangeLight,
            accent: AppColors.orange,
            label: 'Commission',
            value: commission,
          ),
        ),
      ],
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({
    required this.icon,
    required this.tint,
    required this.accent,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color tint;
  final Color accent;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(11)),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(height: AppDimens.md),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Transactions

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.transactions});

  final List<Map<String, dynamic>> transactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        children: [
          for (var i = 0; i < transactions.length; i++) ...[
            _TransactionRow(tx: transactions[i]),
            if (i != transactions.length - 1)
              const Divider(height: 1, indent: 62, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.tx});

  final Map<String, dynamic> tx;

  @override
  Widget build(BuildContext context) {
    final isCredit = (tx['type'] ?? 'credit') == 'credit';
    final amount = (tx['amount'] as num?)?.toInt() ?? 0;
    final description = (tx['description'] as String?)?.trim();
    final createdAt = tx['created_at'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isCredit ? AppColors.greenLight : AppColors.orangeLight,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              isCredit ? Icons.south_west : Icons.north_east,
              size: 19,
              color: isCredit ? AppColors.green : AppColors.orangeDark,
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description?.isNotEmpty == true ? description! : (isCredit ? 'Crédit' : 'Débit'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateLabel(createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          Text(
            '${isCredit ? '+' : '-'}${formatAmount(amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isCredit ? AppColors.green : AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Payouts

class _PayoutsCard extends StatelessWidget {
  const _PayoutsCard({required this.payouts});

  final List<Map<String, dynamic>> payouts;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        children: [
          for (var i = 0; i < payouts.length; i++) ...[
            _PayoutRow(payout: payouts[i]),
            if (i != payouts.length - 1)
              const Divider(height: 1, indent: AppDimens.lg, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.payout});

  final Map<String, dynamic> payout;

  @override
  Widget build(BuildContext context) {
    final status = (payout['status'] ?? '').toString();
    final palette = _payoutPalette(status);
    final amount = (payout['amount'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatAmount(amount),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateLabel(payout['created_at'] as String?),
                  style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.$2,
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            ),
            child: Text(
              palette.$1,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: palette.$3),
            ),
          ),
        ],
      ),
    );
  }
}

(String, Color, Color) _payoutPalette(String status) => switch (status) {
      'executed' => ('Versé', AppColors.greenLight, AppColors.green),
      'failed' => ('Échec', AppColors.redLight, AppColors.red),
      'processing' => ('En cours', AppColors.goldLight, AppColors.goldDark),
      _ => ('En attente', AppColors.orangeLight, AppColors.orangeDark),
    };

// ------------------------------------------------------------ Section card

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.text),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppDimens.xl, horizontal: AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.orangeLight, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.orange, size: 26),
          ),
          const SizedBox(height: AppDimens.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Payout sheet

class _PayoutRequest {
  const _PayoutRequest({required this.amount, required this.method});

  final int amount;
  final String method;
}

class _PayoutSheet extends StatefulWidget {
  const _PayoutSheet({required this.available, required this.minPayout});

  final int available;
  final int minPayout;

  @override
  State<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends State<_PayoutSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.available.toString(),
  );
  String _method = 'mobile_money';
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_amount.text.trim());
    if (value == null || value < widget.minPayout) {
      setState(() => _error = 'Minimum ${formatAmount(widget.minPayout)}.');
      return;
    }
    if (value > widget.available) {
      setState(() => _error = 'Solde disponible insuffisant.');
      return;
    }
    Navigator.of(context).pop(_PayoutRequest(amount: value, method: _method));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppDimens.xl, AppDimens.lg, AppDimens.xl, AppDimens.xl + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          const Text(
            'Demander un retrait',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            'Disponible : ${formatAmount(widget.available)} · minimum ${formatAmount(widget.minPayout)}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.xl),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              labelText: 'Montant (F CFA)',
              prefixIcon: const Icon(Icons.payments_outlined),
              suffixText: 'FCFA',
              errorText: _error,
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          const Text(
            'Recevoir sur',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: AppDimens.sm),
          Row(
            children: [
              Expanded(child: _MethodChip(label: 'Mobile Money', value: 'mobile_money', selected: _method, onTap: (v) => setState(() => _method = v))),
              const SizedBox(width: AppDimens.md),
              Expanded(child: _MethodChip(label: 'Banque', value: 'bank', selected: _method, onTap: (v) => setState(() => _method = v))),
            ],
          ),
          const SizedBox(height: AppDimens.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Confirmer la demande'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orangeLight : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: isSelected ? AppColors.orange : AppColors.border, width: isSelected ? 1.6 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 18,
              color: isSelected ? AppColors.orange : AppColors.textFaint,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.orangeDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(String? iso) => formatDateTime(iso, fallback: '');
