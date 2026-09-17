import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';
import 'order_tracking_screen.dart';

/// Mes commandes (J152) : liste + filtre par statut.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

  static const _filters = <(String, String)>[
    ('', 'Toutes'),
    ('awaiting_payment', 'À payer'),
    ('paid', 'En cours'),
    ('assigned', 'En cours'),
    ('delivered', 'Livrées'),
    ('cancelled', 'Annulées'),
  ];

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
      final orders = await widget.marketplace.orders(perPage: 50);
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

  List<Order> get _visible {
    if (_statusFilter == null || _statusFilter!.isEmpty) {
      return _orders;
    }
    return _orders.where((o) => o.status == _statusFilter! || o.status == 'accepted' && _statusFilter == 'paid' || o.status == 'preparing' && _statusFilter == 'paid').toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
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
        subtitle: 'Vos commandes apparaîtront ici.',
        actionLabel: 'Explorer',
        onAction: () => context.go('/client/search'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) {
                final (value, label) = f;
                final selected = _statusFilter == value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _statusFilter = value;
                      if (value.isEmpty) {
                        _statusFilter = null;
                      }
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _visible.length,
              itemBuilder: (context, index) {
                final order = _visible[index];
                return _OrderCard(
                  order: order,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => OrderTrackingScreen(marketplace: widget.marketplace, orderId: order.id),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                      order.vendor?.businessName ?? 'Commande ${order.reference}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (palette != null)
                    StatusBadge(label: palette.$1, color: palette.$2, small: true),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${order.items.length} article(s) · ${formatDateTime(order.createdAt, fallback: '')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(order.reference, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  AmountText(order.total, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}