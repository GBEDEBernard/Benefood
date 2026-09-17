import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Détail d'une commande vendeur (J156) : articles, totaux, adresse, actions.
class VendorOrderDetailScreen extends StatefulWidget {
  const VendorOrderDetailScreen({super.key, required this.marketplace, required this.order});

  final MarketplaceApi marketplace;
  final Order order;

  @override
  State<VendorOrderDetailScreen> createState() => _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState extends State<VendorOrderDetailScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await widget.marketplace.order(widget.order.id);
      if (mounted) {
        setState(() {
          _order = order;
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

  Future<void> _runAction(Future<Order> Function() call, {required String successLabel}) async {
    setState(() => _actionLoading = true);
    try {
      final updated = await call();
      if (mounted) {
        setState(() => _order = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successLabel), behavior: SnackBarBehavior.floating),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<String?> _askReason(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Raison *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 3) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _accept() async {
    final order = _order ?? widget.order;
    await _runAction(() => widget.marketplace.vendorAccept(order.id), successLabel: 'Commande acceptée');
  }

  Future<void> _refuse() async {
    final order = _order ?? widget.order;
    final reason = await _askReason('Refuser la commande');
    if (reason == null || !mounted) {
      return;
    }
    await _runAction(() => widget.marketplace.vendorRefuse(order.id, reason: reason), successLabel: 'Commande refusée');
  }

  Future<void> _prepare() async {
    final order = _order ?? widget.order;
    await _runAction(() => widget.marketplace.vendorPreparing(order.id), successLabel: 'Préparation commencée');
  }

  Future<void> _ready() async {
    final order = _order ?? widget.order;
    await _runAction(() => widget.marketplace.vendorReady(order.id), successLabel: 'Commande marquée prête');
  }

  Future<void> _cancel() async {
    final order = _order ?? widget.order;
    final reason = await _askReason('Annuler la commande');
    if (reason == null || !mounted) {
      return;
    }
    await _runAction(() => widget.marketplace.vendorCancel(order.id, reason: reason), successLabel: 'Commande annulée');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commande'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: _actionLoading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(
        message: 'Impossible de rafraîchir la commande ($_error).',
        onRetry: _load,
      );
    }
    final order = _order ?? widget.order;
    final palette = BadgePalette.order(order.status);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Commande ${order.reference}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      formatDateTime(order.createdAt, fallback: ''),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (palette != null) StatusBadge(label: palette.$1, color: palette.$2),
            ],
          ),
          if (order.cancelledBy != null) ...[
            const SizedBox(height: 6),
            Text(
              'Annulée par : ${order.cancelledBy}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
          if (order.cancellationReason != null) ...[
            const SizedBox(height: 6),
            Text(
              'Motif : ${order.cancellationReason}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Articles', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${item.quantity} × ${item.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          AmountText(item.subtotal),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  _SummaryRow(label: 'Sous-total', amount: order.subtotal),
                  _SummaryRow(label: 'Livraison', amount: order.deliveryFee),
                  if (order.discount > 0) _SummaryRow(label: 'Remise', amount: -order.discount),
                  const SizedBox(height: 4),
                  _SummaryRow(label: 'Total', amount: order.total, emphasized: true),
                ],
              ),
            ),
          ),
          if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Adresse de livraison'),
                subtitle: Text(order.deliveryAddress!),
              ),
            ),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'Rafraîchir',
            variant: AppButtonVariant.outline,
            icon: Icons.refresh,
            onPressed: _actionLoading ? null : _load,
          ),
          if (order.canVendorAccept || order.canVendorRefuse || order.canVendorPrepare || order.canVendorReady || order.canCancel) ...[
            const SizedBox(height: 12),
            if (order.canVendorAccept) ...[
              AppButton(label: 'Accepter la commande', icon: Icons.check, onPressed: _actionLoading ? null : _accept, loading: _actionLoading),
              const SizedBox(height: 8),
            ],
            if (order.canVendorRefuse)
              AppButton(
                label: 'Refuser la commande',
                icon: Icons.close,
                variant: AppButtonVariant.danger,
                onPressed: _actionLoading ? null : _refuse,
              ),
            if (order.canVendorPrepare) ...[
              AppButton(
                label: 'Commencer la préparation',
                icon: Icons.restaurant_outlined,
                onPressed: _actionLoading ? null : _prepare,
                loading: _actionLoading,
              ),
            ],
            if (order.canVendorReady) ...[
              AppButton(label: 'Marquer prête', icon: Icons.check_circle_outline, onPressed: _actionLoading ? null : _ready, loading: _actionLoading),
              const SizedBox(height: 8),
            ],
            if (order.canCancel) ...[
              const SizedBox(height: 8),
              AppButton(
                label: 'Annuler la commande',
                icon: Icons.cancel_outlined,
                variant: AppButtonVariant.danger,
                onPressed: _actionLoading ? null : _cancel,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, this.amount, this.emphasized = false});

  final String label;
  final int? amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          if (amount != null)
            AmountText(amount!, style: style)
          else
            Text('—', style: style),
        ],
      ),
    );
  }
}