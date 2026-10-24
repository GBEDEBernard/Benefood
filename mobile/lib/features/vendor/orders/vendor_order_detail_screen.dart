import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/services/route_planner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../shared/models/geo_point.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/route_plan.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/favorite_driver_picker.dart';
import '../../../shared/widgets/package_item_tile.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Détail d'une commande vendeur (J156) : articles, totaux, adresse, actions.
class VendorOrderDetailScreen extends StatefulWidget {
  const VendorOrderDetailScreen({super.key, required this.marketplace, required this.order});

  final MarketplaceApi marketplace;
  final Order order;

  @override
  State<VendorOrderDetailScreen> createState() => _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState extends State<VendorOrderDetailScreen> {
  static const _pollInterval = Duration(seconds: 4);

  Order? _order;
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

  Timer? _pollTimer;
  bool _polling = false;

  late final RoutePlanner _routePlanner;
  RoutePlan? _route;
  bool _routeInFlight = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _routePlanner = RoutePlanner(widget.marketplace);
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool get _shouldPoll => _order?.delivery?.isActive ?? false;

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
      final order = await widget.marketplace.vendorOrder(widget.order.id);
      if (mounted) {
        setState(() {
          _order = order;
          _error = null;
        });
        _updateRoute();
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
      final order = await widget.marketplace.vendorOrder(widget.order.id);
      if (mounted) {
        setState(() {
          _order = order;
          _loading = false;
        });
        _schedulePolling();
        _updateRoute();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
        _schedulePolling();
      }
    }
  }

  GeoPoint? get _trackingTarget {
    final order = _order;
    final delivery = order?.delivery;
    if (order == null || delivery == null) {
      return null;
    }
    return delivery.status == 'assigned' || delivery.status == 'en_route_pickup'
        ? order.vendor?.point
        : order.dropoffPoint;
  }

  Future<void> _updateRoute() async {
    final order = _order;
    final position = order?.delivery?.position?.point;
    final target = _trackingTarget;
    if (order == null ||
        position == null ||
        target == null ||
        !(order.delivery?.isActive ?? false)) {
      return;
    }
    if (_routeInFlight) {
      return;
    }

    _routeInFlight = true;
    final plan = await _routePlanner.plan([position, target]);
    if (!mounted) {
      return;
    }
    setState(() {
      _routeInFlight = false;
      if (plan != null) {
        _route = plan;
      }
    });
  }

  Future<void> _runAction(Future<Order> Function() call, {required String successLabel}) async {
    setState(() => _actionLoading = true);
    try {
      final updated = await call();
      if (mounted) {
        setState(() => _order = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successLabel), behavior: SnackBarBehavior.floating),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<String?> _askReason(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Raison *'),
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

  Future<void> _accept() async {
    final order = _order ?? widget.order;
    await _runAction(() => widget.marketplace.vendorAccept(order.id), successLabel: 'Commande acceptée');
  }

  Future<void> _refuse() async {
    final order = _order ?? widget.order;
    final reason = await _askReason('Refuser la commande');
    if (reason == null || !mounted) {
      return;
    }
    await _runAction(() => widget.marketplace.vendorRefuse(order.id, reason: reason), successLabel: 'Commande refusée');
  }

  Future<void> _prepare() async {
    final order = _order ?? widget.order;
    await _runAction(() => widget.marketplace.vendorPreparing(order.id), successLabel: 'Préparation commencée');
  }

  Future<void> _ready() async {
    final order = _order ?? widget.order;
    final choice = await showFavoriteDriverPicker(
      context,
      widget.marketplace,
      title: 'Livreur favori (optionnel)',
    );
    if (choice == null || !mounted) {
      return;
    }
    await _runAction(
      () => widget.marketplace.vendorReady(order.id, favoriteDriverId: choice.driverId),
      successLabel: choice.isNone
          ? 'Commande marquée prête'
          : 'Commande prête — offre réservée à ${choice.label}',
    );
  }

  Future<void> _cancel() async {
    final order = _order ?? widget.order;
    final reason = await _askReason('Annuler la commande');
    if (reason == null || !mounted) {
      return;
    }
    await _runAction(() => widget.marketplace.vendorCancel(order.id, reason: reason), successLabel: 'Commande annulée');
  }

  Widget _trackingCard(Order order) {
    final delivery = order.delivery!;
    final driver = delivery.driver;
    final position = delivery.position;
    final target = _trackingTarget;
    final isPickup =
        delivery.status == 'assigned' || delivery.status == 'en_route_pickup';
    final stale = (position?.ageSeconds ?? 0) >= AppConfig.staleWarnSeconds;
    final hideEta =
        (position?.ageSeconds ?? 0) >= AppConfig.staleHideEtaSeconds;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.orangeLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delivery_dining,
                    color: AppColors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver?.name ?? 'Livreur assigné',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        isPickup
                            ? 'En route vers votre boutique'
                            : 'En route vers le client',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: stale ? AppColors.goldDark : AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            if (position != null && target != null) ...[
              const SizedBox(height: 12),
              AppMap(
                origin: position.point,
                originLabel: driver?.name ?? 'Livreur',
                originHeading: position.heading,
                target: target,
                targetLabel: isPickup ? 'Votre boutique' : 'Client',
                targetIcon:
                    isPickup ? Icons.storefront_outlined : Icons.place,
                targetColor: AppColors.orange,
                secondary:
                    isPickup ? order.dropoffPoint : order.vendor?.point,
                secondaryLabel: isPickup ? 'Client' : 'Votre boutique',
                secondaryIcon:
                    isPickup ? Icons.place : Icons.storefront_outlined,
                secondaryColor: AppColors.gold,
                route: _route?.latLng,
                routeColor: AppColors.orange,
                height: 200,
                followOrigin: true,
                openInMaps: false,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.near_me_outlined,
                    size: 15,
                    color: AppColors.orange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _trackingDistanceLabel(position, target, hideEta),
                      style: const TextStyle(
                        color: AppColors.orangeDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                'Le livreur n\'a pas encore partagé sa position.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (stale && position != null) ...[
              const SizedBox(height: 8),
              Text(
                'Dernière position reçue il y a ${position.ageSeconds} s.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.goldDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _trackingDistanceLabel(
    OrderDeliveryPosition position,
    GeoPoint target,
    bool hideEta,
  ) {
    final km =
        position.distanceKm ??
        distanceKm(position.point.latLng, target.latLng);
    final label = 'À ${formatDistance(km)}';
    if (hideEta) {
      return label;
    }
    final minutes = _route?.etaMinutes ?? estimateMinutes(km);
    return minutes == null ? label : '$label · ~${formatEta(minutes)}';
  }

  @override
  Widget build(BuildContext context) {
    return BeninfoodPageScaffold(
      title: 'Commande',
      api: widget.marketplace,
      audience: NotificationAudience.vendor,
      actions: [
        IconButton(
          tooltip: 'Rafraîchir',
          icon: const Icon(Icons.refresh),
          onPressed: _actionLoading ? null : _load,
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(
        message: 'Impossible de rafraîchir la commande ($_error).',
        onRetry: _load,
      );
    }
    final order = _order ?? widget.order;
    final palette = BadgePalette.order(order.status);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Commande ${order.reference}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      formatDateTime(order.createdAt, fallback: ''),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (palette != null) StatusBadge(label: palette.$1, color: palette.$2),
            ],
          ),
          if (order.cancelledBy != null) ...[
            const SizedBox(height: 6),
            Text(
              'Annulée par : ${order.cancelledBy}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
          if (order.cancellationReason != null) ...[
            const SizedBox(height: 6),
            Text(
              'Motif : ${order.cancellationReason}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if ((order.delivery?.isActive ?? false) &&
              order.delivery?.driver != null) ...[
            const SizedBox(height: 16),
            _trackingCard(order),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Articles', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  for (final item in order.items)
                    PackageItemTile(
                      name: item.name,
                      quantity: item.quantity,
                      imageUrl: item.imageUrl,
                      trailing: formatAmount(item.subtotal, showSymbol: false),
                    ),
                  const Divider(height: 24),
                  _SummaryRow(label: 'Sous-total', amount: order.subtotal),
                  _SummaryRow(label: 'Livraison', amount: order.deliveryFee),
                  if ((order.financials?.serviceFee ?? 0) > 0)
                    _SummaryRow(label: 'Frais de service client', amount: order.financials!.serviceFee!),
                  if (order.discount > 0) _SummaryRow(label: 'Remise', amount: -order.discount),
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
          const SizedBox(height: 24),
          AppButton(
            label: 'Rafraîchir',
            variant: AppButtonVariant.outline,
            icon: Icons.refresh,
            onPressed: _actionLoading ? null : _load,
          ),
          if (order.canVendorAccept || order.canVendorRefuse || order.canVendorPrepare || order.canVendorReady || order.canCancel) ...[
            const SizedBox(height: 12),
            if (order.canVendorAccept) ...[
              AppButton(label: 'Accepter la commande', icon: Icons.check, onPressed: _actionLoading ? null : _accept, loading: _actionLoading),
              const SizedBox(height: 8),
            ],
            if (order.canVendorRefuse)
              AppButton(
                label: 'Refuser la commande',
                icon: Icons.close,
                variant: AppButtonVariant.danger,
                onPressed: _actionLoading ? null : _refuse,
              ),
            if (order.canVendorPrepare) ...[
              AppButton(
                label: 'Commencer la préparation',
                icon: Icons.restaurant_outlined,
                onPressed: _actionLoading ? null : _prepare,
                loading: _actionLoading,
              ),
            ],
            if (order.canVendorReady) ...[
              AppButton(label: 'Marquer prête', icon: Icons.check_circle_outline, onPressed: _actionLoading ? null : _ready, loading: _actionLoading),
              const SizedBox(height: 8),
            ],
            if (order.canCancel) ...[
              const SizedBox(height: 8),
              AppButton(
                label: 'Annuler la commande',
                icon: Icons.cancel_outlined,
                variant: AppButtonVariant.danger,
                onPressed: _actionLoading ? null : _cancel,
              ),
            ],
          ],
        ],
      ),
    );
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