import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order.dart';
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
    final palette = _statusColor(order.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.$2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_statusIcon(order.status), color: palette.$2, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.vendor?.businessName ?? 'Commande ${order.reference}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.items.isEmpty
                              ? '0 article'
                              : '${order.items.length} article${order.items.length > 1 ? 's' : ''}'
                                  ' · ${order.items.first.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: palette.$2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(order.status),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: palette.$2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      formatDate(order.createdAt, fallback: '—'),
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatAmount(order.total),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const TextSpan(
                          text: '  ',
                        ),
                        TextSpan(
                          text: order.currency,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'awaiting_payment' => 'À payer',
      'paid' => 'En préparation',
      'accepted' => 'Confirmée',
      'preparing' => 'En préparation',
      'ready' => 'Prête',
      'assigned' => 'Livreur assigné',
      'out_for_delivery' => 'En livraison',
      'delivered' => 'Livrée',
      'cancelled' => 'Annulée',
      'refunded' => 'Remboursée',
      _ => status.replaceAll('_', ' ').toUpperCase(),
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'awaiting_payment' => Icons.payments_outlined,
      'paid' => Icons.check_circle_outline,
      'accepted' => Icons.verified_outlined,
      'preparing' => Icons.restaurant_menu,
      'ready' => Icons.shopping_bag_outlined,
      'assigned' => Icons.delivery_dining_outlined,
      'out_for_delivery' => Icons.local_shipping_outlined,
      'delivered' => Icons.house_outlined,
      'cancelled' => Icons.cancel_outlined,
      'refunded' => Icons.replay_outlined,
      _ => Icons.receipt_long_outlined,
    };
  }

  (String, Color) _statusColor(String status) {
    return switch (status) {
      'awaiting_payment' => ('À payer', const Color(0xFFE08A00)),
      'paid' => ('Confirmée', AppColors.green),
      'accepted' => ('Confirmée', AppColors.green),
      'preparing' => ('Préparation', const Color(0xFF1976D2)),
      'ready' => ('Prête', const Color(0xFF3949AB)),
      'assigned' => ('Assignée', const Color(0xFF7B1FA2)),
      'out_for_delivery' => ('En livraison', const Color(0xFF00897B)),
      'delivered' => ('Livrée', AppColors.greenDark),
      'cancelled' => ('Annulée', const Color(0xFFE53935)),
      'refunded' => ('Remboursée', AppColors.textSecondary),
      _ => (status, AppColors.green),
    };
  }
}