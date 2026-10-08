import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order.dart';
import '../restaurant_palette.dart';

/// Écran « E. REVENUS » : résumé du mois (solde wallet, ventes validées,
/// commission, attente de reversement) et dernières transactions, calculés
/// dynamiquement à partir des commandes du vendeur (mois courant), avec
/// tirer-pour-recharger et état vide.
class RevenusScreen extends StatelessWidget {
  const RevenusScreen({
    super.key,
    required this.orders,
    this.onOpenDrawer,
    this.onMonthTap,
    this.onSeeAllTap,
    this.onRefresh,
  });

  /// Commandes du vendeur (source de vérité gérée par le shell).
  final List<Order> orders;

  final VoidCallback? onOpenDrawer;
  final VoidCallback? onMonthTap;
  final VoidCallback? onSeeAllTap;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final monthOrders = _monthOrders();
    final (summary, transactions, orderCount) = _compute(monthOrders);

    return Material(
      color: RestaurantPalette.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => onRefresh?.call(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    _buildMainCard(summary, transactions, orderCount),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Commandes du mois courant ; les commandes de moins de 24 h comptent
  /// aussi (ordre de début de mois qui bascule sur le mois écoulé).
  List<Order> _monthOrders() {
    final now = DateTime.now();
    final recent = now.subtract(const Duration(hours: 24));
    return orders.where((o) {
      final created = DateTime.tryParse(o.createdAt ?? '');
      if (created == null) return true;
      return (created.year == now.year && created.month == now.month) ||
          created.isAfter(recent);
    }).toList();
  }

  /// Résumé du mois + dernières transactions dérivés des commandes :
  /// commission de 10 %, solde correspondant aux livraisons encaissées.
  (RevenuSummary, List<RevenuTransaction>, int) _compute(
      List<Order> monthOrders) {
    var validated = 0;
    var pending = 0;
    var delivered = 0;
    var completed = 0;
    final transactions = <RevenuTransaction>[];
    final sorted = [...monthOrders];
    sorted.sort((a, b) => _compareDates(a.createdAt, b.createdAt));

    for (final o in sorted) {
      final status = o.status;
      if (status == 'cancelled' || status == 'refunded') {
        continue;
      }
      if (status == 'awaiting_payment') {
        pending += o.total;
        continue;
      }
      validated += o.total;
      completed++;
      if (status == 'delivered') {
        delivered += o.total;
      }
      if (status == 'paid' ||
          status == 'accepted' ||
          status == 'preparing' ||
          status == 'ready' ||
          status == 'assigned' ||
          status == 'picked_up' ||
          status == 'in_delivery') {
        pending += o.total;
      }
      final time = _txLabel(o.createdAt);
      transactions.add(RevenuTransaction(
        label: 'Vente ${o.reference}',
        dateLabel: time,
        amount: o.total,
        type: RevenuTransactionType.sale,
      ));
      transactions.add(RevenuTransaction(
        label: 'Commission',
        dateLabel: time,
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
      transactions.take(6).toList(),
      completed,
    );
  }

  Widget _buildHeader() {
    return Material(
      color: RestaurantPalette.white,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, right: 16, top: 8, bottom: 10),
        child: Row(
          children: [
            if (onOpenDrawer != null)
              IconButton(
                onPressed: onOpenDrawer,
                icon: const Icon(Icons.menu, color: RestaurantPalette.darkText),
                tooltip: 'Ouvrir le menu',
              )
            else
              const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'E. REVENUS',
                style: TextStyle(
                  color: RestaurantPalette.forest,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(
    RevenuSummary summary,
    List<RevenuTransaction> transactions,
    int orderCount,
  ) {
    final subtitle = orderCount > 0
        ? '$orderCount commande${orderCount > 1 ? 's' : ''} ce mois-ci'
        : null;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Revenus',
                    style: TextStyle(
                      color: RestaurantPalette.darkText,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MonthSelector(onTap: onMonthTap),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: RestaurantPalette.grayText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 18),
            _SummaryRow(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: RestaurantPalette.success,
              label: 'Solde wallet',
              value: formatAmount(summary.walletBalance),
            ),
            const Divider(height: 22, indent: 56, color: RestaurantPalette.borderColor),
            _SummaryRow(
              icon: Icons.south_west,
              iconColor: RestaurantPalette.success,
              label: 'Ventes validées',
              value: formatAmount(summary.validatedSales),
            ),
            const Divider(height: 22, indent: 56, color: RestaurantPalette.borderColor),
            _SummaryRow(
              icon: Icons.percent,
              iconColor: RestaurantPalette.grayText,
              label: 'Commission prélevée',
              value: formatAmount(summary.commission),
            ),
            const Divider(height: 22, indent: 56, color: RestaurantPalette.borderColor),
            _SummaryRow(
              icon: Icons.access_time,
              iconColor: RestaurantPalette.grayText,
              label: 'En attente de reversement',
              value: formatAmount(summary.pendingPayout),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1.5, color: RestaurantPalette.borderColor),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Dernières transactions',
                    style: TextStyle(
                      color: RestaurantPalette.darkText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onSeeAllTap,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Text(
                      'Voir tout',
                      style: TextStyle(
                        color: RestaurantPalette.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (transactions.isEmpty)
              const _EmptyTransactions()
            else
              for (final tx in transactions) ...[
                _TransactionRow(tx),
                if (tx != transactions.last)
                  const Divider(height: 1, indent: 56, color: RestaurantPalette.borderColor),
              ],
          ],
        ),
      ),
    );
  }

  static int _compareDates(String? a, String? b) {
    final da = DateTime.tryParse(a ?? '');
    final db = DateTime.tryParse(b ?? '');
    if (da == null || db == null) return 0;
    return db.compareTo(da);
  }
}

/// État vide des transactions : aucun encaissement ce mois-ci.
class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 36,
            color: RestaurantPalette.orange,
          ),
          const SizedBox(height: 10),
          const Text(
            'Aucune transaction ce mois-ci.',
            style: TextStyle(
              color: RestaurantPalette.darkText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Les ventes validées apparaîtront ici dès leur encaissement.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RestaurantPalette.grayText,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur de mois (« Octobre 2026 › ») : cliquable, la logique de
/// changement de période n'est pas encore branchée.
class _MonthSelector extends StatelessWidget {
  const _MonthSelector({this.onTap});

  final VoidCallback? onTap;

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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = '${_months[now.month - 1]} ${now.year}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RestaurantPalette.orange,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: RestaurantPalette.orange,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: RestaurantPalette.background,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne d'une transaction : montants positifs en vert, négatifs en rouge.
class _TransactionRow extends StatelessWidget {
  const _TransactionRow(this.transaction);

  final RevenuTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: RestaurantPalette.background,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(transaction.icon, size: 20, color: transaction.iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RestaurantPalette.grayText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            transaction.amountText,
            style: TextStyle(
              color: transaction.amountColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Résumé mensuel des revenus du vendeur.
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

/// Une transaction du relevé : vente encaissée (positive) ou commission.
class RevenuTransaction {
  const RevenuTransaction({
    required this.label,
    required this.dateLabel,
    required this.amount,
    required this.type,
  });

  final String label;
  final String dateLabel;

  /// Montant signé : positif pour une vente, négatif pour une commission.
  final int amount;
  final RevenuTransactionType type;

  IconData get icon => type == RevenuTransactionType.sale
      ? Icons.south_west
      : Icons.percent;

  Color get iconColor => type == RevenuTransactionType.sale
      ? RestaurantPalette.success
      : RestaurantPalette.grayText;

  Color get amountColor =>
      amount >= 0 ? RestaurantPalette.success : RestaurantPalette.danger;

  String get amountText {
    final sign = amount >= 0 ? '+' : '-';
    return '$sign${formatAmount(amount.abs())}';
  }
}

/// Libellé de date d'une transaction : « Aujourd'hui, 11:30 » ou « 08/10 09:15 ».
String _txLabel(String? iso) {
  final date = DateTime.tryParse(iso ?? '')?.toLocal();
  if (date == null) return '';
  final now = DateTime.now();
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  final sameDay =
      date.year == now.year && date.month == now.month && date.day == now.day;
  return sameDay ? "Aujourd'hui, $time" : '${date.day}/${date.month} $time';
}