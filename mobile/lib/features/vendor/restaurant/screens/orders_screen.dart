import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order.dart';
import '../restaurant_palette.dart';
import '../widgets/order_status_tag.dart';
import 'order_details_screen.dart';

/// Écran « D. COMMANDES » : onglets Nouvelles / Préparation / Prêtes /
/// Terminées, cartes de commandes avec actions rapides et navigation en pile
/// vers le détail d'une commande.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.orders,
    required this.onAccept,
    required this.onRefuse,
    required this.onPrepare,
    required this.onReady,
    this.onConfirmDelivery,
    this.busyOrderIds = const {},
    this.onOpenDrawer,
    this.onRefresh,
  });

  /// Commandes déjà chargées par le shell (live ou démo).
  final List<Order> orders;

  /// Actions : renvoient `true` lorsque l'action a bien été effectuée.
  final Future<bool> Function(Order order) onAccept;
  final Future<bool> Function(Order order) onRefuse;
  final Future<bool> Function(Order order) onPrepare;
  final Future<bool> Function(Order order) onReady;

  /// Marquage « Livrée » : proposé en démonstration (le serveur confirme la
  /// livraison côté livreur en production).
  final Future<bool> Function(Order order)? onConfirmDelivery;

  /// Commandes en cours d'action (désactivation des boutons).
  final Set<String> busyOrderIds;

  final VoidCallback? onOpenDrawer;
  final Future<void> Function()? onRefresh;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const List<String> _tabLabels = ['Nouvelles', 'Préparation', 'Prêtes', 'Terminées'];

  int _tab = 0;

  List<Order> _group(int index) => switch (index) {
        0 => widget.orders
            .where((o) => o.canVendorAccept || o.status == 'draft')
            .toList(),
        1 => widget.orders.where((o) => o.status == 'accepted' || o.status == 'preparing').toList(),
        2 => widget.orders
            .where((o) =>
                o.status == 'ready' ||
                o.status == 'assigned' ||
                o.status == 'picked_up' ||
                o.status == 'in_delivery')
            .toList(),
        _ => widget.orders
            .where((o) =>
                o.status == 'delivered' || o.status == 'cancelled' || o.status == 'refunded')
            .toList(),
      };

  @override
  Widget build(BuildContext context) {
    final groups = List.generate(4, _group);
    final current = groups[_tab];

    return Material(
      color: RestaurantPalette.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => widget.onRefresh?.call(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    _buildTabsCard(groups),
                    const SizedBox(height: 14),
                    if (current.isEmpty)
                      _EmptyTab(
                        allEmpty: widget.orders.isEmpty,
                        tabLabel: _tabLabels[_tab],
                      )
                    else
                      for (final order in current) ...[
                        _OrderCard(
                          order: order,
                          busy: widget.busyOrderIds.contains(order.id),
                          onOpen: () => _openDetails(order),
                          onAccept: () => widget.onAccept(order),
                          onRefuse: () => widget.onRefuse(order),
                          onPrepare: () => widget.onPrepare(order),
                          onReady: () => widget.onReady(order),
                          onConfirmDelivery: widget.onConfirmDelivery == null
                              ? null
                              : () => widget.onConfirmDelivery!(order),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OrderDetailsScreen(
          order: order,
          busy: widget.busyOrderIds.contains(order.id),
          onAccept: widget.onAccept,
          onRefuse: widget.onRefuse,
          onPrepare: widget.onPrepare,
          onReady: widget.onReady,
          onConfirmDelivery: widget.onConfirmDelivery,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Material(
      color: RestaurantPalette.white,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, right: 6, top: 8, bottom: 10),
        child: Row(
          children: [
            if (widget.onOpenDrawer != null)
              IconButton(
                onPressed: widget.onOpenDrawer,
                icon: const Icon(Icons.menu, color: RestaurantPalette.darkText),
                tooltip: 'Ouvrir le menu',
              )
            else
              const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'D. COMMANDES',
                style: TextStyle(
                  color: RestaurantPalette.forest,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            if (widget.onRefresh != null)
              IconButton(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh, color: RestaurantPalette.grayText),
                tooltip: 'Actualiser',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsCard(List<List<Order>> groups) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Commandes',
              style: TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < _tabLabels.length; i++)
                  Expanded(
                    child: _TabButton(
                      label: '${_tabLabels[i]} (${groups[i].length})',
                      active: _tab == i,
                      onTap: () => setState(() => _tab = i),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? RestaurantPalette.orange : RestaurantPalette.grayText;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: active ? RestaurantPalette.orange : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'une commande de la liste : identification, client, livraison,
/// montant et actions.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.busy,
    required this.onOpen,
    required this.onAccept,
    required this.onRefuse,
    required this.onPrepare,
    required this.onReady,
    this.onConfirmDelivery,
  });

  final Order order;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  final VoidCallback onPrepare;
  final VoidCallback onReady;
  final VoidCallback? onConfirmDelivery;

  int get _articleCount => order.items.fold(0, (sum, item) => sum + item.quantity);

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    order.reference,
                    style: const TextStyle(
                      color: RestaurantPalette.darkText,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _timeAgo(order.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 11.5),
                    ),
                  ),
                  const Spacer(),
                  OrderStatusTag(order.status, small: true),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Client', value: order.customerName ?? 'Client', bold: true),
              _InfoRow(
                label: 'Livraison',
                value: order.deliveryAddress ?? order.deliveryAddressSnapshot?.display ?? '—',
              ),
              _InfoRow(label: 'Montant', value: formatAmount(order.total), bold: true),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$_articleCount article${_articleCount > 1 ? 's' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RestaurantPalette.grayText,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onOpen,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      child: Text(
                        'Voir détails',
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
              if (order.canVendorAccept || order.status == 'accepted' || order.status == 'preparing' || onConfirmDelivery != null) ...[
                const SizedBox(height: 14),
                if (busy)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  )
                else
                  _buildActions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (order.canVendorAccept) {
      return Row(
        children: [
          Expanded(
            child: _ActionButton(label: 'Accepter', color: RestaurantPalette.success, onPressed: onAccept),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(label: 'Refuser', color: RestaurantPalette.danger, onPressed: onRefuse),
          ),
        ],
      );
    }
    if (order.status == 'accepted') {
      return _ActionButton(
        label: 'Commencer la préparation',
        color: RestaurantPalette.orange,
        onPressed: onPrepare,
      );
    }
    if (order.status == 'preparing') {
      return _ActionButton(label: 'Marquer comme Prête', color: RestaurantPalette.orange, onPressed: onReady);
    }
    if (order.status == 'ready') {
      if (onConfirmDelivery != null) {
        return _ActionButton(
          label: 'Marquer comme Livrée',
          color: RestaurantPalette.success,
          onPressed: onConfirmDelivery!,
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: RestaurantPalette.ready.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining_outlined, size: 16, color: RestaurantPalette.ready),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Prête — en attente du livreur',
                style: TextStyle(
                  color: RestaurantPalette.ready,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 13.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.color, required this.onPressed});

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: RestaurantPalette.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.allEmpty, required this.tabLabel});

  final bool allEmpty;
  final String tabLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 44,
            color: RestaurantPalette.orange,
          ),
          const SizedBox(height: 12),
          Text(
            allEmpty ? 'Aucune commande' : 'Aucune commande « $tabLabel »',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RestaurantPalette.darkText,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Les nouvelles commandes apparaîtront ici dès qu\'un client commande.',
            textAlign: TextAlign.center,
            style: TextStyle(color: RestaurantPalette.grayText, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Affichage relatif d'une date : « il y a 5 min », « il y a 2 h »…
String _timeAgo(String? iso) {
  final date = DateTime.tryParse(iso ?? '')?.toLocal();
  if (date == null) {
    return '';
  }
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) {
    return "à l'instant";
  }
  if (diff.inMinutes < 60) {
    return 'il y a ${diff.inMinutes} min';
  }
  if (diff.inHours < 24) {
    return 'il y a ${diff.inHours} h';
  }
  if (diff.inDays < 7) {
    return 'il y a ${diff.inDays} j';
  }
  return formatDate(iso, fallback: '');
}
