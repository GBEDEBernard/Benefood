import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/state_widgets.dart';
import 'order_tracking_screen.dart';

/// Mes commandes (J152) — design premium : en-tête brandé, filtres chips,
/// cartes avec logo boutique, contenu et total en orange.
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

  static const _filters = <(String?, String)>[
    (null, 'Toutes'),
    ('awaiting_payment', 'À payer'),
    ('active', 'En cours'),
    ('delivered', 'Livrées'),
    ('cancelled', 'Annulées'),
  ];

  static const _activeStatuses = {'paid', 'accepted', 'preparing', 'ready', 'assigned', 'out_for_delivery'};

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
    switch (_statusFilter) {
      case null:
      case '':
        return _orders;
      case 'active':
        return _orders.where((o) => _activeStatuses.contains(o.status)).toList();
      default:
        return _orders.where((o) => o.status == _statusFilter).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final activeCount = _orders.where((o) => _activeStatuses.contains(o.status)).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _buildBody(visible, activeCount),
      ),
    );
  }

  Widget _buildBody(List<Order> visible, int activeCount) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 16),
          Center(child: CircularProgressIndicator()),
        ],
      );
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

    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppDimens.xl),
        children: [
          // --- En-tête premium ---
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, 12, AppDimens.pagePadding, 0),
            child: Row(
              children: [
                _RoundBackButton(onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mes commandes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        activeCount > 0
                            ? '$activeCount commande${activeCount > 1 ? 's' : ''} en cours'
                            : '${_orders.length} commande${_orders.length > 1 ? 's' : ''} au total',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // --- Filtres ---
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, 14, 0, 6),
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final (value, label) = _filters[index];
                  final selected = _statusFilter == value;
                  return _FilterPill(
                    label: label,
                    selected: selected,
                    onTap: () => setState(() => _statusFilter = value),
                  );
                },
              ),
            ),
          ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Aucune commande dans ce filtre.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...visible.map((order) => _OrderCard(
                  order: order,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => OrderTrackingScreen(marketplace: widget.marketplace, orderId: order.id),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

/// Bouton retour circulaire premium.
class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.text),
        ),
      ),
    );
  }
}

/// Pastille de filtre premium (sélection = orange).
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.orange : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          border: Border.all(color: selected ? AppColors.orange : AppColors.border),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))]
              : AppTheme.softShadow(),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Carte commande premium : logo boutique, référence, contenu, statut, total.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _statusStyle(order.status);
    final itemCount = order.items.fold<int>(0, (sum, item) => sum + item.quantity);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, 8, AppDimens.pagePadding, 0),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: AppTheme.softShadow(),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Logo / photo de la boutique
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: order.vendor?.logoUrl != null
                          ? AppNetworkImage(url: order.vendor!.logoUrl, icon: Icons.storefront)
                          : const Icon(Icons.storefront_outlined, color: AppColors.orange, size: 22),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '#${order.reference.split('-').last}'
                            '${itemCount > 0 ? ' · $itemCount article${itemCount > 1 ? 's' : ''}' : ''}'
                            ' · ${formatDate(order.createdAt, fallback: '—')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatAmount(order.total, showSymbol: false),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            color: AppColors.orange,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: palette.$2.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            palette.$1,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: palette.$2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Aperçu du contenu (photos produits)
                if (order.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(height: 1, color: AppColors.border),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: Row(
                      children: [
                        for (final item in order.items.take(4))
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: AppColors.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: item.imageUrl != null
                                  ? AppNetworkImage(url: item.imageUrl, icon: Icons.fastfood_outlined)
                                  : const Icon(Icons.fastfood_outlined, size: 15, color: AppColors.textFaint),
                            ),
                          ),
                        if (order.items.length > 4)
                          Text(
                            '+${order.items.length - 4}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              order.items.first.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 16, color: AppColors.textFaint),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  (String, Color) _statusStyle(String status) {
    return switch (status) {
      'awaiting_payment' => ('À payer', AppColors.goldDark),
      'paid' => ('Confirmée', AppColors.green),
      'accepted' => ('Confirmée', AppColors.green),
      'preparing' => ('Préparation', AppColors.orange),
      'ready' => ('Prête', AppColors.green),
      'assigned' => ('Livreur assigné', AppColors.green),
      'out_for_delivery' => ('En livraison', AppColors.green),
      'delivered' => ('Livrée', AppColors.green),
      'cancelled' => ('Annulée', AppColors.red),
      'refunded' => ('Remboursée', AppColors.textSecondary),
      _ => (status.replaceAll('_', ' '), AppColors.green),
    };
  }
}
