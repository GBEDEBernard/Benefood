import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/models/parcel.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Service colis côté livreur (cahier v1.0, phase 3) :
/// offres de colis disponibles + courses assignées (accept → pickup → start → deliver).
class DriverParcelsScreen extends StatefulWidget {
  const DriverParcelsScreen({
    super.key,
    required this.marketplace,
    this.onOfferAccepted,
    this.onOpenMenu,
  });

  final MarketplaceApi marketplace;
  final VoidCallback? onOfferAccepted;

  /// Ouvre le tiroir latéral (menu hamburger) — géré par le shell livreur.
  final VoidCallback? onOpenMenu;

  @override
  State<DriverParcelsScreen> createState() => _DriverParcelsScreenState();
}

class _DriverParcelsScreenState extends State<DriverParcelsScreen> {
  List<Parcel> _runs = [];
  List<Parcel> _offers = [];
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
      final runs = await widget.marketplace.myDriverParcels();
      final offers = await widget.marketplace.driverParcelOffers();
      if (mounted) {
        setState(() {
          _runs = runs;
          _offers = offers;
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

  Future<void> _advance(Parcel parcel) async {
    switch (parcel.status) {
      case 'assigned':
      case 'en_route_pickup':
        await _runAction(parcel, widget.marketplace.pickupParcelDelivery);
      case 'picked_up':
        await _runAction(parcel, widget.marketplace.startParcelDelivery);
      case 'in_delivery':
        final code = await _askConfirmationCode();
        if (!mounted || code == null || code.isEmpty) {
          return;
        }
        await _runAction(
          parcel,
          (id) => widget.marketplace.deliverParcelDelivery(id, proofCode: code),
        );
    }
  }

  Future<String?> _askConfirmationCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        title: const Text('Code de confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Demandez le code à 6 chiffres au destinataire. Sans ce code, le colis ne peut pas être confirmé et les fonds restent bloqués.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Code à 6 chiffres *',
                hintText: '000000',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final value = controller.text.trim();
              if (value.length != 6) {
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    controller.dispose();
    return code;
  }

  Future<void> _runAction(
    Parcel parcel,
    Future<Parcel> Function(String id) action,
  ) async {
    setState(() => _actionId = parcel.id);
    try {
      await action(parcel.id);
      if (mounted) {
        showToast(context, 'Colis mis à jour.');
        widget.onOfferAccepted?.call();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BeninfoodAppBar(
            onMenu: widget.onOpenMenu,
            api: widget.marketplace,
            audience: NotificationAudience.driver,
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        children: [
          _SectionHeader(
            icon: Icons.route_outlined,
            label: 'Mes courses colis',
            count: _runs.length,
            color: AppColors.green,
          ),
          const SizedBox(height: AppDimens.sm),
          if (_runs.isEmpty)
            const _EmptyNote(
              icon: Icons.route_outlined,
              text: 'Aucune course colis en cours.',
            )
          else
            for (final run in _runs) ...[
              _RunCard(parcel: run, busy: _actionId, onAction: _advance),
              const SizedBox(height: AppDimens.sm),
            ],
          const SizedBox(height: AppDimens.xl),
          _SectionHeader(
            icon: Icons.local_offer_outlined,
            label: 'Offres de colis',
            count: _offers.length,
            color: AppColors.orange,
          ),
          const SizedBox(height: AppDimens.sm),
          if (_offers.isEmpty)
            const _EmptyNote(
              icon: Icons.inventory_2_outlined,
              text: 'Aucun colis disponible sur votre zone pour le moment.',
            )
          else
            for (final offer in _offers) ...[
              _OfferCard(
                parcel: offer,
                busy: _actionId,
                onAccept: (parcel) {
                  _runAction(parcel, widget.marketplace.acceptParcelDelivery);
                },
              ),
              const SizedBox(height: AppDimens.sm),
            ],
          const SizedBox(height: AppDimens.xxl),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({
    required this.parcel,
    required this.busy,
    required this.onAction,
  });

  final Parcel parcel;
  final String? busy;
  final ValueChanged<Parcel> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = BadgePalette.parcel(parcel.status);
    final actionLabel = switch (parcel.status) {
      'assigned' => 'J\'ai récupéré le colis',
      'en_route_pickup' => 'J\'ai récupéré le colis',
      'picked_up' => 'Commencer la livraison',
      'in_delivery' => 'Marquer comme livré',
      _ => '',
    };

    return Card(
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                if (palette != null)
                  StatusBadge(
                    label: palette.$1,
                    color: palette.$2,
                    small: true,
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            _RouteLine(
              icon: Icons.trip_origin,
              color: AppColors.green,
              text: parcel.pickup?.display ?? '—',
            ),
            const SizedBox(height: 4),
            _RouteLine(
              icon: Icons.place,
              color: AppColors.orange,
              text: parcel.dropoff?.display ?? '—',
            ),
            if (parcel.pickupPoint != null || parcel.dropoffPoint != null) ...[
              const SizedBox(height: AppDimens.sm),
              AppMap(
                target: parcel.pickupPoint,
                secondary: parcel.dropoffPoint,
                height: 110,
                initialZoom: 12,
                followOrigin: false,
                showRoute: false,
              ),
            ],
            const Divider(height: AppDimens.xl),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Votre gain',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      AmountText(
                        parcel.partnerAmount,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actionLabel.isNotEmpty)
                  AppButton(
                    label: actionLabel,
                    icon: Icons.arrow_forward,
                    fullWidth: false,
                    onPressed: busy == null ? () => onAction(parcel) : null,
                    loading: busy == parcel.id,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.parcel,
    required this.busy,
    required this.onAccept,
  });

  final Parcel parcel;
  final String? busy;
  final ValueChanged<Parcel> onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                StatusBadge(
                  label: 'Disponible',
                  color: AppColors.gold,
                  small: true,
                  icon: Icons.local_offer,
                ),
              ],
            ),
            if (parcel.description != null &&
                parcel.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                parcel.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppDimens.sm),
            _RouteLine(
              icon: Icons.trip_origin,
              color: AppColors.green,
              text: parcel.pickup?.display ?? '—',
            ),
            const SizedBox(height: 4),
            _RouteLine(
              icon: Icons.place,
              color: AppColors.orange,
              text: parcel.dropoff?.display ?? '—',
            ),
            if (parcel.pickupPoint != null || parcel.dropoffPoint != null) ...[
              const SizedBox(height: AppDimens.sm),
              AppMap(
                target: parcel.pickupPoint,
                secondary: parcel.dropoffPoint,
                height: 110,
                initialZoom: 12,
                followOrigin: false,
                showRoute: false,
              ),
            ],
            const Divider(height: AppDimens.xl),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Votre gain',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      AmountText(
                        parcel.partnerAmount,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: 'Accepter',
                  icon: Icons.check,
                  fullWidth: false,
                  onPressed: busy == null ? () => onAccept(parcel) : null,
                  loading: busy == parcel.id,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
