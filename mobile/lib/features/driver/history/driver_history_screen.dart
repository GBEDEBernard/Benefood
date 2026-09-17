import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/delivery.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Historique des missions terminées du livreur (J162).
class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  List<Delivery> _deliveries = [];
  bool _loading = true;
  String? _error;

  static const _historyStatuses = {'delivered', 'cancelled', 'incident'};

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
      final deliveries = await widget.marketplace.myDeliveries();
      if (mounted) {
        setState(() {
          _deliveries = deliveries.where((d) => _historyStatuses.contains(d.status)).toList();
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_deliveries.isEmpty) {
      return const EmptyState(
        icon: Icons.history_outlined,
        title: 'Aucune mission terminée',
        subtitle: 'Vos livraisons passées apparaîtront ici.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _deliveries.length,
        itemBuilder: (context, index) => _HistoryCard(delivery: _deliveries[index]),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = BadgePalette.delivery(delivery.status);
    final reference = delivery.order?.reference ?? 'Mission';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(reference, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (palette != null)
                  StatusBadge(label: palette.$1, color: palette.$2, small: true),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  formatDateTime(delivery.createdAt, fallback: '—'),
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                AmountText(
                  delivery.partnerAmount ?? delivery.fee,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
