import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Tableau de bord vendeur (J154) : boutique, statut, statistiques rapides.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.marketplace, required this.onGoToTab});

  final MarketplaceApi marketplace;
  final ValueChanged<int> onGoToTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _status;
  List<Product> _products = [];
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;

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
      final status = await widget.marketplace.vendorStatus();
      final products = await widget.marketplace.vendorProducts();
      final orders = await widget.marketplace.vendorOrders(perPage: 50);
      if (mounted) {
        setState(() {
          _status = status;
          _products = products;
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

  int get _pendingOrders => _orders
      .where((o) => o.canVendorAccept || o.canVendorRefuse || o.canVendorPrepare || o.canVendorReady)
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
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

    final rawVendor = _status?['vendor'];
    final vendor = rawVendor is Map<String, dynamic> ? rawVendor : null;
    final status = _stringOrNull(vendor?['status']);
    final palette = BadgePalette.vendor(status);
    final businessName = _stringOrNull(vendor?['business_name']) ?? 'Ma boutique';
    final city = _stringOrNull(vendor?['city']);
    final phone = _stringOrNull(vendor?['phone']);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(businessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      ),
                      if (palette != null) StatusBadge(label: palette.$1, color: palette.$2, small: true),
                    ],
                  ),
                  if (city != null && city.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(city, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ],
                  if (phone != null && phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(phone, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.shopping_bag_outlined,
                  value: _products.length,
                  label: 'Produits',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.receipt_long_outlined,
                  value: _pendingOrders,
                  label: 'Commandes en attente',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Gérer mes produits',
            icon: Icons.shopping_bag_outlined,
            onPressed: () => widget.onGoToTab(1),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Voir les commandes',
            icon: Icons.receipt_long_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => widget.onGoToTab(2),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text('$value', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

String? _stringOrNull(dynamic value) => value is String ? value : null;