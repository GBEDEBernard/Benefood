import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/route_planner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../shared/models/geo_point.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/route_plan.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/call_button.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/package_item_tile.dart';
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
  static const _pollInterval = Duration(seconds: 5);

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
          _submitReview(rating: rating, driverRating: driverRating, comment: comment);
        },
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
      'paid' => AppColors.green,
      'accepted' => AppColors.green,
      'preparing' => const Color(0xFF1976D2),
      'ready' => const Color(0xFF3949AB),
      'assigned' => const Color(0xFF7B1FA2),
      'out_for_delivery' => AppColors.green,
      'delivered' => AppColors.green,
      'cancelled' => AppColors.red,
      'refunded' => AppColors.textSecondary,
      _ => AppColors.green,
    };
  }

  /// Carte de suivi « ultra pro ».
  ///
  /// - Avant l'affectation d'un livreur : ma position (point bleu) → boutique,
  ///   pour que le client se situe par rapport au lieu de sa commande.
  /// - Pendant la course : position du livreur (moto) → adresse de livraison,
  ///   tracé routier réel et mise à jour toutes les 5 s.
  Widget _liveTrackingMap(Order order) {
    final driver = order.delivery?.position?.point;
    final dropoff = order.dropoffPoint;
    final shop = _shopPoint(order);
    final self = _selfPosition;

    if (driver != null && dropoff != null) {
      return AppMap(
        origin: driver,
        originLabel: order.delivery?.driver?.name ?? 'Livreur',
        target: dropoff,
        targetLabel: 'Vous',
        targetIcon: Icons.place,
        targetColor: AppColors.orange,
        secondary: shop,
        secondaryLabel: order.vendor?.businessName ?? 'Boutique',
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
        target: shop,
        targetLabel: order.vendor?.businessName ?? 'Boutique',
        targetIcon: Icons.storefront_outlined,
        targetColor: AppColors.gold,
        secondary: dropoff,
        secondaryLabel: 'Adresse de livraison',
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
      target: shop ?? dropoff,
      targetLabel: shop != null
          ? (order.vendor?.businessName ?? 'Boutique')
          : 'Adresse de livraison',
      targetIcon: shop != null ? Icons.storefront_outlined : Icons.place,
      targetColor: shop != null ? AppColors.gold : AppColors.orange,
      secondary: shop != null ? dropoff : null,
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
                  color: AppColors.greenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delivery_dining, color: AppColors.green, size: 26),
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
                        if (driver.vehicle != null && driver.vehicle!.isNotEmpty) ...[
                          const Icon(Icons.two_wheeler, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(driver.vehicle!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                          const SizedBox(width: 10),
                        ],
                        if (driver.rating != null) ...[
                          const Icon(Icons.star, size: 14, color: AppColors.gold),
                          const SizedBox(width: 3),
                          Text(
                            driver.rating!.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (tracking) const _LiveDot(color: AppColors.green),
            ],
          ),
          if (tracking) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.near_me_outlined, size: 15, color: AppColors.orange),
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
            onEmptyPhone: () => showToast(context, 'Numéro du livreur indisponible.', isError: true),
          ),
        ],
      ),
    );
  }

  /// Distance livreur -> adresse : `distance_km` de l'API, sinon calculée ici.
  String _distanceLabel(Order order) {
    final position = order.delivery?.position;
    if (position == null) {
      return '—';
    }
    final dropoff = order.dropoffPoint;
    final km = position.distanceKm ??
        (dropoff == null ? null : distanceKm(position.point.latLng, dropoff.latLng));
    final label = 'À ${formatDistance(km)} de vous';
    final minutes = estimateMinutes(km ?? 0);
    return minutes == null ? label : '$label · ~${formatEta(minutes)}';
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
                    decoration: BoxDecoration(                        color: i < current ? accent : AppColors.border,
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
    final paid = order.paymentStatus == 'confirmed' ||
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
      color = order.isDelivered ? AppColors.green : AppColors.goldDark;
      label = order.isDelivered
          ? 'Paiement encaissé à la livraison'
          : 'Paiement en espèces à la livraison';
      icon = order.isDelivered ? Icons.check_circle : Icons.payments_outlined;
    } else if (paid) {
      color = AppColors.green;
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
                    ? (isCash ? 'Commande enregistrée !' : 'Paiement confirmé !')
                    : 'Commande créée',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
            Icon(Icons.fact_check_outlined, size: 22, color: AppColors.goldDark),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Avis déposé',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Stars(rating: review.rating),
                      const SizedBox(width: 8),
                      Text('Vendeur', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                  if (review.driverRating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Stars(rating: review.driverRating!),
                        const SizedBox(width: 8),
                        Text('Livreur', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
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
  const _ReviewDialog({required this.canRateDriver, required this.onCancel, required this.onSubmit});

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
    widget.onSubmit(_rating, widget.canRateDriver ? _driverRating : null, _comment.text.trim());
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
            const Text('Votre note pour le vendeur *', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Center(
              child: _StarsInput(rating: _rating, onChanged: (v) => setState(() => _rating = v)),
            ),
            if (widget.canRateDriver) ...[
              const SizedBox(height: AppDimens.md),
              const Text('Note pour le livreur (optionnel)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Center(
                child: _StarsInput(rating: _driverRating ?? 0, onChanged: (v) => setState(() => _driverRating = v)),
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