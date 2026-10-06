import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/geo.dart';
import '../../../shared/models/delivery.dart';
import '../../../shared/models/geo_point.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/call_button.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/package_item_tile.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Détail d'une mission (J162) : informations et actions de progression.
class MissionDetailScreen extends StatefulWidget {
  const MissionDetailScreen({
    super.key,
    required this.marketplace,
    required this.deliveryId,
    this.initialDelivery,
  });

  final MarketplaceApi marketplace;
  final String deliveryId;
  final Delivery? initialDelivery;

  @override
  State<MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends State<MissionDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _locationInterval = Duration(seconds: 15);

  Delivery? _delivery;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  Timer? _locationTimer;
  bool _sendingLocation = false;
  LocationFailure? _reportedFailure;

  /// Position GPS courante du livreur (carte + guidage).
  GeoPoint? _position;

  StreamSubscription<GeoResult>? _positionSubscription;

  static const _activeStatuses = {'assigned', 'picked_up', 'in_delivery'};

  @override
  void initState() {
    super.initState();
    _delivery = widget.initialDelivery;
    _load();
    _startPositionStream();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  /// Suit la position en continu : la carte se recentre automatiquement et le
  /// bandeau de guidage affiche distance / cap / temps estimé.
  void _startPositionStream() {
    _positionSubscription?.cancel();
    _positionSubscription = LocationService.watch().listen(
      (geo) {
        if (!mounted) {
          return;
        }
        setState(() => _position = GeoPoint(geo.latitude, geo.longitude));
      },
      onError: (_) {
        // Permission refusée / GPS coupé : la carte reste sur la destination.
      },
    );
  }

  bool get _shouldReportLocation =>
      _delivery != null && _activeStatuses.contains(_delivery!.status);

  void _syncLocationReporting() {
    _locationTimer?.cancel();
    _locationTimer = null;
    if (!_shouldReportLocation) {
      return;
    }
    _sendLocation();
    _locationTimer = Timer.periodic(_locationInterval, (_) => _sendLocation());
  }

  /// Phase « collecte » : la cible du guidage est le vendeur.
  bool get _isPickupPhase {
    final status = _delivery?.status;
    return status == 'assigned' || status == 'available' || status == 'proposed';
  }

  /// Destination affichée sur la carte et dans le bandeau de guidage.
  GeoPoint? get _target => _isPickupPhase ? _delivery?.pickupPoint : _delivery?.dropoffPoint;

  String get _targetTitle => _isPickupPhase
      ? 'Rejoindre le point de collecte'
      : 'Direction l\'adresse de livraison';

  String? get _targetAddress =>
      _isPickupPhase ? _delivery?.vendor?.address : _delivery?.order?.address;

  double? get _distanceKm {
    final target = _target;
    final position = _position;
    if (target == null || position == null) {
      return null;
    }
    return distanceKm(position.latLng, target.latLng);
  }

  double? get _bearing {
    final target = _target;
    final position = _position;
    if (target == null || position == null) {
      return null;
    }
    return bearingDegrees(position.latLng, target.latLng);
  }

  Future<void> _sendLocation() async {
    if (_sendingLocation) {
      return;
    }
    _sendingLocation = true;
    try {
      // Le flux de position alimente la carte : on le réutilise pour éviter une
      // seconde acquisition GPS, et on retombe sur `locate()` si besoin.
      final known = _position;
      if (known != null) {
        if (mounted && _shouldReportLocation) {
          await widget.marketplace.updateDriverLocation(known.latitude, known.longitude);
        }
        return;
      }
      final result = await LocationService.locate();
      if (result.isSuccess) {
        final geo = result.geo!;
        _reportedFailure = null;
        if (mounted) {
          setState(() => _position = GeoPoint(geo.latitude, geo.longitude));
        }
        if (mounted && _shouldReportLocation) {
          await widget.marketplace.updateDriverLocation(geo.latitude, geo.longitude);
        }
        return;
      }
      if (mounted && _shouldReportLocation && _reportedFailure != result.failure) {
        _reportedFailure = result.failure;
        showToast(context, _locationFailureMessage(result.failure), isError: true);
      }
    } catch (_) {
      // Position indisponible : on réessaiera au prochain tick.
    } finally {
      _sendingLocation = false;
    }
  }

  static String _locationFailureMessage(LocationFailure? failure) => switch (failure) {
        LocationFailure.serviceDisabled =>
          'Suivi interrompu : activez le GPS pour être localisé.',
        LocationFailure.permissionDenied =>
          'Suivi interrompu : autorisez la localisation dans les réglages pour le client.',
        _ => 'Position introuvable : votre position sera retransmise dès que possible.',
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deliveries = await widget.marketplace.myDeliveries();
      Delivery? match;
      for (final delivery in deliveries) {
        if (delivery.id == widget.deliveryId) {
          match = delivery;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _delivery = match ?? _delivery;
          _loading = false;
        });
        _syncLocationReporting();
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

  Future<void> _run(Future<Delivery> Function() action, String successMessage) async {
    setState(() => _actionLoading = true);
    try {
      final updated = await action();
      if (mounted) {
        setState(() {
          _delivery = updated;
          _actionLoading = false;
        });
        _syncLocationReporting();
        showToast(context, successMessage);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _pickup() => _run(
        () => widget.marketplace.markPickedUp(widget.deliveryId),
        'Commande récupérée. Cap sur la livraison.',
      );

  Future<void> _start() => _run(
        () => widget.marketplace.markInDelivery(widget.deliveryId),
        'Livraison démarrée.',
      );

  Future<void> _deliver() async {
    final proofCode = await _askProofCode();
    if (!mounted) {
      return;
    }
    await _run(
      () => widget.marketplace.markDelivered(widget.deliveryId, proofCode: proofCode),
      'Commande livrée.',
    );
  }

  Future<void> _incident() async {
    final message = await _askIncidentMessage();
    if (message == null || !mounted) {
      return;
    }
    await _run(
      () => widget.marketplace.reportIncident(widget.deliveryId, message),
      'Incident signalé.',
    );
  }

  Future<String?> _askProofCode() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
        title: const Text('Preuve de livraison'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Code de confirmation',
            hintText: 'Optionnel',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askIncidentMessage() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
        title: const Text('Signaler un incident'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: "Décrivez l'incident *",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Retour'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (controller.text.trim().length >= 3) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de la mission'),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.orange,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _delivery == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _delivery == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final delivery = _delivery;
    if (delivery == null) {
      return const EmptyState(icon: Icons.search_off, title: 'Mission introuvable');
    }

    final palette = BadgePalette.delivery(delivery.status);
    final order = delivery.order;
    final vendor = delivery.vendor;
    final status = delivery.status;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        children: [
          // Order reference + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order?.reference ?? 'Mission',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (palette != null) StatusBadge(label: palette.$1, color: palette.$2),
            ],
          ),
          const SizedBox(height: AppDimens.lg),

          // Guidage GPS : la cible suit l'avancement de la mission
          // (collecte chez le vendeur -> adresse du client).
          MapGuidanceBar(
            title: _targetTitle,
            distanceKm: _distanceKm,
            bearing: _bearing,
            etaMinutes: estimateMinutes(_distanceKm ?? 0),
            address: _targetAddress,
            waitingForPosition: _position == null,
            accent: _isPickupPhase ? AppColors.gold : AppColors.orange,
          ),
          const SizedBox(height: AppDimens.sm),
          AppMap(
            origin: _position,
            target: _target,
            secondary: _isPickupPhase ? _delivery?.dropoffPoint : _delivery?.pickupPoint,
            secondaryLabel: _isPickupPhase ? 'Livraison' : 'Collecte',
            height: 250,
            followOrigin: true,
          ),
          const SizedBox(height: AppDimens.md),

          // Vendor + client info card (avec appels directs)
          _MissionInfoCard(
            vendor: vendor,
            order: order,
          ),
          const SizedBox(height: AppDimens.md),

          // Contenu du colis : photos + quantités à collecter/livrer
          if (order?.items.isNotEmpty ?? false)
            PackageContentCard(
              children: [
                for (final item in order!.items)
                  PackageItemTile(
                    name: item.name,
                    quantity: item.quantity,
                    imageUrl: item.imageUrl,
                    dense: true,
                  ),
              ],
            ),
          const SizedBox(height: AppDimens.md),

          // Fee summary card
          _FeeCard(delivery: delivery),
          const SizedBox(height: AppDimens.md),

          // Animated step timeline
          _AnimatedTimeline(status: status),
          const SizedBox(height: AppDimens.xl),

          // Action buttons
          if (status == 'assigned')
            AppButton(
              label: "J'ai récupéré la commande",
              icon: Icons.inventory_2_outlined,
              onPressed: _actionLoading ? null : _pickup,
              loading: _actionLoading,
            ),
          if (status == 'picked_up')
            AppButton(
              label: 'Démarrer la livraison',
              icon: Icons.directions_bike,
              onPressed: _actionLoading ? null : _start,
              loading: _actionLoading,
            ),
          if (status == 'in_delivery')
            AppButton(
              label: 'Livrer',
              icon: Icons.check_circle_outline,
              onPressed: _actionLoading ? null : _deliver,
              loading: _actionLoading,
            ),
          const SizedBox(height: AppDimens.sm),
          AppButton(
            label: 'Signaler un incident',
            variant: AppButtonVariant.outline,
            icon: Icons.report_problem_outlined,
            onPressed: _actionLoading ? null : _incident,
          ),
        ],
      ),
    );
  }
}

/// Carte d'information : point de collecte (vendeur) + livraison (client).
class _MissionInfoCard extends StatelessWidget {
  const _MissionInfoCard({required this.vendor, required this.order});

  final DeliveryVendor? vendor;
  final DeliveryOrder? order;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          children: [
            // Collecte
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.orange.withValues(alpha: 0.1),
                child: const Icon(Icons.storefront_outlined, color: AppColors.orange),
              ),
              title: const Text(
                'Collecte',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              subtitle: Text(
                [
                  vendor?.businessName ?? 'Vendeur',
                  vendor?.address ?? '',
                  vendor?.city ?? '',
                ].where((e) => e.isNotEmpty).join('\n'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: (vendor?.phone?.trim().isNotEmpty ?? false)
                  ? CallButton(
                      label: 'Appeler',
                      phone: vendor!.phone,
                      compact: true,
                    )
                  : null,
            ),
            const Divider(height: 1, indent: 56),
            // Client
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.gold.withValues(alpha: 0.1),
                child: const Icon(Icons.person_outline, color: AppColors.gold),
              ),
              title: Text(
                order?.client?.name ?? 'Client',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              subtitle: order?.client?.phone != null
                  ? Text(
                      order!.client!.phone!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    )
                  : null,
              trailing: (order?.client?.phone?.trim().isNotEmpty ?? false)
                  ? CallButton(
                      label: 'Appeler le client',
                      phone: order!.client!.phone,
                      compact: true,
                    )
                  : null,
            ),
            const Divider(height: 1, indent: 56),
            // Livraison
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.green.withValues(alpha: 0.1),
                child: const Icon(Icons.location_on_outlined, color: AppColors.green),
              ),
              title: const Text(
                'Adresse de livraison',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              subtitle: Text(
                order?.address ?? '—',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte récapitulatif des frais.
class _FeeCard extends StatelessWidget {
  const _FeeCard({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          children: [
            Row(
              children: [
                Text('Frais de livraison', style: theme.textTheme.bodyMedium),
                const Spacer(),
                AmountText(
                  delivery.fee,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.orange),
                ),
              ],
            ),
            if (delivery.partnerAmount != null) ...[
              const SizedBox(height: AppDimens.xs),
              Row(
                children: [
                  Text('Votre part', style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  AmountText(
                    delivery.partnerAmount,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chronologie animée des étapes de la mission.
///
/// Les étapes suivent l'ordre : Créée → Affectée → Collectée → Livrée.
/// Chaque étape est animée : icône qui passe au bon couleur, pulse pour l'étape courante.
class _AnimatedTimeline extends StatelessWidget {
  const _AnimatedTimeline({required this.status});

  final String status;

  static const _steps = [
    _TimelineStep('Créée', Icons.fiber_manual_record, AppColors.ivory),
    _TimelineStep('Affectée', Icons.motorcycle, AppColors.orange),
    _TimelineStep('Collectée', Icons.inventory_2, AppColors.gold),
    _TimelineStep('Livrée', Icons.check_circle, AppColors.green),
  ];

  int get _currentStepIndex {
    return switch (status) {
      'assigned' => 1,
      'picked_up' => 2,
      'in_delivery' || 'delivered' => 3,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final completedIndex = _currentStepIndex;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chronologie',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppDimens.md),
            ...List.generate(_steps.length, (index) {
              final step = _steps[index];
              final isCompleted = index <= completedIndex;
              final isCurrent = index == completedIndex;

              final color = isCompleted
                  ? step.color
                  : AppColors.textSecondary;
              final backgroundColor = isCompleted
                  ? step.color.withValues(alpha: 0.15)
                  : AppColors.textSecondary.withValues(alpha: 0.1);

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  // `Curves.easeOutBack` dépasse 1.0 : on borne l'opacité
                  // (l'assertion `0 <= opacity <= 1` planterait sinon).
                  return Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Padding(
                      padding: EdgeInsets.only(top: isCurrent ? 0 : 0, bottom: AppDimens.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Indicator circle with animation
                          Transform.scale(
                            scale: isCurrent ? 1.1 : 1.0,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color,
                                  width: isCompleted ? 2 : 1,
                                ),
                              ),
                              child: Icon(
                                step.icon,
                                size: 18,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimens.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.label,
                                  style: TextStyle(
                                    fontWeight: isCompleted
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: color,
                                  ),
                                ),
                                if (isCurrent && status == 'assigned' ||
                                    isCurrent && status == 'picked_up' ||
                                    isCurrent && status == 'in_delivery')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _statusMessage(status),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  String _statusMessage(String status) => switch (status) {
        'assigned' => "En attente de la collecte chez le vendeur.",
        'picked_up' => "Direction l'adresse de livraison.",
        'in_delivery' => "Livraison en cours, position partagée.",
        _ => '',
      };
}

class _TimelineStep {
  const _TimelineStep(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
