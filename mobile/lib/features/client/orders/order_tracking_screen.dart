import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Écran de suivi / détail d'une commande (J152, J177).
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key, required this.marketplace, required this.orderId});

  final MarketplaceApi marketplace;
  final String orderId;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const _pollInterval = Duration(seconds: 15);

  Order? _order;
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;
  Timer? _pollTimer;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool get _shouldPoll => _order?.delivery?.isTracking ?? false;

  void _schedulePolling() {
    _pollTimer?.cancel();
    if (_shouldPoll) {
      _pollTimer = Timer.periodic(_pollInterval, (_) => _refreshSilently());
    }
  }

  Future<void> _refreshSilently() async {
    if (_polling) {
      return;
    }
    _polling = true;
    try {
      final order = await widget.marketplace.order(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _error = null;
        });
      }
    } on ApiException {
      // Silence : on ne coupe pas le suivi si un rafraîchissement échoue.
    } finally {
      _polling = false;
      if (mounted) {
        _schedulePolling();
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await widget.marketplace.order(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _loading = false;
        });
        _schedulePolling();
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

  Future<void> _cancel() async {
    final reason = await _askCancelReason();
    if (reason == null || !mounted) {
      return;
    }
    setState(() => _actionLoading = true);
    try {
      final order = await widget.marketplace.cancelOrder(widget.orderId, reason);
      if (mounted) {
        setState(() {
          _order = order;
          _actionLoading = false;
        });
        showToast(context, 'Commande annulée');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<String?> _askCancelReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la commande'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Raison de l\'annulation *'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suivi de commande')),
      body: _buildBody(),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'awaiting_payment' => 'En attente de paiement',
      'paid' => 'En préparation',
      'accepted' => 'Confirmée',
      'preparing' => 'En préparation',
      'ready' => 'Prête',
      'assigned' => 'Livreur assigné',
      'out_for_delivery' => 'En livraison',
      'delivered' => 'Livrée',
      'cancelled' => 'Annulée',
      'refunded' => 'Remboursée',
      _ => status.replaceAll('_', ' '),
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'awaiting_payment' => const Color(0xFFE08A00),
      'paid' => AppColors.green,
      'accepted' => AppColors.green,
      'preparing' => const Color(0xFF1976D2),
      'ready' => const Color(0xFF3949AB),
      'assigned' => const Color(0xFF7B1FA2),
      'out_for_delivery' => const Color(0xFF00897B),
      'delivered' => AppColors.greenDark,
      'cancelled' => const Color(0xFFE53935),
      'refunded' => AppColors.textSecondary,
      _ => AppColors.green,
    };
  }

  Widget? _trackingCard(Order order) {
    final delivery = order.delivery;
    final driver = delivery?.driver;
    final position = delivery?.position;
    if (delivery == null || driver == null) {
      return null;
    }

    final theme = Theme.of(context);
    final tracking = position != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delivery_dining, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Livreur', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (tracking)
                  _LiveDot(color: Colors.green)
                else
                  Text('Non affecté', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            if (driver.name != null)
              Text(driver.name!, style: theme.textTheme.bodyMedium),
            for (final line
                in [driver.vehicle ?? '', driver.rating != null ? 'Note : ${driver.rating!.toStringAsFixed(1)}' : '']
                    .where((e) => e.isNotEmpty))
              Text(line, style: theme.textTheme.bodySmall),
            if (tracking) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'À ${formatDistance(position.distanceKm)} de vous',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const Spacer(),
                  Text('Mise à jour auto', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final order = _order!;
    final accent = _statusColor(order.status);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusHero(
            order: order,
            accent: accent,
            label: _statusLabel(order.status),
            onCancel: order.canCancel ? _cancel : null,
          ),
          const SizedBox(height: 16),
          if (order.canCancel || order.isAwaitingPayment || order.isPaid || order.status == 'accepted')
            _ProgressStepper(order: order, accent: accent),
          const SizedBox(height: 8),
          if (order.paymentStatus.isNotEmpty) ...[
            _PaymentStatusRow(order: order),
            const SizedBox(height: 12),
          ],
          if (order.statusHistory.isNotEmpty) _Timeline(history: order.statusHistory),
          const SizedBox(height: 20),
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
                          Expanded(child: Text('${item.quantity} × ${item.name}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: AmountText(item.subtotal, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  _SummaryRow(label: 'Sous-total', amount: order.subtotal),
                  _SummaryRow(label: 'Livraison', amount: order.deliveryFee),
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
          if (_trackingCard(order) != null) ...[
            const SizedBox(height: 12),
            _trackingCard(order)!,
          ],
          if (order.cancellationReason != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.error),
                title: const Text('Motif d\'annulation'),
                subtitle: Text(order.cancellationReason!),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (order.canCancel)
            AppButton(
              label: 'Annuler la commande',
              variant: AppButtonVariant.danger,
              onPressed: _actionLoading ? null : _cancel,
              loading: _actionLoading,
            ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Signaler un problème',
            variant: AppButtonVariant.outline,
            icon: Icons.support_agent,
            onPressed: () => context.push('/client/complaints/new', extra: {'order_id': order.id}),
          ),
        ],
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.order,
    required this.accent,
    required this.label,
    this.onCancel,
  });

  final Order order;
  final Color accent;
  final String label;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final date = formatDate(order.createdAt, fallback: '');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _RefChip(abbr: order.reference.split('-').last, accent: accent),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Commande',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.reference,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${order.vendor?.businessName ?? 'Béninfood'} · $date',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatAmount(order.total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (onCancel != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Annuler la commande'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RefChip extends StatelessWidget {
  const _RefChip({required this.abbr, required this.accent});

  final String abbr;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '#$abbr',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProgressStepper extends StatelessWidget {
  const _ProgressStepper({required this.order, required this.accent});

  final Order order;
  final Color accent;

  static const _steps = ['Confirmation', 'Préparation', 'Livraison'];

  int get _currentIndex {
    return switch (order.status) {
      'awaiting_payment' => 0,
      'paid' || 'accepted' || 'preparing' => 1,
      'ready' || 'assigned' || 'out_for_delivery' => 2,
      'delivered' => _steps.length,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              _StepItem(
                label: _steps[i],
                index: i,
                current: current,
                accent: accent,
              ),
              if (i < _steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(top: 24),
                    decoration: BoxDecoration(
                      color: i < current ? accent : const Color(0xFFE2E5E9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.label,
    required this.index,
    required this.current,
    required this.accent,
  });

  final String label;
  final int index;
  final int current;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final done = index < current;
    final active = index == current;

    final Color color = done
        ? accent
        : active
            ? accent
            : const Color(0xFFC7CBD1);
    final IconData icon = done
        ? Icons.check_circle
        : active
            ? Icons.radio_button_checked
            : Icons.radio_button_off;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        SizedBox(
          width: 68,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: done || active ? FontWeight.w700 : FontWeight.w400,
              color: done || active ? AppColors.text : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentStatusRow extends StatelessWidget {
  const _PaymentStatusRow({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final paid = order.paymentStatus == 'confirmed' ||
        order.paymentStatus == 'paid' ||
        order.status == 'paid' ||
        order.isDelivered;
    final cancelled = order.isCancelled;

    final Color color = cancelled
        ? const Color(0xFFE53935)
        : paid
            ? AppColors.green
            : const Color(0xFFE08A00);
    final label = cancelled
        ? 'Paiement annulé'
        : paid
            ? 'Paiement confirmé'
            : 'En attente de paiement';

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            paid ? Icons.check_circle : cancelled ? Icons.cancel : Icons.schedule,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 13.5, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Résultat de commande après checkout (succès / en attente).
class TrackingResultScreen extends StatelessWidget {
  const TrackingResultScreen({
    super.key,
    required this.marketplace,
    required this.order,
    required this.success,
  });

  final MarketplaceApi marketplace;
  final Order order;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                success ? Icons.check_circle : Icons.hourglass_top,
                size: 72,
                color: success ? Colors.green : theme.colorScheme.tertiary,
              ),
              const SizedBox(height: 20),
              Text(
                success ? 'Paiement confirmé !' : 'Commande créée',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                success
                    ? 'Votre commande ${order.reference} a été réglée et est en préparation.'
                    : 'Votre commande ${order.reference} est en attente de paiement.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              AmountText(order.total, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 32),
              AppButton(
                label: 'Suivre ma commande',
                icon: Icons.track_changes,
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => OrderTrackingScreen(marketplace: marketplace, orderId: order.id),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Retour à l\'accueil',
                variant: AppButtonVariant.outline,
                onPressed: () => context.go('/client'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.history});

  final List<OrderStatusHistory> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historique', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...List.generate(history.length, (index) {
              final entry = history[history.length - 1 - index];
              final isLast = index == 0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Icon(
                        isLast ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 18,
                        color: isLast ? theme.colorScheme.primary : theme.colorScheme.outline,
                      ),
                      if (index < history.length - 1)
                        Container(
                          width: 2,
                          height: 40,
                          color: theme.colorScheme.outlineVariant,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _statusLabel(entry.toStatus),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (entry.reason != null && entry.reason!.isNotEmpty)
                            Text(entry.reason!, style: theme.textTheme.bodySmall),
                          Text(
                            formatDateTime(entry.createdAt, fallback: ''),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'awaiting_payment' => 'En attente de paiement',
      'paid' => 'En préparation',
      'accepted' => 'Confirmée',
      'preparing' => 'En préparation',
      'ready' => 'Prête',
      'assigned' => 'Livreur assigné',
      'out_for_delivery' => 'En livraison',
      'delivered' => 'Livrée',
      'cancelled' => 'Annulée',
      'refunded' => 'Remboursée',
      _ => status.replaceAll('_', ' '),
    };
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

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        const Text('Suivi en direct'),
      ],
    );
  }
}