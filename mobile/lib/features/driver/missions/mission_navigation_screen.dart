import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/services/background_location_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/navigation_guide.dart';
import '../../../core/services/route_planner.dart';
import '../../../core/services/voice_guidance.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../shared/models/driver_mission.dart';
import '../../../shared/models/geo_point.dart';
import '../../../shared/models/route_plan.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/call_button.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/package_item_tile.dart';

/// Navigation plein écran d'une mission active.
///
/// La carte occupe l'arrière-plan, le guidage reste visible en haut et les
/// actions terrain (collecte, départ livraison, code client) sont regroupées
/// dans un panneau bas repliable par le contenu.
class MissionNavigationScreen extends StatefulWidget {
  const MissionNavigationScreen({
    super.key,
    required this.marketplace,
    required this.mission,
  });

  final MarketplaceApi marketplace;
  final DriverMission mission;

  @override
  State<MissionNavigationScreen> createState() =>
      _MissionNavigationScreenState();
}

class _MissionNavigationScreenState extends State<MissionNavigationScreen> {
  static const _locationInterval = Duration(
    seconds: AppConfig.locationIntervalSeconds,
  );

  late DriverMission _mission;
  late final RoutePlanner _routePlanner;
  late final NavigationGuide _guide;
  late final VoiceGuidance _voice;

  StreamSubscription<GeoResult>? _positionSubscription;
  Timer? _reportTimer;
  bool _sendingLocation = false;
  bool _actionLoading = false;

  GeoPoint? _position;
  LocationFailure? _locationFailure;
  bool _locating = false;

  RoutePlan? _route;
  GeoPoint? _routeTarget;
  RoutePlan? _deliveryLeg;
  NavigationState? _navigationState;
  bool _routeInFlight = false;
  bool _routeFailed = false;
  DateTime? _lastOffRouteRecalc;

  bool _voiceEnabled = true;

  bool get _isActive => _mission.isActive;

  @override
  void initState() {
    super.initState();
    _mission = widget.mission;
    _routePlanner = RoutePlanner(widget.marketplace);
    _guide = NavigationGuide(
      offRouteThresholdMeters: AppConfig.rerouteDeviationMeters.toDouble(),
      arrivalThresholdMeters: AppConfig.arrivalRadiusMeters.toDouble(),
    );
    _voice = VoiceGuidance()..init();
    _syncReporting();
    _startTracking();
    _loadDeliveryLeg();
  }

  @override
  void dispose() {
    _reportTimer?.cancel();
    _positionSubscription?.cancel();
    unawaited(_voice.dispose());
    unawaited(BackgroundLocationService.stop());
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Localisation et transmission au serveur
  // ------------------------------------------------------------------

  Future<void> _startTracking() async {
    if (_locating) {
      return;
    }
    setState(() => _locating = true);
    try {
      final result = await LocationService.locate();
      if (!mounted) {
        return;
      }
      if (result.isSuccess) {
        final geo = result.geo!;
        setState(() {
          _position = GeoPoint(geo.latitude, geo.longitude);
          _locationFailure = null;
          _locating = false;
        });
        _subscribeToPosition();
        _refreshGuidance();
        _maybeUpdateRoute();
        return;
      }

      setState(() {
        _locationFailure = result.failure;
        _locating = false;
      });
      _showLocationFailure(result.failure);
      if (result.failure == LocationFailure.unavailable) {
        _subscribeToPosition();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationFailure = LocationFailure.unavailable;
        _locating = false;
      });
      _showLocationFailure(LocationFailure.unavailable);
      _subscribeToPosition();
    }
  }

  void _subscribeToPosition() {
    _positionSubscription?.cancel();
    try {
      _positionSubscription = LocationService.watch(
        distanceFilter: AppConfig.locationDistanceFilterMeters,
      ).listen(
        _onPosition,
        onError: (_) {
          if (!mounted) {
            return;
          }
          setState(() => _locationFailure = LocationFailure.unavailable);
          _showLocationFailure(LocationFailure.unavailable);
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _locationFailure = LocationFailure.unavailable);
      }
    }
  }

  void _onPosition(GeoResult geo) {
    if (!mounted) {
      return;
    }
    final position = GeoPoint(geo.latitude, geo.longitude);
    setState(() {
      _position = position;
      _locationFailure = null;
    });
    _refreshGuidance();
    _maybeUpdateRoute();
  }

  Future<void> _retryLocation() async {
    _positionSubscription?.cancel();
    setState(() {
      _locationFailure = null;
      _position = null;
    });
    await _startTracking();
  }

  void _showLocationFailure(LocationFailure? failure) {
    if (!mounted || failure == null) {
      return;
    }
    showToast(context, _locationFailureMessage(failure), isError: true);
  }

  static String _locationFailureMessage(
    LocationFailure failure,
  ) => switch (failure) {
    LocationFailure.serviceDisabled =>
      'GPS désactivé : activez la localisation pour être guidé.',
    LocationFailure.permissionDenied =>
      'Localisation refusée : vous pouvez continuer la mission, le suivi client sera limité.',
    _ => 'Position introuvable : nouvelle tentative en cours.',
  };

  void _syncReporting() {
    _reportTimer?.cancel();
    _reportTimer = null;
    if (!_isActive) {
      unawaited(BackgroundLocationService.stop());
      return;
    }
    _sendLocation();
    _reportTimer = Timer.periodic(_locationInterval, (_) => _sendLocation());
    unawaited(() async {
      try {
        await BackgroundLocationService.configure();
        await BackgroundLocationService.start();
      } catch (_) {
        // Suivi d'arrière-plan indisponible : le timer au premier plan suffit.
      }
    }());
  }

  Future<void> _sendLocation() async {
    if (_sendingLocation || !_isActive) {
      return;
    }
    _sendingLocation = true;
    try {
      final position = _position;
      if (position == null) {
        return;
      }
      await widget.marketplace.updateDriverLocation(
        position.latitude,
        position.longitude,
      );
    } catch (_) {
      // Réseau indisponible : le prochain tick réessaiera.
    } finally {
      _sendingLocation = false;
    }
  }

  // ------------------------------------------------------------------
  // Itinéraire et guidage
  // ------------------------------------------------------------------

  DriverMissionStop get _currentStop => _mission.currentStop;

  GeoPoint? get _target => _currentStop.point;

  String get _targetTitle {
    if (_mission.isPickupPhase) {
      return _mission.isParcel
          ? 'Rejoindre l\'expéditeur'
          : 'Rejoindre le point de collecte';
    }
    return 'Direction l\'adresse de livraison';
  }

  String? get _targetAddress {
    final address = _currentStop.displayAddress;
    return address.isEmpty ? null : address;
  }

  bool get _routeFallbackVisible =>
      _position != null &&
      _isActive &&
      (_routeFailed || (_route != null && !_route!.isRouted));

  Future<void> _loadDeliveryLeg() async {
    final pickup = _mission.pickup.point;
    final dropoff = _mission.dropoff.point;
    if (pickup == null || dropoff == null) {
      return;
    }
    final plan = await _routePlanner.plan([pickup, dropoff]);
    if (mounted && plan != null) {
      setState(() => _deliveryLeg = plan);
    }
  }

  void _maybeUpdateRoute() {
    final target = _target;
    if (target == null || _position == null || !_isActive) {
      return;
    }
    if (_route != null && _routeTarget == target) {
      return;
    }
    unawaited(_updateRoute());
  }

  Future<void> _updateRoute({bool force = false}) async {
    final target = _target;
    final position = _position;
    if (target == null || position == null || !_isActive) {
      return;
    }
    if (_routeInFlight) {
      return;
    }
    _routeInFlight = true;
    final targetChanged = _routeTarget != target;

    final plan = await _routePlanner.plan([position, target], force: force);
    if (!mounted) {
      return;
    }

    setState(() {
      _routeInFlight = false;
      if (plan != null) {
        _route = plan;
        _routeTarget = target;
        _routeFailed = false;
      } else {
        _routeFailed = targetChanged;
        if (targetChanged) {
          _route = null;
          _routeTarget = null;
          _navigationState = null;
        }
      }
    });

    if (plan != null) {
      if (_routeTarget != _target) {
        _maybeUpdateRoute();
      } else {
        _refreshGuidance();
      }
    }
  }

  void _refreshGuidance() {
    final position = _position;
    final route = _route;
    final target = _target;
    if (position == null ||
        route == null ||
        target == null ||
        _routeTarget != target) {
      if (_navigationState != null) {
        setState(() => _navigationState = null);
      }
      return;
    }

    final state = _guide.update(route, position);
    setState(() => _navigationState = state);

    if (state != null) {
      _voice.announce(state);
      if (state.offRoute) {
        _handleOffRoute();
      }
    }
  }

  void _handleOffRoute() {
    final now = DateTime.now();
    final last = _lastOffRouteRecalc;
    if (last != null &&
        now.difference(last).inSeconds < AppConfig.rerouteMinIntervalSeconds) {
      return;
    }
    _lastOffRouteRecalc = now;
    unawaited(_updateRoute(force: true));
  }

  double? get _distanceKm {
    final state = _navigationState;
    if (state != null) {
      return state.remainingMeters / 1000;
    }
    final target = _target;
    final position = _position;
    if (target == null || position == null) {
      return null;
    }
    return distanceKm(position.latLng, target.latLng);
  }

  int? get _etaMinutes =>
      _navigationState?.etaMinutes ??
      _route?.etaMinutes ??
      estimateMinutes(_distanceKm ?? 0);

  double? get _bearing {
    final target = _target;
    final position = _position;
    if (target == null || position == null) {
      return null;
    }
    return bearingDegrees(position.latLng, target.latLng);
  }

  List<LatLng>? get _activeRoute {
    final route = _route;
    if (route == null || _routeTarget != _target) {
      return null;
    }
    return route.latLng;
  }

  List<LatLng>? get _highlightSegment {
    final state = _navigationState;
    final route = _route;
    if (state == null ||
        route == null ||
        _routeTarget != _target ||
        state.stepIndex < 0 ||
        state.stepIndex >= route.steps.length) {
      return null;
    }
    final segment = route.steps[state.stepIndex].latLng;
    return segment.length >= 2 ? segment : null;
  }

  List<LatLng>? get _deliveryLegRoute => _deliveryLeg?.latLng;

  // ------------------------------------------------------------------
  // Actions terrain
  // ------------------------------------------------------------------

  void _applyStatus(String status) {
    setState(() {
      _mission = _mission.copyWithStatus(status);
      _route = null;
      _routeTarget = null;
      _navigationState = null;
      _routeFailed = false;
    });
    unawaited(_voice.stop());
    _syncReporting();
    _maybeUpdateRoute();
  }

  Future<void> _startPickup() async {
    if (_actionLoading) {
      return;
    }
    setState(() => _actionLoading = true);
    try {
      if (_mission.isParcel) {
        await widget.marketplace.startParcelPickup(_mission.id);
      } else {
        await widget.marketplace.startDeliveryPickup(_mission.id);
      }
      if (!mounted) {
        return;
      }
      setState(() => _actionLoading = false);
      _applyStatus('en_route_pickup');
      showToast(context, 'Cap sur le point de collecte.');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _confirmPickup() async {
    if (_actionLoading) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _PickupConfirmationDialog(mission: _mission),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _actionLoading = true);
    try {
      if (_mission.isParcel) {
        await widget.marketplace.pickupParcelDelivery(_mission.id);
      } else {
        await widget.marketplace.markPickedUp(_mission.id);
      }
      if (!mounted) {
        return;
      }
      setState(() => _actionLoading = false);
      _applyStatus('picked_up');
      showToast(
        context,
        _mission.isParcel
            ? 'Colis récupéré. Vous pouvez démarrer la livraison.'
            : 'Commande récupérée. Vous pouvez démarrer la livraison.',
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _startDelivery() async {
    if (_actionLoading) {
      return;
    }
    setState(() => _actionLoading = true);
    try {
      if (_mission.isParcel) {
        await widget.marketplace.startParcelDelivery(_mission.id);
      } else {
        await widget.marketplace.markInDelivery(_mission.id);
      }
      if (!mounted) {
        return;
      }
      setState(() => _actionLoading = false);
      _applyStatus('in_delivery');
      showToast(context, 'Livraison démarrée.');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _requestProofCode() async {
    if (_actionLoading || _mission.status != 'in_delivery') {
      return;
    }
    final delivered = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProofCodeDialog(onSubmit: _submitProofCode),
    );
    if (delivered == true && mounted) {
      showToast(context, 'Livraison confirmée.');
    }
  }

  Future<String?> _submitProofCode(String code) async {
    try {
      if (_mission.isParcel) {
        await widget.marketplace.deliverParcelDelivery(
          _mission.id,
          proofCode: code,
        );
      } else {
        await widget.marketplace.markDelivered(_mission.id, proofCode: code);
      }
      if (!mounted) {
        return null;
      }
      setState(() {
        _mission = _mission.copyWithStatus('delivered');
        _navigationState = null;
      });
      _syncReporting();
      await _voice.stop();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Impossible de confirmer la livraison. Réessayez.';
    }
  }

  void _finish() {
    Navigator.of(context).pop(_mission);
  }

  Future<void> _openExternalMaps() async {
    final position = _position;
    final target = _target;
    if (position == null || target == null) {
      showToast(
        context,
        'Position ou destination indisponible.',
        isError: true,
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${position.latitude},${position.longitude}'
      '&destination=${target.latitude},${target.longitude}'
      '&travelmode=two-wheeler',
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        showToast(
          context,
          'Aucune application de navigation trouvée.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showToast(
          context,
          'Impossible d\'ouvrir l\'application de navigation.',
          isError: true,
        );
      }
    }
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      body: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              origin: _position,
              originLabel: 'Vous',
              originHeading: _bearing,
              target: _target,
              targetLabel: _currentStop.title,
              targetImageUrl: _currentStop.imageUrl,
              targetIcon: _mission.isPickupPhase
                  ? Icons.storefront_outlined
                  : Icons.location_on_outlined,
              targetColor: _mission.isPickupPhase
                  ? AppColors.gold
                  : AppColors.orange,
              secondary: _mission.isPickupPhase ? _mission.dropoff.point : null,
              secondaryLabel: _mission.dropoff.title,
              secondaryImageUrl: _mission.isPickupPhase
                  ? _mission.dropoff.imageUrl
                  : null,
              secondaryIcon: Icons.place_outlined,
              secondaryColor: AppColors.orange,
              route: _activeRoute,
              routeColor: _mission.isPickupPhase
                  ? AppColors.gold
                  : AppColors.orange,
              highlightRoute: _highlightSegment,
              extraRoute: _deliveryLegRoute,
              followOrigin: true,
              height: double.infinity,
              expandable: false,
              openInMaps: false,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _MapCircleButton(
                          icon: Icons.arrow_back,
                          tooltip: 'Retour à la mission',
                          onPressed: () => Navigator.of(context).pop(_mission),
                        ),
                        const Spacer(),
                        _MapCircleButton(
                          icon: _voiceEnabled
                              ? Icons.volume_up
                              : Icons.volume_off,
                          tooltip: _voiceEnabled
                              ? 'Couper le guidage vocal'
                              : 'Activer le guidage vocal',
                          onPressed: () => setState(() {
                            _voiceEnabled = !_voiceEnabled;
                            _voice.enabled = _voiceEnabled;
                            if (!_voiceEnabled) {
                              unawaited(_voice.stop());
                            }
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.sm),
                    _GuidanceCard(
                      title: _targetTitle,
                      address: _targetAddress,
                      distanceKm: _distanceKm,
                      bearing: _bearing,
                      etaMinutes: _etaMinutes,
                      waitingForPosition: _position == null,
                      locating: _locating,
                      accent: _mission.isPickupPhase
                          ? AppColors.gold
                          : AppColors.orange,
                      navigationState: _navigationState,
                    ),
                    if (_locationFailure != null) ...[
                      const SizedBox(height: AppDimens.sm),
                      _LocationFailureBanner(
                        message: _locationFailureMessage(_locationFailure!),
                        onRetry: _retryLocation,
                      ),
                    ],
                    if (_routeFallbackVisible) ...[
                      const SizedBox(height: AppDimens.sm),
                      const _RouteFallbackBanner(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomMissionPanel(
              mission: _mission,
              locating: _locating,
              actionLoading: _actionLoading,
              arrived: _navigationState?.arrived ?? false,
              distanceKm: _distanceKm,
              onPrimary: _primaryAction,
              onOpenMaps: _openExternalMaps,
              onFinish: _finish,
            ),
          ),
        ],
      ),
    );
  }

  VoidCallback? get _primaryAction => switch (_mission.status) {
    'assigned' => _startPickup,
    'en_route_pickup' => _confirmPickup,
    'picked_up' => _startDelivery,
    'in_delivery' => _requestProofCode,
    'delivered' => _finish,
    _ => null,
  };
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.title,
    required this.address,
    required this.distanceKm,
    required this.bearing,
    required this.etaMinutes,
    required this.waitingForPosition,
    required this.locating,
    required this.accent,
    required this.navigationState,
  });

  final String title;
  final String? address;
  final double? distanceKm;
  final double? bearing;
  final int? etaMinutes;
  final bool waitingForPosition;
  final bool locating;
  final Color accent;
  final NavigationState? navigationState;

  @override
  Widget build(BuildContext context) {
    final state = navigationState;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              state?.icon ?? Icons.navigation,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state != null)
                  Text(
                    formatDistance(state.distanceToManeuverMeters / 1000),
                    style: TextStyle(
                      fontSize: 19,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: -0.4,
                    ),
                  )
                else if (distanceKm != null)
                  Text(
                    formatDistance(distanceKm),
                    style: TextStyle(
                      fontSize: 19,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: -0.4,
                    ),
                  ),
                Text(
                  state != null
                      ? (state.offRoute
                            ? 'Recalcul de l\'itinéraire…'
                            : state.instruction)
                      : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                if (state == null && address != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    waitingForPosition
                        ? (locating
                              ? 'Recherche de votre position…'
                              : 'Position indisponible')
                        : address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (state != null && address != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (etaMinutes != null && state?.offRoute != true)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
              child: Text(
                formatEta(etaMinutes),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomMissionPanel extends StatelessWidget {
  const _BottomMissionPanel({
    required this.mission,
    required this.locating,
    required this.actionLoading,
    required this.arrived,
    required this.distanceKm,
    required this.onPrimary,
    required this.onOpenMaps,
    required this.onFinish,
  });

  final DriverMission mission;
  final bool locating;
  final bool actionLoading;
  final bool arrived;
  final double? distanceKm;
  final VoidCallback? onPrimary;
  final VoidCallback onOpenMaps;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final stop = mission.currentStop;
    final phone = stop.contactPhone?.trim() ?? '';
    final delivered = mission.status == 'delivered';
    final cancelled = mission.status == 'cancelled';
    final accent = mission.isPickupPhase ? AppColors.gold : AppColors.orange;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            10,
            AppDimens.pagePadding,
            AppDimens.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (delivered) ...[
                _DeliveredPanel(mission: mission, onFinish: onFinish),
              ] else if (cancelled) ...[
                const Text(
                  'Mission annulée',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cette mission ne peut plus être poursuivie.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onFinish,
                  child: const Text('Retour'),
                ),
              ] else ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusPill,
                        ),
                      ),
                      child: Text(
                        mission.isPickupPhase ? 'COLLECTE' : 'LIVRAISON',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mission.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ),
                    if (arrived)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.greenLight,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusPill,
                          ),
                        ),
                        child: const Text(
                          'Arrivé',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        mission.isPickupPhase
                            ? (mission.isParcel
                                  ? Icons.inventory_2_outlined
                                  : Icons.storefront_outlined)
                            : Icons.person_pin_circle_outlined,
                        size: 21,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stop.displayAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (stop.contactName != null &&
                              stop.contactName!.trim().isNotEmpty &&
                              stop.contactName!.trim() !=
                                  stop.title.trim()) ...[
                            const SizedBox(height: 1),
                            Text(
                              stop.contactName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textFaint,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      CallButton(label: 'Appeler', phone: phone, compact: true),
                    ],
                  ],
                ),
                if (mission.isPickupPhase &&
                    mission.items.isNotEmpty &&
                    mission.status == 'en_route_pickup') ...[
                  const SizedBox(height: 9),
                  _PickupItemsSummary(mission: mission),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: actionLoading ? null : onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                  ),
                  icon: actionLoading
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_primaryIcon, size: 21),
                  label: Text(
                    _primaryLabel,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        locating
                            ? 'Localisation en cours…'
                            : distanceKm != null
                            ? '${formatDistance(distanceKm)} restants'
                            : 'Distance indisponible',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onOpenMaps,
                      icon: const Icon(Icons.directions_outlined, size: 16),
                      label: const Text('Ouvrir dans Maps'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _primaryLabel => switch (mission.status) {
    'assigned' => 'Démarrer la récupération',
    'en_route_pickup' => 'Je suis arrivé au point de collecte',
    'picked_up' => 'Démarrer la livraison',
    'in_delivery' => 'Saisir le code de livraison',
    _ => 'Continuer',
  };

  IconData get _primaryIcon => switch (mission.status) {
    'assigned' => Icons.play_arrow_rounded,
    'en_route_pickup' => Icons.inventory_2_outlined,
    'picked_up' => Icons.two_wheeler,
    'in_delivery' => Icons.password_outlined,
    _ => Icons.arrow_forward,
  };
}

class _DeliveredPanel extends StatelessWidget {
  const _DeliveredPanel({required this.mission, required this.onFinish});

  final DriverMission mission;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: AppColors.greenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.green,
                size: 27,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mission terminée',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'La livraison a bien été confirmée.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AmountText(
              mission.earnings,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: onFinish,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
          ),
          child: const Text(
            'Terminer la mission',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _PickupItemsSummary extends StatelessWidget {
  const _PickupItemsSummary({required this.mission});

  final DriverMission mission;

  @override
  Widget build(BuildContext context) {
    final preview = mission.items.take(2).toList(growable: false);
    final remaining = mission.items.length - preview.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 15,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              [
                for (final item in preview) '${item.quantity}× ${item.name}',
                if (remaining > 0) '+$remaining',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.97),
        elevation: 2,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 21, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}

class _LocationFailureBanner extends StatelessWidget {
  const _LocationFailureBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_off, size: 17, color: AppColors.goldDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 11.5, color: AppColors.text),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.goldDark,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Réessayer',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteFallbackBanner extends StatelessWidget {
  const _RouteFallbackBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.route_outlined, size: 15, color: AppColors.textSecondary),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Itinéraire routier indisponible — estimation à vol d\'oiseau.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupConfirmationDialog extends StatelessWidget {
  const _PickupConfirmationDialog({required this.mission});

  final DriverMission mission;

  @override
  Widget build(BuildContext context) {
    final phone = mission.pickup.contactPhone?.trim() ?? '';

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      title: Text(
        mission.isParcel
            ? 'Confirmer la collecte du colis ?'
            : 'Confirmer la collecte ?',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 340),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mission.isParcel
                    ? 'Vérifiez que le colis correspond à la description avant de confirmer.'
                    : 'Vérifiez que tous les articles de la commande sont présents avant de confirmer.',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              if (mission.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: Column(
                    children: [
                      for (final item in mission.items)
                        PackageItemTile(
                          name: item.name,
                          quantity: item.quantity,
                          imageUrl: item.imageUrl,
                          dense: true,
                        ),
                    ],
                  ),
                ),
              ] else if (mission.isParcel &&
                  (mission.description?.trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: Text(
                    mission.description!.trim(),
                    style: const TextStyle(fontSize: 12, color: AppColors.text),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      mission.pickup.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  if (phone.isNotEmpty)
                    CallButton(label: 'Appeler', phone: phone, compact: true),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Pas encore'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}

class _ProofCodeDialog extends StatefulWidget {
  const _ProofCodeDialog({required this.onSubmit});

  final Future<String?> Function(String code) onSubmit;

  @override
  State<_ProofCodeDialog> createState() => _ProofCodeDialogState();
}

class _ProofCodeDialogState extends State<_ProofCodeDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) {
      return;
    }
    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Saisissez les 6 chiffres du code client.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await widget.onSubmit(code);
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      title: const Text(
        'Code de livraison',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demandez au client son code à 6 chiffres pour confirmer la livraison.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            enabled: !_loading,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 9,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              counterText: '',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmer'),
        ),
      ],
    );
  }
}
