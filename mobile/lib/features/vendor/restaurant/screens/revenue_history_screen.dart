import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/formatters.dart';
import '../restaurant_palette.dart';

/// Historique complet des revenus du vendeur (J21 §3.5) : toutes les écritures
/// de la période, les reversements (payouts) et l'export CSV du relevé courant.
class RevenueHistoryScreen extends StatelessWidget {
  const RevenueHistoryScreen({super.key, required this.revenue});

  final Map<String, dynamic> revenue;

  @override
  Widget build(BuildContext context) {
    final transactions = (revenue['transactions'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
    final payouts =
        (revenue['payouts'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const <Map<String, dynamic>>[];

    return Material(
      color: RestaurantPalette.background,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildSummaryCard(context),
                  const SizedBox(height: 12),
                  _buildSectionTitle('Écritures (${transactions.length})'),
                  const SizedBox(height: 8),
                  if (transactions.isEmpty)
                    const _EmptyHint('Aucune écriture sur la période.')
                  else
                    _buildTransactionsCard(transactions),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Reversements (${payouts.length})'),
                  const SizedBox(height: 8),
                  if (payouts.isEmpty)
                    const _EmptyHint('Aucun reversement enregistré.')
                  else
                    _buildPayoutsCard(payouts),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Material(
      color: RestaurantPalette.white,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 8, top: 6, bottom: 10),
        child: Row(
          children: [
            const BackButton(),
            const Expanded(
              child: Text(
                'Historique des revenus',
                style: TextStyle(
                  color: RestaurantPalette.forest,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Exporter en CSV',
              onPressed: () => _exportCsv(context, transactions: revenue['transactions']),
              icon: const Icon(Icons.download_outlined, color: RestaurantPalette.orange),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    int amount(String key) => (revenue[key] as num?)?.toInt() ?? 0;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SummaryLine(label: 'Ventes validées', value: formatAmount(amount('gross_sales'))),
            _SummaryLine(label: 'Commission prélevée', value: formatAmount(amount('commission'))),
            _SummaryLine(label: 'Solde disponible', value: formatAmount(amount('available_balance'))),
            _SummaryLine(label: 'En attente de reversement', value: formatAmount(amount('pending_amount'))),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          color: RestaurantPalette.darkText,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      );

  Widget _buildTransactionsCard(List<Map<String, dynamic>> transactions) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < transactions.length; i++) ...[
              _TransactionTile(transaction: transactions[i]),
              if (i != transactions.length - 1)
                const Divider(height: 1, color: RestaurantPalette.borderColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutsCard(List<Map<String, dynamic>> payouts) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < payouts.length; i++) ...[
              _PayoutTile(payout: payouts[i]),
              if (i != payouts.length - 1)
                const Divider(height: 1, color: RestaurantPalette.borderColor),
            ],
          ],
        ),
      ),
    );
  }

  void _exportCsv(BuildContext context, {dynamic transactions}) {
    final rows = (transactions as List?)?.whereType<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final buffer = StringBuffer('date;reference;brut;commission;net\n');
    for (final row in rows) {
      buffer.writeln(
        '${row['date'] ?? ''};${row['reference'] ?? ''};${row['gross'] ?? 0};'
        '${row['commission'] ?? 0};${row['net'] ?? 0}',
      );
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Relevé CSV copié dans le presse-papiers.')),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 13.5)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: RestaurantPalette.darkText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final Map<String, dynamic> transaction;

  @override
  Widget build(BuildContext context) {
    final net = (transaction['net'] as num?)?.toInt() ?? 0;
    final commission = (transaction['commission'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vente ${transaction['reference'] ?? ''}'.trim(),
                  style: const TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Brut ${formatAmount((transaction['gross'] as num?)?.toInt() ?? 0)} · '
                  'Commission ${formatAmount(commission)}',
                  style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${formatAmount(net)}',
            style: const TextStyle(
              color: RestaurantPalette.success,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout});

  final Map<String, dynamic> payout;

  @override
  Widget build(BuildContext context) {
    final status = (payout['status'] ?? '').toString();
    final executed = status == 'executed' || status == 'paid';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            executed ? Icons.check_circle_outline : Icons.schedule,
            size: 20,
            color: executed ? RestaurantPalette.success : RestaurantPalette.grayText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _methodLabel(payout['method'] as String?),
              style: const TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '-${formatAmount((payout['amount'] as num?)?.toInt() ?? 0)}',
            style: TextStyle(
              color: executed ? RestaurantPalette.darkText : RestaurantPalette.grayText,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _methodLabel(String? method) {
    switch (method) {
      case 'bank':
        return 'Virement bancaire';
      case 'mobile_money':
        return 'Mobile Money';
      case 'cash':
        return 'Espèces';
      case null:
      case '':
        return 'Reversement';
      default:
        return method;
    }
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: RestaurantPalette.cardDecoration,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 13),
      ),
    );
  }
}
