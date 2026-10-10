import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../restaurant_palette.dart';
import '../widgets/order_status_tag.dart';

/// Détail d'une commande vendeur : client, articles, paiement, notes et
/// actions en pied de page fixe (Accepter / Refuser, Préparation, Prête,
/// Livrée). Affiche aussi la minuterie d'acceptation, le détail financier et
/// l'historique de statut (J21 §3.4).
class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onRefuse,
    required this.onPrepare,
    required this.onReady,
    this.onConfirmDelivery,
    this.onReportIncident,
    this.busy = false,
  });

  final Order order;
  final Future<bool> Function(Order order) onAccept;
  final Future<bool> Function(Order order) onRefuse;
  final Future<bool> Function(Order order) onPrepare;
  final Future<bool> Function(Order order) onReady;
  final Future<bool> Function(Order order)? onConfirmDelivery;
  final Future<bool> Function(Order order, String subject, String description)? onReportIncident;
  final bool busy;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Order _order;
  late bool _busy;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _busy = widget.busy;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Compte à rebours d'acceptation : actif tant que la commande est payée et
  /// en attente d'acceptation vendeur et qu'une échéance est connue.
  void _startTimer() {
    _timer?.cancel();
    if (!_hasAcceptanceDeadline) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining == Duration.zero) {
        _timer?.cancel();
      }
      setState(() {});
    });
  }

  bool get _hasAcceptanceDeadline =>
      _order.status == 'paid' && _order.vendorAcceptanceDeadlineAt != null;

  Duration? get _remaining {
    final raw = _order.vendorAcceptanceDeadlineAt;
    if (raw == null) return null;
    final deadline = DateTime.tryParse(raw)?.toLocal();
    if (deadline == null) return null;
    final diff = deadline.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
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
    if (ok) _startTimer();
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
                  if (_hasAcceptanceDeadline) ...[
                    _buildCountdownCard(),
                    const SizedBox(height: 12),
                  ],
                  _buildCustomerCard(),
                  const SizedBox(height: 12),
                  _buildItemsCard(),
                  const SizedBox(height: 12),
                  _buildPaymentCard(),
                  if (_order.notes != null && _order.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildNotesCard(),
                  ],
                  if (_order.financials != null) ...[
                    const SizedBox(height: 12),
                    _buildFinancialCard(),
                  ],
                  if (_order.statusHistory.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildHistoryCard(),
                  ],
                  if (widget.onReportIncident != null) ...[
                    const SizedBox(height: 12),
                    _buildReportCard(),
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

  Widget _buildCountdownCard() {
    final remaining = _remaining ?? Duration.zero;
    final urgent = remaining.inSeconds <= 60;
    final color = urgent ? RestaurantPalette.danger : RestaurantPalette.orange;
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 22, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'À accepter avant expiration',
                style: TextStyle(
                  color: color,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$minutes:$seconds',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard() {
    final f = _order.financials!;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Détail financier',
              style: TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _SummaryRow(label: 'Base commissionnable', value: formatAmount(_order.subtotal)),
            if (f.commissionRate != null)
              _SummaryRow(label: 'Taux commission', value: '${f.commissionRate} %'),
            if (f.commissionAmount != null)
              _SummaryRow(label: 'Commission plateforme', value: '- ${formatAmount(f.commissionAmount!)}'),
            if (f.deliveryPartnerAmount != null)
              _SummaryRow(label: 'Part livraison', value: formatAmount(f.deliveryPartnerAmount!)),
            const Divider(height: 16, color: RestaurantPalette.borderColor),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Votre part',
                    style: TextStyle(
                      color: RestaurantPalette.success,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  formatAmount(f.vendorAmount ?? 0),
                  style: const TextStyle(
                    color: RestaurantPalette.success,
                    fontSize: 16,
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

  Widget _buildHistoryCard() {
    final history = [..._order.statusHistory];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historique',
              style: TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < history.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 8, color: RestaurantPalette.orange),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusLabel(history[i].toStatus),
                      style: const TextStyle(
                        color: RestaurantPalette.darkText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    formatDateTime(history[i].createdAt),
                    style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 12),
                  ),
                ],
              ),
              if (i != history.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard() {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _reportProblem,
      icon: const Icon(Icons.report_problem_outlined, size: 20),
      label: const Text('Signaler un problème'),
      style: OutlinedButton.styleFrom(
        foregroundColor: RestaurantPalette.danger,
        side: const BorderSide(color: RestaurantPalette.danger),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _reportProblem() async {
    final description = await showTextPromptDialog(
      context,
      title: 'Signaler un problème',
      hint: 'Décrivez le problème rencontré sur cette commande…',
      confirmLabel: 'Envoyer',
      maxLines: 4,
      maxLength: 2000,
    );
    if (description == null || description.isEmpty || !mounted) return;

    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await widget.onReportIncident!(_order, 'Problème commande ${_order.reference}', description);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Signalement envoyé au support.' : 'Échec de l\'envoi du signalement.')),
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

String _statusLabel(String status) {
  switch (status) {
    case 'awaiting_payment':
      return 'En attente de paiement';
    case 'paid':
      return 'Payée — à accepter';
    case 'accepted':
      return 'Acceptée';
    case 'preparing':
      return 'En préparation';
    case 'ready':
      return 'Prête';
    case 'assigned':
      return 'Livreur assigné';
    case 'picked_up':
      return 'Récupérée par le livreur';
    case 'in_delivery':
      return 'En livraison';
    case 'delivered':
      return 'Livrée';
    case 'cancelled':
      return 'Annulée';
    case 'refunded':
      return 'Remboursée';
    default:
      return status;
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
