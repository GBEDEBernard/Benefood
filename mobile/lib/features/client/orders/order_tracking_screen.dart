import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/route_planner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../shared/models/driver_selection.dart';
import '../../../shared/models/geo_point.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/route_plan.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/call_button.dart';
import '../../../shared/widgets/driver_picker_sheet.dart';
import '../../../shared/widgets/fedapay_checkout_screen.dart';
import '../drivers/driver_selection_screen.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/package_item_tile.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Écran de suivi / détail d'une commande (J152, J177).
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({
    super.key,
    required this.marketplace,
    required this.orderId,
  });

  final MarketplaceApi marketplace;
  final String orderId;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const _pollInterval = Duration(
    seconds: AppConfig.locationIntervalSeconds,
  );

  Order? _order;
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;
  bool _reviewing = false;
  Timer? _pollTimer;
  bool _polling = false;

  /// Position GPS du client (pour se situer par rapport à la boutique).
  GeoPoint? _selfPosition;
  StreamSubscription<GeoResult>? _positionSub;

  late final RoutePlanner _routePlanner;
  RoutePlan? _route;

  /// Tronçon boutique → client (tracé bleu) affiché en complément du tronçon actif.
  RoutePlan? _deliveryLeg;

  @override
  void initState() {
    super.initState();
    _routePlanner = RoutePlanner(widget.marketplace);
    _load();
    _startPositionStream();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  /// Suit la position du client : son marqueur se déplace en direct sur la carte.
  void _startPositionStream() {
    _positionSub = LocationService.watch().listen(
      (geo) {
        if (!mounted) {
          return;
        }
        setState(() => _selfPosition = GeoPoint(geo.latitude, geo.longitude));
        _updateRoute();
      },
      onError: (_) {
        // Permission refusée / GPS coupé : la carte reste sur les points connus.
      },
    );
  }

  /// Point de la boutique (point de collecte) depuis le vendeur de la commande.
  GeoPoint? _shopPoint(Order order) => order.vendor?.point;

  /// Extrémités du tracé : livreur → adresse pendant la course, sinon moi → boutique.
  List<GeoPoint>? _routeEndpoints(Order order) {
    final driver = order.delivery?.position?.point;
    final dropoff = order.dropoffPoint;
    if (driver != null && dropoff != null) {
      return [driver, dropoff];
    }
    final self = _selfPosition;
    final shop = _shopPoint(order);
    if (self != null && shop != null) {
      return [self, shop];
    }
    return null;
  }

  Future<void> _updateRoute() async {
    final order = _order;
    if (order == null) {
      return;
    }

    // Tronçon boutique → client (indépendant de la position affichée).
    final shop = _shopPoint(order);
    final dropoff = order.dropoffPoint;
    if (shop != null && dropoff != null) {
      final leg = await _routePlanner.plan([shop, dropoff]);
      if (!mounted) {
        return;
      }
      setState(() => _deliveryLeg = leg);
    }

    final points = _routeEndpoints(order);
    if (points == null) {
      return;
    }
    final plan = await _routePlanner.plan(points);
    if (!mounted) {
      return;
    }
    setState(() => _route = plan);
  }

  bool get _shouldPoll =>
      (_order?.delivery?.isActive ?? false) ||
      (_order?.isWaitingDriver ?? false);

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

  Future<void> _openDriverSelection() async {
    final order = _order;
    if (order == null) {
      return;
    }
    final driver = await showApproachDriverSelection(
      context,
      widget.marketplace,
      targetId: order.id,
      reference: order.reference,
    );
    if (driver == null || !mounted) {
      return;
    }

    final fee = driver.approachFee ?? 0;
    final hasExistingApproach =
        order.approachDriverId != null &&
        order.approachPaymentStatus != null &&
        order.approachPaymentStatus != 'failed';
    final method = hasExistingApproach
        ? (order.approachPaymentMethod ?? 'online')
        : await _askApproachPaymentMethod(driver, fee);
    if (method == null || !mounted) {
      return;
    }

    setState(() => _actionLoading = true);
    try {
      final payload = await widget.marketplace.createApproachPayment(
        orderId: order.id,
        driverProfileId: driver.id,
        paymentMethod: method,
      );
      if (!mounted) {
        return;
      }
      setState(() => _actionLoading = false);

      final checkoutUrl = payload['checkout_url'];
      if (method == 'online' &&
          checkoutUrl is String &&
          checkoutUrl.isNotEmpty) {
        final paid = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => FedaPayCheckoutScreen(
              marketplace: widget.marketplace,
              checkoutUrl: checkoutUrl,
              transactionId: payload['transaction_id']?.toString(),
            ),
          ),
        );
        if (!mounted) {
          return;
        }
        await _refreshSilently();
        if (!mounted) {
          return;
        }
        showToast(
          context,
          paid == true
              ? 'Frais d\'approche réglés. Votre livreur est sollicité.'
              : 'Paiement non confirmé. Vous pouvez réessayer.',
          isError: paid != true,
        );
        return;
      }

      await _refreshSilently();
      if (!mounted) {
        return;
      }
      showToast(
        context,
        method == 'cash'
            ? 'Frais d\'approche à régler en espèces à la livraison.'
            : 'Livreur choisi. Votre demande lui a été envoyée.',
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted && _actionLoading) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<String?> _askApproachPaymentMethod(NearbyDriver driver, int fee) {
    if (fee <= 0) {
      return Future.value('online');
    }
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Frais d\'approche',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '${driver.displayName} est à ${formatDistance(driver.approachDistanceKm)} de la boutique.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Supplément à régler',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    formatAmount(fee),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.orangeDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.credit_card, color: AppColors.orange),
                title: const Text('Payer en ligne'),
                subtitle: const Text('Mobile Money via FedaPay'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(sheetContext).pop('online'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.payments_outlined,
                  color: AppColors.orange,
                ),
                title: const Text('Payer à la livraison'),
                subtitle: const Text('En espèces, en plus de la course'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(sheetContext).pop('cash'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelDriverRequest() async {
    final order = _order;
    if (order == null) {
      return;
    }
    setState(() => _actionLoading = true);
    try {
      await widget.marketplace.cancelOrderDriverRequest(order.id);
      if (mounted) {
        showToast(context, 'Demande de livreur annulée.');
      }
      await _refreshSilently();
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
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
        _updateRoute();
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
      final order = await widget.marketplace.cancelOrder(
        widget.orderId,
        reason,
      );
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

  bool _canReassign(Order order) {
    final afterPickup =
        order.status == 'picked_up' || order.status == 'in_delivery';
    final beforePickupWithIncident =
        order.status == 'assigned' &&
        (order.delivery?.hasOpenIncident ?? false);
    return (afterPickup || beforePickupWithIncident) &&
        order.delivery?.driver != null;
  }

  Future<void> _changeDriver() async {
    final order = _order;
    if (order == null) {
      return;
    }
    final beforePickup = order.status == 'assigned';
    final driverPoint = order.delivery?.position?.point;
    final searchPoint = beforePickup
        ? (order.vendor?.point ?? driverPoint ?? order.dropoffPoint)
        : (driverPoint ?? order.dropoffPoint);
    if (searchPoint == null) {
      showToast(
        context,
        'Position de remise indisponible. Réessayez lorsque le suivi GPS est actif.',
        isError: true,
      );
      return;
    }

    final reason = await _askReassignReason();
    if (reason == null || !mounted) {
      return;
    }

    setState(() => _actionLoading = true);
    try {
      final drivers = await widget.marketplace.replacementDrivers(
        order.id,
        latitude: searchPoint.latitude,
        longitude: searchPoint.longitude,
      );
      if (!mounted) {
        return;
      }
      if (drivers.isEmpty) {
        showToast(
          context,
          'Aucun livreur disponible autour du point de remise.',
          isError: true,
        );
        return;
      }

      setState(() => _actionLoading = false);
      final choice = await showDriverPickerSheet(
        context,
        drivers: drivers,
        title: 'Choisir le nouveau livreur',
        subtitle: beforePickup
            ? 'Le nouveau livreur se rendra au point de collecte. Aucun frais supplémentaire ne vous sera facturé.'
            : 'La course sera partagée au prorata du trajet déjà effectué. Aucun frais supplémentaire ne vous sera facturé.',
      );
      if (choice == null || !mounted) {
        return;
      }

      setState(() => _actionLoading = true);
      final result = await widget.marketplace.reassignOrder(
        order.id,
        driverProfileId: choice.id,
        reason: reason,
        latitude: driverPoint?.latitude,
        longitude: driverPoint?.longitude,
      );
      if (!mounted) {
        return;
      }
      await _refreshSilently();
      if (!mounted) {
        return;
      }
      final code = result['handover_code']?.toString();
      if (code != null && code.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Nouveau livreur affecté'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Code de remise à communiquer au nouveau livreur :'),
                const SizedBox(height: 12),
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Compris'),
              ),
            ],
          ),
        );
      }
      if (mounted) {
        showToast(
          context,
          beforePickup
              ? '${choice.displayName} reprend la course.'
              : '${choice.displayName} reprend la livraison.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<String?> _askReassignReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer de livreur'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Que s\'est-il passé ? *',
            hintText: 'Livreur injoignable, colis endommagé…',
          ),
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
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
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
          decoration: const InputDecoration(
            labelText: 'Raison de l\'annulation *',
          ),
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

  Future<void> _submitReview({
    required int rating,
    int? driverRating,
    String? comment,
  }) async {
    setState(() => _reviewing = true);
    try {
      await widget.marketplace.reviewOrder(
        widget.orderId,
        rating: rating,
        driverRating: driverRating,
        comment: comment,
      );
      await _load();
      if (mounted) {
        showToast(context, 'Merci pour votre avis !');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _reviewing = false);
      }
    }
  }

  void _openReviewDialog(Order order) {
    final canRateDriver = order.delivery?.driver != null;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ReviewDialog(
        canRateDriver: canRateDriver,
        onCancel: () => Navigator.of(dialogContext).pop(),
        onSubmit: (rating, driverRating, comment) {
          Navigator.of(dialogContext).pop();
          _submitReview(
            rating: rating,
            driverRating: driverRating,
            comment: comment,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BeninfoodPageScaffold(
      title: 'Suivi de commande',
      api: widget.marketplace,
      body: _buildBody(),
    );
  }

  String _statusLabel(Order order) {
    if (order.isCash && order.isAwaitingPayment) {
      // Commande en espèces : rien à régler en ligne, le livreur encaisse.
      return 'Paiement à la livraison';
    }

    return switch (order.status) {
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
      _ => order.status.replaceAll('_', ' '),
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'awaiting_payment' => AppColors.goldDark,
      'paid' => AppColors.orange,
      'accepted' => AppColors.orange,
      'preparing' => const Color(0xFF1976D2),
      'ready' => AppColors.orangeDark,
      'assigned' => AppColors.orangeDark,
      'out_for_delivery' => AppColors.orange,
      'delivered' => AppColors.orange,
      'cancelled' => AppColors.red,
      'refunded' => AppColors.textSecondary,
      _ => AppColors.orange,
    };
  }

  /// Carte de suivi « ultra pro ».
  ///
  /// - Avant l'affectation d'un livreur : ma position (point bleu) → boutique,
  ///   pour que le client se situe par rapport au lieu de sa commande.
  /// - Pendant la course : position du livreur (moto) → adresse de livraison,
  ///   tracé routier réel et mise à jour toutes les 4 s.
  Widget _liveTrackingMap(Order order) {
    final driver = order.delivery?.position?.point;
    final dropoff = order.dropoffPoint;
    final shop = _shopPoint(order);
    final self = _selfPosition;

    if (driver != null && dropoff != null) {
      return AppMap(
        origin: driver,
        originLabel: order.delivery?.driver?.name ?? 'Livreur',
        originImageUrl: order.delivery?.driver?.avatarUrl,
        originHeading: order.delivery?.position?.heading,
        target: dropoff,
        targetLabel: 'Vous',
        targetImageUrl: order.customerAvatarUrl,
        targetIcon: Icons.place,
        targetColor: AppColors.orange,
        secondary: shop,
        secondaryLabel: order.vendor?.businessName ?? 'Boutique',
        secondaryImageUrl: order.vendor?.logoUrl,
        secondaryIcon: Icons.storefront_outlined,
        secondaryColor: AppColors.gold,
        route: _route?.latLng,
        routeColor: AppColors.blue,
        extraRoute: _deliveryLeg?.latLng,
        height: 240,
        followOrigin: true,
      );
    }

    if (self != null && shop != null) {
      return AppMap(
        origin: self,
        originIsDriver: false,
        originLabel: 'Vous',
        originImageUrl: order.customerAvatarUrl,
        target: shop,
        targetLabel: order.vendor?.businessName ?? 'Boutique',
        targetImageUrl: order.vendor?.logoUrl,
        targetIcon: Icons.storefront_outlined,
        targetColor: AppColors.gold,
        secondary: dropoff,
        secondaryLabel: 'Adresse de livraison',
        secondaryImageUrl: order.customerAvatarUrl,
        secondaryIcon: Icons.place,
        secondaryColor: AppColors.orange,
        route: _route?.latLng,
        routeColor: AppColors.blue,
        height: 240,
        followOrigin: true,
      );
    }

    if (shop == null && dropoff == null) {
      return const SizedBox.shrink();
    }

    return AppMap(
      origin: self,
      originIsDriver: false,
      originLabel: 'Vous',
      originImageUrl: order.customerAvatarUrl,
      target: shop ?? dropoff,
      targetLabel: shop != null
          ? (order.vendor?.businessName ?? 'Boutique')
          : 'Adresse de livraison',
      targetImageUrl: shop != null
          ? order.vendor?.logoUrl
          : order.customerAvatarUrl,
      targetIcon: shop != null ? Icons.storefront_outlined : Icons.place,
      targetColor: shop != null ? AppColors.gold : AppColors.orange,
      secondary: shop != null ? dropoff : null,
      secondaryImageUrl: shop != null ? order.customerAvatarUrl : null,
      secondaryIcon: Icons.place,
      secondaryColor: AppColors.orange,
      routeColor: AppColors.blue,
      height: 240,
      followOrigin: self != null,
      openInMaps: false,
    );
  }

  /// Carte livreur premium : identité, suivi en direct et appel direct.
  Widget? _trackingCard(Order order) {
    final delivery = order.delivery;
    final driver = delivery?.driver;
    final position = delivery?.position;
    if (delivery == null || driver == null) {
      return null;
    }

    final theme = Theme.of(context);
    final tracking = position != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.orangeLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delivery_dining,
                  color: AppColors.orange,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name ?? 'Votre livreur',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (driver.vehicle != null &&
                            driver.vehicle!.isNotEmpty) ...[
                          const Icon(
                            Icons.two_wheeler,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            driver.vehicle!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (driver.rating != null) ...[
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            driver.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (tracking)
                _LiveDot(
                  color: _positionIsStale(position)
                      ? AppColors.goldDark
                      : AppColors.orange,
                ),
            ],
          ),
          if (tracking) ...[
            const SizedBox(height: 12),
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
                    _distanceLabel(order),
                    style: const TextStyle(
                      color: AppColors.orangeDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
            if (position.lastLocationAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Position envoyée le ${formatDateTime(position.lastLocationAt, fallback: '')}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (_positionIsStale(position))
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 15,
                      color: AppColors.goldDark,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _stalePositionLabel(position),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.goldDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else if (order.dropoffPoint != null) ...[
            const SizedBox(height: 8),
            Text(
              'Le livreur n\'a pas encore partagé sa position.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          // --- Appel direct du livreur (téléphone exposé par l'API) ---
          CallButton(
            label: 'Appeler le livreur',
            phone: driver.phone,
            onEmptyPhone: () => showToast(
              context,
              'Numéro du livreur indisponible.',
              isError: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Vrai quand la position n'a pas été rafraîchie depuis le seuil d'alerte.
  bool _positionIsStale(OrderDeliveryPosition? position) {
    final age = position?.ageSeconds;
    return age != null && age >= AppConfig.staleWarnSeconds;
  }

  /// Au-delà du seuil critique, l'ETA n'est plus affichée (position trop vieille).
  bool _etaIsHidden(OrderDeliveryPosition? position) {
    final age = position?.ageSeconds;
    return age != null && age >= AppConfig.staleHideEtaSeconds;
  }

  String _stalePositionLabel(OrderDeliveryPosition position) {
    final age = position.ageSeconds ?? 0;
    if (age < 60) {
      return 'Position non rafraîchie depuis $age s';
    }
    return 'Position non rafraîchie depuis ${(age / 60).floor()} min';
  }

  /// Distance livreur -> adresse : `distance_km` de l'API, sinon calculée ici.
  /// L'ETA privilégie l'itinéraire routier réel (`_route`) quand il est connu,
  /// sinon retombe sur l'estimation à vol d'oiseau.
  String _distanceLabel(Order order) {
    final position = order.delivery?.position;
    if (position == null) {
      return '—';
    }
    final dropoff = order.dropoffPoint;
    final km =
        position.distanceKm ??
        (dropoff == null
            ? null
            : distanceKm(position.point.latLng, dropoff.latLng));
    final label = 'À ${formatDistance(km)} de vous';
    if (_etaIsHidden(position)) {
      return label;
    }
    final routeMinutes = _route?.etaMinutes;
    final minutes = routeMinutes ?? estimateMinutes(km ?? 0);
    return minutes == null ? label : '$label · ~${formatEta(minutes)}';
  }

  /// Carte de choix / attente d'un livreur proche après paiement.
  Widget? _driverSelectionCard(Order order) {
    final request = order.driverRequest;

    if (request != null && request.isPending) {
      return _WaitingDriverCard(
        request: request,
        cancelling: _actionLoading,
        onCancel: _cancelDriverRequest,
      );
    }

    if (!order.canChooseDriver) {
      return null;
    }

    return _ChooseDriverCard(
      refused: request?.isRefused ?? false,
      expired: request?.isExpired ?? false,
      reason: request?.refusalReason,
      onChoose: _openDriverSelection,
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
            label: _statusLabel(order),
            onCancel: order.canCancel ? _cancel : null,
          ),
          const SizedBox(height: 16),
          _liveTrackingMap(order),
          const SizedBox(height: 16),
          if (_driverSelectionCard(order) != null) ...[
            _driverSelectionCard(order)!,
            const SizedBox(height: 16),
          ],
          if (_canReassign(order)) ...[
            Card(
              child: ListTile(
                onTap: _actionLoading ? null : _changeDriver,
                leading: const Icon(Icons.swap_horiz, color: AppColors.orange),
                title: const Text('Changer de livreur'),
                subtitle: const Text(
                  'Le nouveau livreur reprend le colis au point de remise.',
                ),
                trailing: _actionLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (order.canCancel ||
              order.isAwaitingPayment ||
              order.isPaid ||
              order.status == 'accepted')
            _ProgressStepper(order: order, accent: accent),
          const SizedBox(height: 8),
          if (order.paymentStatus.isNotEmpty) ...[
            _PaymentStatusRow(order: order),
            const SizedBox(height: 12),
          ],
          if (!order.isCancelled &&
              (order.confirmationCode?.isNotEmpty ?? false)) ...[
            _ConfirmationCodeCard(code: order.confirmationCode!),
            const SizedBox(height: 12),
          ],
          if (order.statusHistory.isNotEmpty)
            _Timeline(history: order.statusHistory),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Articles',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                  _SummaryRow(
                    label: 'Livraison (base)',
                    amount: order.deliveryFee,
                  ),
                  if (order.approachFee > 0)
                    _SummaryRow(
                      label: 'Approche livreur',
                      amount: order.approachFee,
                    ),
                  if ((order.financials?.serviceFee ?? 0) > 0)
                    _SummaryRow(
                      label: 'Commission client',
                      amount: order.financials!.serviceFee!,
                    ),
                  const SizedBox(height: 4),
                  _SummaryRow(
                    label: 'Total',
                    amount: order.total,
                    emphasized: true,
                  ),
                ],
              ),
            ),
          ),
          if (order.deliveryAddress != null &&
              order.deliveryAddress!.isNotEmpty) ...[
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
                leading: Icon(
                  Icons.cancel_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
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
            onPressed: () => context.push(
              '/client/complaints/new',
              extra: {'order_id': order.id},
            ),
          ),
          if (order.isDelivered) ...[
            const SizedBox(height: AppDimens.md),
            if (order.hasReview) ...[
              _ReviewCard(review: order.review!),
            ] else ...[
              AppButton(
                label: 'Donner mon avis',
                variant: AppButtonVariant.outline,
                icon: Icons.star_outline,
                onPressed: _reviewing ? null : () => _openReviewDialog(order),
                loading: _reviewing,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ChooseDriverCard extends StatelessWidget {
  const _ChooseDriverCard({
    required this.refused,
    required this.expired,
    required this.reason,
    required this.onChoose,
  });

  final bool refused;
  final bool expired;
  final String? reason;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showNotice = refused || expired;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        side: const BorderSide(color: AppColors.border),
      ),
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
                  decoration: BoxDecoration(
                    color: AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(12),
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
                      const Text(
                        'Choisissez votre livreur',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Livreurs proches, distances et délais de route en temps réel.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showNotice) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  refused
                      ? 'Le livreur a décliné la demande. Choisissez un autre livreur proche.'
                      : (reason != null && reason!.trim().isNotEmpty
                            ? 'Demande expirée : ${reason!.trim()}'
                            : 'La demande a expiré. Choisissez un autre livreur proche.'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldDark,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onChoose,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.person_search_outlined, size: 19),
                label: const Text('Choisir mon livreur'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingDriverCard extends StatelessWidget {
  const _WaitingDriverCard({
    required this.request,
    required this.cancelling,
    required this.onCancel,
  });

  final DriverRequestInfo request;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final driver = request.driver;

    return Card(
      elevation: 0,
      color: AppColors.goldLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: AppNetworkImage(
                      url: driver?.avatarUrl,
                      fit: BoxFit.cover,
                      fallback: Container(
                        color: AppColors.goldLight,
                        child: const Icon(
                          Icons.delivery_dining,
                          color: AppColors.goldDark,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver?.displayName ?? 'Votre livreur',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.goldDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Demande envoyée, en attente de sa réponse…',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.goldDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.goldDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              request.waitsForReady
                  ? 'Le livreur sera notifié dès que la commande sera prête.'
                  : _countdown(request),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.goldDark,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: cancelling ? null : onCancel,
                child: Text(cancelling ? 'Annulation…' : 'Annuler la demande'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _countdown(DriverRequestInfo request) {
    final seconds = request.secondsRemaining;
    if (seconds == null) {
      return 'Le livreur peut accepter la course dès maintenant.';
    }
    if (seconds <= 0) {
      return 'La demande a expiré. Choisissez un autre livreur.';
    }
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return 'Réponse attendue sous ${minutes > 0 ? '$minutes min $rest s' : '$rest s'}.';
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
    final date = formatDateTime(order.createdAt, fallback: '');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                    if (order.payment?.paidAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Payée le ${formatDateTime(order.payment?.paidAt, fallback: '')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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
                      color: i < current ? accent : AppColors.border,
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
        : AppColors.borderStrong;
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
    final paid =
        order.paymentStatus == 'confirmed' ||
        order.paymentStatus == 'paid' ||
        order.status == 'paid' ||
        order.isDelivered;
    final cancelled = order.isCancelled;

    final Color color;
    final String label;
    final IconData icon;

    if (cancelled) {
      color = AppColors.red;
      label = 'Paiement annulé';
      icon = Icons.cancel;
    } else if (order.isCash) {
      // Paiement à la livraison : encaissé par le livreur à la remise.
      color = order.isDelivered ? AppColors.orange : AppColors.goldDark;
      label = order.isDelivered
          ? 'Paiement encaissé à la livraison'
          : 'Paiement en espèces à la livraison';
      icon = order.isDelivered ? Icons.check_circle : Icons.payments_outlined;
    } else if (paid) {
      color = AppColors.orange;
      label = 'Paiement confirmé';
      icon = Icons.check_circle;
    } else {
      color = AppColors.goldDark;
      label = 'En attente de paiement';
      icon = Icons.schedule;
    }

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: color,
            fontWeight: FontWeight.w600,
          ),
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
    // Commande en espèces : aucun règlement en ligne, tout se fait à la remise.
    final isCash = order.isCash;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                success
                    ? (isCash ? Icons.payments_outlined : Icons.check_circle)
                    : Icons.hourglass_top,
                size: 72,
                color: success ? Colors.green : theme.colorScheme.tertiary,
              ),
              const SizedBox(height: 20),
              Text(
                success
                    ? (isCash
                          ? 'Commande enregistrée !'
                          : 'Paiement confirmé !')
                    : 'Commande créée',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                success
                    ? (isCash
                          ? 'Votre commande ${order.reference} part en préparation. Vous réglerez ${formatAmount(order.total)} en espèces au livreur.'
                          : 'Votre commande ${order.reference} a été réglée et est en préparation.')
                    : 'Votre commande ${order.reference} est en attente de paiement.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              AmountText(
                order.total,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Suivre ma commande',
                icon: Icons.track_changes,
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => OrderTrackingScreen(
                      marketplace: marketplace,
                      orderId: order.id,
                    ),
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
            const Text(
              'Historique',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
                        isLast
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 18,
                        color: isLast
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
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
                            Text(
                              entry.reason!,
                              style: theme.textTheme.bodySmall,
                            ),
                          Text(
                            formatDateTime(entry.createdAt, fallback: ''),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
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
  const _SummaryRow({
    required this.label,
    this.amount,
    this.emphasized = false,
  });

  final String label;
  final int? amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
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

/// Avis déjà déposé sur la commande.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final OrderReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 22,
              color: AppColors.goldDark,
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Avis déposé',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Stars(rating: review.rating),
                      const SizedBox(width: 8),
                      Text(
                        'Vendeur',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (review.driverRating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Stars(rating: review.driverRating!),
                        const SizedBox(width: 8),
                        Text(
                          'Livreur',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (review.comment != null && review.comment!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(review.comment!, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialogue de notation vendeur + livreur (cahier v1.0, J29 §9).
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    required this.canRateDriver,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool canRateDriver;
  final VoidCallback onCancel;
  final void Function(int rating, int? driverRating, String comment) onSubmit;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _comment = TextEditingController();
  int _rating = 0;
  int? _driverRating;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    if (_rating < 1) {
      showToast(context, 'Indiquez une note (1 à 5 étoiles).', isError: true);
      return;
    }
    widget.onSubmit(
      _rating,
      widget.canRateDriver ? _driverRating : null,
      _comment.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Donner mon avis'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Votre note pour le vendeur *',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Center(
              child: _StarsInput(
                rating: _rating,
                onChanged: (v) => setState(() => _rating = v),
              ),
            ),
            if (widget.canRateDriver) ...[
              const SizedBox(height: AppDimens.md),
              const Text(
                'Note pour le livreur (optionnel)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Center(
                child: _StarsInput(
                  rating: _driverRating ?? 0,
                  onChanged: (v) => setState(() => _driverRating = v),
                ),
              ),
            ],
            const SizedBox(height: AppDimens.md),
            TextField(
              controller: _comment,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Commentaire (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text('Plus tard')),
        FilledButton(onPressed: _submit, child: const Text('Envoyer')),
      ],
    );
  }
}

/// Rangée d'étoiles (lecture).
class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star : Icons.star_border,
            size: 16,
            color: AppColors.goldDark,
          ),
      ],
    );
  }
}

/// Rangée d'étoiles interactives (saisie).
class _StarsInput extends StatelessWidget {
  const _StarsInput({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => onChanged(i),
            icon: Icon(
              i <= rating ? Icons.star : Icons.star_border,
              size: 30,
              color: AppColors.goldDark,
            ),
          ),
      ],
    );
  }
}

class _ConfirmationCodeCard extends StatelessWidget {
  const _ConfirmationCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.goldLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, color: AppColors.goldDark),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Code de confirmation',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.goldDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: AppColors.goldDark,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Communiquez ce code au livreur uniquement au moment de la réception. Sans ce code, la livraison ne peut pas être confirmée.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.goldDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
