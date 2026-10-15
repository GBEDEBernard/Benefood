import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/parcel.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/fedapay_checkout_screen.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Suivi détaillé d'un colis (client ou boutique vendeuse) :
/// carte, livreur, paiement et journal.
class ParcelDetailScreen extends StatefulWidget {
  const ParcelDetailScreen({
    super.key,
    required this.marketplace,
    required this.parcelId,
    this.audience = NotificationAudience.client,
  });

  final MarketplaceApi marketplace;
  final String parcelId;

  /// Espace qui consulte le colis (client ou vendeur expéditeur).
  final NotificationAudience audience;

  @override
  State<ParcelDetailScreen> createState() => _ParcelDetailScreenState();
}

class _ParcelDetailScreenState extends State<ParcelDetailScreen> {
  Parcel? _parcel;
  bool _loading = true;
  String? _error;
  String? _actionId;

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
      final parcel = await widget.marketplace.parcel(widget.parcelId);
      if (mounted) {
        setState(() {
          _parcel = parcel;
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

  Future<void> _cancel() async {
    final parcel = _parcel;
    if (parcel == null) {
      return;
    }
    final reason = await _askCancelReason();
    if (reason == null || !mounted) {
      return;
    }
    setState(() => _actionId = 'cancel');
    try {
      await widget.marketplace.cancelParcel(parcel.id, reason: reason);
      if (mounted) {
        showToast(context, 'Colis annulé.');
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _actionId = null);
      }
    }
  }

  Future<String?> _askCancelReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le colis'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motif d\'annulation *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                return;
              }
              Navigator.of(context).pop(text);
            },
            child: const Text('Annuler le colis'),
          ),
        ],
      ),
    );
  }

  Future<void> _pay() async {
    final parcel = _parcel;
    if (parcel == null) {
      return;
    }
    setState(() => _actionId = 'pay');
    try {
      final payload = await widget.marketplace.createParcelPayment(parcel.id);
      if (!mounted) {
        return;
      }
      final checkoutUrl = payload['checkout_url'];
      if (checkoutUrl is String && checkoutUrl.isNotEmpty) {
        await startFedaPayCheckout(
          context,
          marketplace: widget.marketplace,
          checkoutUrl: checkoutUrl,
          transactionId: payload['transaction_id']?.toString(),
        );
      } else {
        final message = payload['message']?.toString();
        if (message != null && message.isNotEmpty && mounted) {
          showToast(context, message, isError: false);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _actionId = null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BeninfoodAppBar(
            onMenu: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/${widget.audience.name}/parcels');
              }
            },
            api: widget.marketplace,
            audience: widget.audience,
          ),
          Expanded(child: _buildBody()),
        ],
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
    final parcel = _parcel!;
    final theme = Theme.of(context);
    final palette = BadgePalette.parcel(parcel.status);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          parcel.reference,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (palette != null) StatusBadge(label: palette.$1, color: palette.$2),
                    ],
                  ),
                  if (parcel.description != null && parcel.description!.isNotEmpty) ...[
                    const SizedBox(height: AppDimens.sm),
                    Text(
                      parcel.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: AppDimens.md),
                  Row(
                    children: [
                      Icon(Icons.event_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        formatDateTime(parcel.createdAt, fallback: '—'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.md),
          if (parcel.pickupPoint != null || parcel.dropoffPoint != null) ...[
            AppMap(
              target: parcel.pickupPoint,
              secondary: parcel.dropoffPoint,
              height: 160,
              initialZoom: 12,
              followOrigin: false,
              showRoute: false,
            ),
            const SizedBox(height: AppDimens.md),
          ],
          _RouteCard(parcel: parcel),
          const SizedBox(height: AppDimens.md),
          if (parcel.driver != null) _DriverCard(parcel: parcel),
          if (parcel.driver == null && parcel.isPaid) ...[
            const SizedBox(height: AppDimens.md),
            Card(
              color: AppColors.goldLight,
              child: const ListTile(
                leading: Icon(Icons.hourglass_top, color: AppColors.goldDark),
                title: Text('Colis payé', style: TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w600)),
                subtitle: Text('Un livreur sera bientôt affecté à votre colis.'),
              ),
            ),
          ],
          if (parcel.isAwaitingPayment) ...[
            const SizedBox(height: AppDimens.md),
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Paiement requis'),
                subtitle: Text('Frais de livraison : ${formatAmount(parcel.deliveryFee)}'),
                trailing: _actionId == 'pay'
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: _actionId == null ? _pay : null,
              ),
            ),
          ],
          const SizedBox(height: AppDimens.md),
          _Timeline(history: parcel.statusHistory),
          if (parcel.cancellationReason != null) ...[
            const SizedBox(height: AppDimens.md),
            Card(
              child: ListTile(
                leading: Icon(Icons.cancel_outlined, color: theme.colorScheme.error),
                title: const Text('Motif d\'annulation'),
                subtitle: Text(parcel.cancellationReason!),
              ),
            ),
          ],
          const SizedBox(height: AppDimens.xl),
          if (parcel.isAwaitingPayment) ...[
            AppButton(
              label: 'Payer maintenant',
              icon: Icons.payment,
              onPressed: _actionId == null ? _pay : null,
            ),
            const SizedBox(height: AppDimens.sm),
            AppButton(
              label: 'Annuler le colis',
              variant: AppButtonVariant.danger,
              onPressed: _actionId == null ? _cancel : null,
              loading: _actionId == 'cancel',
            ),
          ],
          const SizedBox(height: AppDimens.xxl),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.parcel});

  final Parcel parcel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          children: [
            _RouteRow(
              icon: Icons.trip_origin,
              color: AppColors.green,
              title: 'Ramassage',
              text: parcel.pickup?.display ?? '—',
            ),
            const SizedBox(height: AppDimens.sm),
            _RouteRow(
              icon: Icons.place,
              color: AppColors.orange,
              title: 'Livraison',
              text: parcel.dropoff?.display ?? '—',
            ),
            const Divider(height: AppDimens.xl),
            Row(
              children: [
                const Expanded(
                  child: Text('Frais de livraison', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                AmountText(parcel.deliveryFee, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.icon, required this.color, required this.title, required this.text});

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.parcel});

  final Parcel parcel;

  @override
  Widget build(BuildContext context) {
    final driver = parcel.driver!;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.goldLight,
          child: Icon(Icons.delivery_dining, color: AppColors.goldDark),
        ),
        title: Text(driver.name ?? 'Livreur Béninfood', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [driver.vehicle, driver.phone].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.history});

  final List<ParcelStatusStep> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Suivi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: AppDimens.md),
            for (var i = 0; i < history.length; i++) ...[
              _TimelineStep(step: history[history.length - 1 - i], isLast: i == 0),
              if (i != history.length - 1)
                const SizedBox(height: AppDimens.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.step, required this.isLast});

  final ParcelStatusStep step;
  final bool isLast;

  String get _label {
    final to = step.toStatus ?? '';
    return _statusLabel(to);
  }

  String _statusLabel(String status) => switch (status) {
        'awaiting_payment' => 'En attente de paiement',
        'paid' => 'Colis payé',
        'assigned' => 'Livreur affecté',
        'picked_up' => 'Colis récupéré',
        'in_delivery' => 'En livraison',
        'delivered' => 'Livré',
        'cancelled' => 'Annulé',
        'refunded' => 'Remboursé',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isLast ? AppColors.orange : AppColors.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_label, style: TextStyle(fontSize: 13.5, fontWeight: isLast ? FontWeight.w800 : FontWeight.w600)),
              if (step.createdAt != null)
                Text(
                  formatDateTime(step.createdAt, fallback: ''),
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}