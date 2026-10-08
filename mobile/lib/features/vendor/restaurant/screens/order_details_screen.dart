import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order.dart';
import '../restaurant_palette.dart';
import '../widgets/order_status_tag.dart';

/// Détail d'une commande vendeur : client, articles, paiement, notes et
/// actions en pied de page fixe (Accepter / Refuser, Préparation, Prête,
/// Livrée).
class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onRefuse,
    required this.onPrepare,
    required this.onReady,
    this.onConfirmDelivery,
    this.busy = false,
  });

  final Order order;
  final Future<bool> Function(Order order) onAccept;
  final Future<bool> Function(Order order) onRefuse;
  final Future<bool> Function(Order order) onPrepare;
  final Future<bool> Function(Order order) onReady;
  final Future<bool> Function(Order order)? onConfirmDelivery;
  final bool busy;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Order _order;
  late bool _busy;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _busy = widget.busy;
  }

  /// Exécute une action puis applique le statut résultant localement (le
  /// shell reste la source de vérité pour la liste).
  Future<void> _run(Future<bool> Function(Order) action, String nextStatus) async {
    if (_busy) return;
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await action(_order);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _order = _order.withStatus(nextStatus);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RestaurantPalette.background,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _buildCustomerCard(),
                  const SizedBox(height: 12),
                  _buildItemsCard(),
                  const SizedBox(height: 12),
                  _buildPaymentCard(),
                  if (_order.notes != null && _order.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildNotesCard(),
                  ],
                  const SizedBox(height: 96),
                ],
              ),
            ),
            if (_hasActions) _buildFooter(),
          ],
        ),
      ),
    );
  }

  bool get _hasActions =>
      _order.canVendorAccept ||
      _order.status == 'accepted' ||
      _order.status == 'preparing' ||
      _order.status == 'ready';

  Widget _buildHeader() {
    return Material(
      color: RestaurantPalette.white,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 12, top: 6, bottom: 10),
        child: Row(
          children: [
            const BackButton(),
            Expanded(
              child: Text(
                'Commande ${_order.reference}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RestaurantPalette.forest,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            OrderStatusTag(_order.status),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    final address = _order.deliveryAddress ?? _order.deliveryAddressSnapshot?.display ?? '—';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Client',
              style: TextStyle(
                color: RestaurantPalette.grayText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _order.customerName ?? 'Client',
              style: const TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (_order.customerPhone != null)
              _DetailLine(
                icon: Icons.phone,
                iconColor: RestaurantPalette.success,
                value: _order.customerPhone!,
              ),
            _DetailLine(
              icon: Icons.location_on_outlined,
              iconColor: RestaurantPalette.orange,
              value: address,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Articles',
              style: TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in _order.items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${item.name} × ${item.quantity}',
                      style: const TextStyle(
                        color: RestaurantPalette.darkText,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatAmount(item.subtotal),
                    style: const TextStyle(
                      color: RestaurantPalette.darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            const Divider(height: 16, color: RestaurantPalette.borderColor),
            _SummaryRow(label: 'Sous-total', value: formatAmount(_order.subtotal)),
            _SummaryRow(label: 'Livraison', value: formatAmount(_order.deliveryFee)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      color: RestaurantPalette.orange,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  formatAmount(_order.total),
                  style: const TextStyle(
                    color: RestaurantPalette.orange,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    final paid = _order.isPaid || _order.status == 'delivered';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                size: 20, color: RestaurantPalette.forest),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                paid ? 'Déjà payé en ligne' : 'Paiement à la livraison (Espèces)',
                style: const TextStyle(
                  color: RestaurantPalette.darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    size: 18, color: RestaurantPalette.orange),
                SizedBox(width: 8),
                Text(
                  'Notes du client',
                  style: TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _order.notes!.trim(),
              style: const TextStyle(
                color: RestaurantPalette.grayText,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: RestaurantPalette.white,
        border: Border(top: BorderSide(color: RestaurantPalette.borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            )
          else
            ..._footerButtons(),
        ],
      ),
    );
  }

  List<Widget> _footerButtons() {
    if (_order.canVendorAccept) {
      return [
        Row(
          children: [
            Expanded(
              child: _FooterButton(
                label: 'Accepter',
                color: RestaurantPalette.success,
                onPressed: () => _run(widget.onAccept, 'accepted'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FooterButton(
                label: 'Refuser',
                color: RestaurantPalette.danger,
                onPressed: () => _run(widget.onRefuse, 'cancelled'),
              ),
            ),
          ],
        ),
      ];
    }
    if (_order.status == 'accepted') {
      return [
        _FooterButton(
          label: 'Commencer la préparation',
          color: RestaurantPalette.orange,
          onPressed: () => _run(widget.onPrepare, 'preparing'),
        ),
      ];
    }
    if (_order.status == 'preparing') {
      return [
        _FooterButton(
          label: 'Marquer comme Prête',
          color: RestaurantPalette.orange,
          onPressed: () => _run(widget.onReady, 'ready'),
        ),
      ];
    }
    // ready
    if (widget.onConfirmDelivery != null) {
      return [
        _FooterButton(
          label: 'Marquer comme Livrée',
          color: RestaurantPalette.success,
          onPressed: () => _run(widget.onConfirmDelivery!, 'delivered'),
        ),
      ];
    }
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: RestaurantPalette.ready.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining_outlined, size: 17, color: RestaurantPalette.ready),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Prête — en attente du livreur',
                style: TextStyle(
                  color: RestaurantPalette.ready,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.iconColor, required this.value});

  final IconData icon;
  final Color iconColor;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 13.5),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: RestaurantPalette.darkText,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({required this.label, required this.color, required this.onPressed});

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
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
