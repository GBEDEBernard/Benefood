import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';
import 'vendor_order_detail_screen.dart';

/// Commandes reçues (J156) : liste avec actions accept/refuse/prepare/ready.
class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

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
      final orders = await widget.marketplace.vendorOrders(perPage: 50);
      if (mounted) {
        setState(() {
          _orders = orders;
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

  Future<void> _runAction(Order order, Future<Order> Function() call, {String? successLabel}) async {
    setState(() => _busyId = order.id);
    try {
      final updated = await call();
      if (!mounted) {
        return;
      }
      setState(() {
        final index = _orders.indexWhere((o) => o.id == updated.id);
        if (index >= 0) {
          _orders[index] = updated;
        }
      });
      if (successLabel != null) {
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
        setState(() => _busyId = null);
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

  Future<void> _accept(Order order) async {
    await _runAction(
      order,
      () => widget.marketplace.vendorAccept(order.id),
      successLabel: 'Commande acceptée',
    );
  }

  Future<void> _refuse(Order order) async {
    final reason = await _askReason('Refuser la commande');
    if (reason == null || !mounted) {
      return;
    }
    await _runAction(
      order,
      () => widget.marketplace.vendorRefuse(order.id, reason: reason),
      successLabel: 'Commande refusée',
    );
  }

  Future<void> _prepare(Order order) async {
    await _runAction(
      order,
      () => widget.marketplace.vendorPreparing(order.id),
      successLabel: 'Préparation commencée',
    );
  }

  Future<void> _ready(Order order) async {
    await _runAction(
      order,
      () => widget.marketplace.vendorReady(order.id),
      successLabel: 'Commande marquée prête',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commandes')),
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
    if (_orders.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Aucune commande',
        subtitle: 'Vos commandes apparaîtront ici dès qu\'un client commande.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _OrderCard(
            order: order,
            busy: _busyId == order.id,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => VendorOrderDetailScreen(marketplace: widget.marketplace, order: order),
              ),
            ),
            onAccept: () => _accept(order),
            onRefuse: () => _refuse(order),
            onPrepare: () => _prepare(order),
            onReady: () => _ready(order),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.busy,
    required this.onTap,
    required this.onAccept,
    required this.onRefuse,
    required this.onPrepare,
    required this.onReady,
  });

  final Order order;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  final VoidCallback onPrepare;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = BadgePalette.order(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Commande ${order.reference}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (palette != null) StatusBadge(label: palette.$1, color: palette.$2, small: true),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${order.items.length} article(s) · ${formatDateTime(order.createdAt, fallback: '')}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    order.reference,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  AmountText(order.total, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              if (order.canVendorAccept || order.canVendorRefuse || order.canVendorPrepare || order.canVendorReady) ...[
                const SizedBox(height: 12),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (order.canVendorAccept)
                        FilledButton.tonal(
                          style: _compactStyle,
                          onPressed: onAccept,
                          child: const Text('Accepter'),
                        ),
                      if (order.canVendorRefuse)
                        OutlinedButton(
                          style: _compactStyle,
                          onPressed: onRefuse,
                          child: const Text('Refuser'),
                        ),
                      if (order.canVendorPrepare)
                        FilledButton.tonal(
                          style: _compactStyle,
                          onPressed: onPrepare,
                          child: const Text('Commencer la préparation'),
                        ),
                      if (order.canVendorReady)
                        FilledButton.tonal(
                          style: _compactStyle,
                          onPressed: onReady,
                          child: const Text('Marquer prête'),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static final ButtonStyle _compactStyle = FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    visualDensity: VisualDensity.compact,
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  );
}