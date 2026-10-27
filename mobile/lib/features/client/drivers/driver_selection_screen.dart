import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../shared/models/driver_selection.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Ouvre l'écran « Choisir mon livreur » (commande ou colis).
///
/// Retourne `true` si un livreur a accepté pendant que l'écran était ouvert.
Future<bool?> showDriverSelectionPage(
  BuildContext context,
  MarketplaceApi marketplace, {
  required String targetId,
  required String reference,
  required bool isParcel,
  VoidCallback? onChanged,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => DriverSelectionScreen(
        marketplace: marketplace,
        targetId: targetId,
        reference: reference,
        isParcel: isParcel,
        onChanged: onChanged,
      ),
    ),
  );
}

class DriverSelectionScreen extends StatefulWidget {
  const DriverSelectionScreen({
    super.key,
    required this.marketplace,
    required this.targetId,
    required this.reference,
    required this.isParcel,
    this.onChanged,
  });

  final MarketplaceApi marketplace;
  final String targetId;
  final String reference;
  final bool isParcel;
  final VoidCallback? onChanged;

  @override
  State<DriverSelectionScreen> createState() => _DriverSelectionScreenState();
}

class _DriverSelectionScreenState extends State<DriverSelectionScreen>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 5);

  DriverSelectionPage? _page;
  bool _loading = true;
  bool _connectionLost = false;
  ApiException? _error;
  String? _actionDriverId;
  bool _autoAssigning = false;
  bool _cancelling = false;
  bool _assignedNotified = false;
  bool _polling = false;
  String? _selectedDriverId;
  Timer? _pollTimer;
  double? _radiusOverride;
  bool _routeLoading = false;
  bool _showRoute = false;
  List<LatLng>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSilently();
    }
  }

  Future<DriverSelectionPage> _fetch() {
    final radius = _radiusOverride;
    return widget.isParcel
        ? widget.marketplace.parcelNearbyDrivers(
            widget.targetId,
            radiusKm: radius,
          )
        : widget.marketplace.orderNearbyDrivers(
            widget.targetId,
            radiusKm: radius,
          );
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final page = await _fetch();
      if (!mounted) {
        return;
      }
      setState(() {
        _page = page;
        _loading = false;
        _error = null;
        _connectionLost = false;
        final selected = _selectedDriverId;
        if (selected != null && !page.drivers.any((d) => d.id == selected)) {
          _selectedDriverId = null;
        }
      });
      _startPolling();
      _closeIfAssigned(page);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (kDebugMode) {
        debugPrint(
          '[driver_selection] recherche échouée : ${e.status} ${e.code}',
        );
      }
      if (_page == null) {
        setState(() {
          _error = e;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _connectionLost = true;
        });
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refreshSilently());
  }

  Future<void> _refreshSilently() async {
    if (_polling || !mounted) {
      return;
    }
    _polling = true;
    try {
      final page = await _fetch();
      if (!mounted) {
        return;
      }
      setState(() {
        _page = page;
        _connectionLost = false;
        final selected = _selectedDriverId;
        if (selected != null && !page.drivers.any((d) => d.id == selected)) {
          _selectedDriverId = null;
        }
      });
      _closeIfAssigned(page);
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[driver_selection] rafraîchissement interrompu : ${e.status} ${e.code}',
        );
      }
      if (mounted) {
        setState(() => _connectionLost = true);
      }
    } finally {
      _polling = false;
    }
  }

  void _closeIfAssigned(DriverSelectionPage page) {
    if (_assignedNotified || page.request?.isAccepted != true) {
      return;
    }
    _assignedNotified = true;
    widget.onChanged?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showToast(context, 'Votre livreur a accepté la course.');
        Navigator.of(context).pop(true);
      }
    });
  }

  Future<void> _request(NearbyDriver driver) async {
    setState(() => _actionDriverId = driver.id);
    try {
      if (widget.isParcel) {
        await widget.marketplace.requestParcelDriver(
          widget.targetId,
          driver.id,
        );
      } else {
        await widget.marketplace.requestOrderDriver(
          widget.targetId,
          driver.id,
        );
      }
      if (!mounted) {
        return;
      }
      widget.onChanged?.call();
      showToast(context, 'Demande envoyée à ${driver.displayName}.');
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
        if (e.isConflict) {
          await _load(silent: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _actionDriverId = null);
      }
    }
  }

  Future<void> _autoAssign() async {
    setState(() => _autoAssigning = true);
    try {
      if (widget.isParcel) {
        await widget.marketplace.autoAssignParcelDriver(widget.targetId);
      } else {
        await widget.marketplace.autoAssignOrderDriver(widget.targetId);
      }
      if (!mounted) {
        return;
      }
      widget.onChanged?.call();
      showToast(context, 'Nous sollicitons le livreur disponible le plus proche.');
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _autoAssigning = false);
      }
    }
  }

  Future<void> _cancelRequest() async {
    setState(() => _cancelling = true);
    try {
      if (widget.isParcel) {
        await widget.marketplace.cancelParcelDriverRequest(widget.targetId);
      } else {
        await widget.marketplace.cancelOrderDriverRequest(widget.targetId);
      }
      if (!mounted) {
        return;
      }
      widget.onChanged?.call();
      showToast(context, 'Demande annulée.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  Future<void> _widenRadius() async {
    final page = _page;
    if (page == null) {
      return;
    }
    final next = math.min(page.maxRadiusKm, math.max(page.radiusKm * 2, 1.0));
    if (next <= page.radiusKm) {
      return;
    }
    setState(() => _radiusOverride = next);
    await _load();
  }

  Future<void> _toggleRoute() async {
    if (_showRoute) {
      setState(() => _showRoute = false);
      return;
    }
    if (_route != null) {
      setState(() => _showRoute = true);
      return;
    }

    final pickup = _page?.pickup?.point;
    final dropoff = _page?.dropoff?.point;
    if (pickup == null || dropoff == null) {
      return;
    }

    setState(() => _routeLoading = true);
    try {
      final plan = await widget.marketplace.routePlan([pickup, dropoff]);
      if (!mounted) {
        return;
      }
      setState(() {
        _route = plan.latLng;
        _showRoute = true;
      });
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _routeLoading = false);
      }
    }
  }

  void _openHelp() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choisir mon livreur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              const _HelpRow(
                icon: Icons.radar,
                text:
                    'Seuls les livreurs en ligne, disponibles et avec une position GPS récente sont affichés.',
              ),
              const _HelpRow(
                icon: Icons.send_outlined,
                text:
                    'Vous envoyez une demande : le livreur peut accepter ou refuser. Sa réponse arrive en quelques secondes.',
              ),
              const _HelpRow(
                icon: Icons.lock_outline,
                text:
                    'Le numéro du livreur et le suivi en direct sont activés après son acceptation.',
              ),
              const _HelpRow(
                icon: Icons.auto_awesome_outlined,
                text:
                    'Sans préférence ? La plateforme sollicite automatiquement le livreur le plus proche.',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                  ),
                  child: const Text('Compris'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetails() {
    final page = _page;
    if (page == null) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Détails de la course',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.storefront_outlined,
                color: AppColors.orange,
                title: 'Point de collecte',
                name: page.pickup?.title ?? '—',
                address: page.pickup?.display ?? '—',
              ),
              const SizedBox(height: 14),
              _DetailRow(
                icon: Icons.home_outlined,
                color: AppColors.green,
                title: 'Adresse de livraison',
                name: page.dropoff?.title ?? '—',
                address: page.dropoff?.display ?? '—',
              ),
              if (page.tripDistanceKm != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.route_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Trajet ${formatDistance(page.tripDistanceKm)}'
                      '${page.tripDurationSeconds != null ? ' · ${formatEta((page.tripDurationSeconds! / 60).ceil())}' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              reference: widget.reference,
              isParcel: widget.isParcel,
              onBack: () => Navigator.of(context).maybePop(),
              onHelp: _openHelp,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _page == null) {
      return const _LoadingView();
    }
    final error = _error;
    if (error != null && _page == null) {
      return _ErrorView(error: error, onRetry: _load);
    }

    final page = _page;
    if (page == null) {
      return const _LoadingView();
    }

    final request = page.request;
    final pending = request?.isPending == true;
    final hasDrivers = page.drivers.isNotEmpty;

    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          if (_connectionLost) ...[
            _ConnectionBanner(onRetry: () => _load()),
            const SizedBox(height: AppDimens.sm),
          ],
          if (page.pickup != null || page.dropoff != null) ...[
            _SummaryCard(
              pickup: page.pickup,
              dropoff: page.dropoff,
              tripDistanceKm: page.tripDistanceKm,
              onDetails: _openDetails,
            ),
            const SizedBox(height: AppDimens.md),
          ],
          _buildMap(page),
          const SizedBox(height: AppDimens.md),
          if (pending)
            _PendingRequestCard(
              request: request!,
              cancelling: _cancelling,
              onCancel: _cancelRequest,
            )
          else ...[
            if (request != null &&
                (request.isRefused ||
                    request.isExpired ||
                    request.isCancelled)) ...[
              _RequestNoticeCard(request: request),
              const SizedBox(height: AppDimens.sm),
            ],
            if (!hasDrivers)
              _EmptyDriversView(
                page: page,
                onRetry: () => _load(),
                onWiden: _widenRadius,
                onAutoAssign: _autoAssigning ? null : _autoAssign,
                autoAssigning: _autoAssigning,
              )
            else ...[
              _InfoBar(count: page.drivers.length),
              const SizedBox(height: AppDimens.sm),
              for (var i = 0; i < page.drivers.length; i++) ...[
                _DriverCard(
                  driver: page.drivers[i],
                  nearest: i == 0,
                  selected: _selectedDriverId == page.drivers[i].id,
                  busy: _actionDriverId,
                  onSelect: () => setState(
                    () => _selectedDriverId = _selectedDriverId == page.drivers[i].id
                        ? null
                        : page.drivers[i].id,
                  ),
                  onRequest: () => _request(page.drivers[i]),
                ),
                const SizedBox(height: AppDimens.sm),
              ],
              _AutoAssignPanel(
                loading: _autoAssigning,
                onPressed: _autoAssigning ? null : _autoAssign,
              ),
            ],
          ],
          const SizedBox(height: AppDimens.lg),
          const _PrivacyFooter(),
        ],
      ),
    );
  }

  Widget _buildMap(DriverSelectionPage page) {
    final pickup = page.pickup?.point;
    final dropoff = page.dropoff?.point;

    if (pickup == null && dropoff == null) {
      return const SizedBox.shrink();
    }

    final selectedId = _selectedDriverId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.radar, size: 16, color: AppColors.orangeDark),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Rayon de recherche · ${formatDistance(page.radiusKm)}'
                '${page.expanded ? ' (élargi)' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _routeLoading ? null : _toggleRoute,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: _routeLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _showRoute ? Icons.alt_route : Icons.directions_outlined,
                      size: 17,
                    ),
              label: Text(
                _showRoute ? 'Masquer l’itinéraire' : 'Voir l’itinéraire',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        AppMap(
          initialCenter: pickup ?? dropoff,
          secondary: pickup,
          secondaryLabel: 'Commerce',
          secondaryIcon: Icons.storefront_outlined,
          secondaryColor: AppColors.orange,
          target: dropoff,
          targetLabel: 'Vous',
          targetIcon: Icons.home_outlined,
          targetColor: AppColors.green,
          height: 254,
          initialZoom: _zoomForRadius(page.radiusKm),
          followOrigin: false,
          showRoute: false,
          route: _showRoute ? _route : null,
          routeColor: AppColors.blue,
          expandable: true,
          radiusCenter: pickup,
          radiusMeters: page.radiusKm * 1000,
          radiusColor: AppColors.orange,
          recenterPoint: pickup,
          recenterTooltip: 'Recentrer sur le commerce',
          extraMarkers: [
            for (final driver in page.drivers)
              if (driver.position != null)
                AppMapMarker(
                  point: driver.position!.point,
                  label: _driverMarkerLabel(driver),
                  imageUrl: driver.avatarUrl,
                  heading: driver.position!.heading,
                  color: AppColors.green,
                  icon: Icons.two_wheeler,
                  size: 36,
                  highlighted: driver.id == selectedId,
                ),
          ],
        ),
      ],
    );
  }

  String _driverMarkerLabel(NearbyDriver driver) {
    final eta = driver.etaToPickupSeconds;
    final distance = formatDistance(driver.distanceToPickupKm);
    if (eta == null) {
      return distance;
    }
    return '${formatEta((eta / 60).ceil())} · $distance';
  }

  double _zoomForRadius(double radiusKm) {
    if (radiusKm <= 3) {
      return 13.6;
    }
    if (radiusKm <= 6) {
      return 12.8;
    }
    if (radiusKm <= 10) {
      return 12.1;
    }
    return 11.5;
  }
}

// ---------------------------------------------------------------------------
// En-tête
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.reference,
    required this.isParcel,
    required this.onBack,
    required this.onHelp,
  });

  final String reference;
  final bool isParcel;
  final VoidCallback onBack;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.text),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choisir mon livreur',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${isParcel ? 'Colis' : 'Commande'} #$reference',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onHelp,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.green,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.help_outline, size: 19),
            label: const Text(
              'Aide',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Récapitulatif de la course
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.pickup,
    required this.dropoff,
    required this.tripDistanceKm,
    required this.onDetails,
  });

  final DriverSelectionPlace? pickup;
  final DriverSelectionPlace? dropoff;
  final double? tripDistanceKm;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _PlaceBlock(
              icon: Icons.storefront_outlined,
              color: AppColors.orange,
              tint: AppColors.orangeLight,
              overline: 'Point de collecte',
              title: pickup?.title ?? '—',
              subtitle: pickup?.subtitle ?? ' ',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                const Icon(
                  Icons.arrow_forward,
                  size: 15,
                  color: AppColors.textFaint,
                ),
                if (tripDistanceKm != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatDistance(tripDistanceKm),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(width: 1, height: 56, color: AppColors.border),
          const SizedBox(width: 8),
          Expanded(
            child: _PlaceBlock(
              icon: Icons.home_outlined,
              color: AppColors.green,
              tint: AppColors.greenLight,
              overline: 'Livraison à',
              title: dropoff?.title ?? '—',
              subtitle: dropoff?.subtitle ?? ' ',
            ),
          ),
          IconButton(
            tooltip: 'Détails',
            onPressed: onDetails,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceBlock extends StatelessWidget {
  const _PlaceBlock({
    required this.icon,
    required this.color,
    required this.tint,
    required this.overline,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final String overline;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                overline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Liste et carte des livreurs
// ---------------------------------------------------------------------------

class _InfoBar extends StatelessWidget {
  const _InfoBar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count livreur${count > 1 ? 's' : ''} disponible${count > 1 ? 's' : ''} autour de vous',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          const Text(
            'Trié par proximité',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const Icon(
            Icons.expand_more,
            size: 15,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.nearest,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onRequest,
  });

  final NearbyDriver driver;
  final bool nearest;
  final bool selected;
  final String? busy;
  final VoidCallback onSelect;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final loading = busy == driver.id;
    final disabled = busy != null;
    final age = driver.positionAgeSeconds;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: selected ? AppColors.orange : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: AppNetworkImage(
                            url: driver.avatarUrl,
                            fit: BoxFit.cover,
                            fallback: Container(
                              color: AppColors.orangeLight,
                              child: const Icon(
                                Icons.delivery_dining,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                driver.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            if (nearest) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.orangeLight,
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusPill,
                                  ),
                                ),
                                child: const Text(
                                  'Le plus proche',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.orangeDark,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 5,
                          children: [
                            if (driver.rating != null && driver.rating! > 0) ...[
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: AppColors.orange,
                              ),
                              Text(
                                driver.rating!.toStringAsFixed(1).replaceAll(
                                  '.',
                                  ',',
                                ),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orangeDark,
                                ),
                              ),
                              const Text(
                                '·',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textFaint,
                                ),
                              ),
                            ],
                            Text(
                              '${driver.completedDeliveries} livraison${driver.completedDeliveries > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'En ligne',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.green,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '· ${_freshness(age)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: _freshnessColor(age),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DistanceBlock(
                      icon: Icons.two_wheeler,
                      color: AppColors.orange,
                      tint: AppColors.orangeLight,
                      distanceLabel: formatDistance(driver.distanceToPickupKm),
                      etaLabel: driver.etaToPickupSeconds == null
                          ? '—'
                          : formatEta((driver.etaToPickupSeconds! / 60).ceil()),
                      caption: 'du point de collecte',
                    ),
                  ),
                  Container(width: 1, height: 46, color: AppColors.border),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DistanceBlock(
                      icon: Icons.home_outlined,
                      color: AppColors.green,
                      tint: AppColors.greenLight,
                      distanceLabel: formatDistance(
                        driver.pickupToDropoffKm ??
                            driver.distanceToDropoffKm,
                      ),
                      etaLabel: driver.etaToDropoffSeconds == null
                          ? '—'
                          : formatEta(
                              (driver.etaToDropoffSeconds! / 60).ceil(),
                            ),
                      caption: 'de votre adresse',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: disabled ? null : onRequest,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.orange.withValues(
                      alpha: 0.45,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                  ),
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: 17),
                  label: Text(
                    loading ? 'Envoi…' : 'Demander ce livreur',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistanceBlock extends StatelessWidget {
  const _DistanceBlock({
    required this.icon,
    required this.color,
    required this.tint,
    required this.distanceLabel,
    required this.etaLabel,
    required this.caption,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final String distanceLabel;
  final String etaLabel;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    distanceLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      etaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AutoAssignPanel extends StatelessWidget {
  const _AutoAssignPanel({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  size: 19,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Aucun livreur ne vous convient ?',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Confiez-nous votre livraison : nous sollicitons automatiquement le livreur disponible le plus proche.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orangeDark,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: AppColors.orange.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Assigner automatiquement',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demande en attente / refus / expiration
// ---------------------------------------------------------------------------

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
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
          const SizedBox(height: 12),
          Text(
            request.waitsForReady
                ? 'Le livreur sera notifié dès que la commande sera prête.'
                : _countdownLabel(request),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.goldDark,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: cancelling ? null : onCancel,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.goldDark,
              ),
              child: Text(cancelling ? 'Annulation…' : 'Annuler la demande'),
            ),
          ),
        ],
      ),
    );
  }

  String _countdownLabel(DriverRequestInfo request) {
    final seconds = request.secondsRemaining;
    if (seconds == null) {
      return 'Le livreur peut accepter la course dès maintenant.';
    }
    if (seconds <= 0) {
      return 'La demande a expiré. Choisissez un autre livreur.';
    }
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    final label = minutes > 0 ? '$minutes min $rest s' : '$rest s';
    return 'Réponse attendue sous $label.';
  }
}

class _RequestNoticeCard extends StatelessWidget {
  const _RequestNoticeCard({required this.request});

  final DriverRequestInfo request;

  @override
  Widget build(BuildContext context) {
    final refused = request.isRefused;
    final cancelled = request.isCancelled;
    final title = refused
        ? 'Le livreur a décliné la demande'
        : cancelled
        ? 'La demande a été annulée'
        : 'La demande a expiré';
    final reason = request.refusalReason;
    final subtitle = reason != null && reason.trim().isNotEmpty
        ? reason.trim()
        : 'Choisissez un autre livreur proche pour votre livraison.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.goldDark),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.goldDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// États vides, chargement, erreur
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.orangeLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.radar,
                size: 40,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Recherche des livreurs à proximité…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Nous vérifions les livreurs en ligne autour du point de collecte.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final ApiException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final network =
        error.status == 0 ||
        error.code == 'network.error' ||
        error.code == 'network.timeout';
    final code = error.code ?? '';

    final title = network
        ? 'Connexion interrompue'
        : code.contains('pickup_unavailable')
        ? 'Position du commerce indisponible'
        : code.contains('dropoff_unavailable')
        ? 'Adresse de livraison incomplète'
        : code.contains('already_assigned')
        ? 'Un livreur est déjà affecté'
        : 'Recherche impossible';

    final message = network
        ? 'Vérifiez votre connexion puis réessayez. La recherche reprendra automatiquement.'
        : code.contains('pickup_unavailable')
        ? 'Le commerce n’a pas de coordonnées GPS exploitables. Contactez le support pour finaliser la course.'
        : code.contains('dropoff_unavailable')
        ? 'Votre adresse de livraison n’a pas de coordonnées GPS. Modifiez l’adresse de la commande pour continuer.'
        : error.message;

    final icon = network
        ? Icons.wifi_off
        : code.contains('_unavailable')
        ? Icons.location_off_outlined
        : Icons.error_outline;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: AppColors.orangeLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.orangeDark),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDriversView extends StatelessWidget {
  const _EmptyDriversView({
    required this.page,
    required this.onRetry,
    required this.onWiden,
    required this.onAutoAssign,
    required this.autoAssigning,
  });

  final DriverSelectionPage page;
  final VoidCallback onRetry;
  final VoidCallback onWiden;
  final VoidCallback? onAutoAssign;
  final bool autoAssigning;

  @override
  Widget build(BuildContext context) {
    final diagnostics = page.diagnostics;
    final positionIssue = diagnostics.hasPositionIssue;
    final canWiden = page.radiusKm + 0.01 < page.maxRadiusKm;

    final title = positionIssue
        ? 'Positions GPS en cours de mise à jour'
        : 'Aucun livreur disponible dans ${formatDistance(page.radiusKm)}';

    final subtitle = positionIssue
        ? _positionIssueText(diagnostics)
        : 'Tous les livreurs proches sont peut-être déjà en mission. '
              'La recherche se met à jour automatiquement toutes les 5 secondes.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.orangeLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              positionIssue
                  ? Icons.gps_off
                  : Icons.delivery_dining_outlined,
              size: 32,
              color: positionIssue ? AppColors.goldDark : AppColors.orange,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          if (positionIssue) ...[
            const SizedBox(height: 8),
            Text(
              '${diagnostics.onlineDrivers} en ligne · '
              '${diagnostics.stalePosition} position(s) à rafraîchir',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textFaint,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.borderStrong),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                  ),
                  child: const Text(
                    'Réessayer',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (canWiden) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onWiden,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.orangeDark,
                      side: BorderSide(
                        color: AppColors.orange.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusMd,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Élargir le rayon',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAutoAssign,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
              icon: autoAssigning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_outlined, size: 17),
              label: Text(
                autoAssigning
                    ? 'Recherche en cours…'
                    : 'Assigner automatiquement',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _positionIssueText(DriverSelectionDiagnostics diagnostics) {
    if (diagnostics.withoutPosition > 0 && diagnostics.stalePosition == 0) {
      return '${diagnostics.withoutPosition} livreur(s) sont en ligne mais n’ont pas encore partagé leur position GPS.';
    }
    if (diagnostics.stalePosition > 0 && diagnostics.withoutPosition == 0) {
      return '${diagnostics.stalePosition} livreur(s) sont en ligne mais leur position GPS n’est plus à jour. Ils réapparaîtront dès qu’ils la partageront.';
    }
    return 'Des livreurs sont en ligne mais aucune position GPS récente n’est disponible pour le moment.';
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: AppColors.red),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Connexion interrompue — mise à jour en pause.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.red,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.red,
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

class _PrivacyFooter extends StatelessWidget {
  const _PrivacyFooter();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.shield_outlined,
            size: 14,
            color: AppColors.green,
          ),
        ),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Vos données sont sécurisées. Seuls les livreurs disponibles voient votre demande ; '
            'le contact direct est activé après acceptation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.orangeLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: AppColors.orange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.name,
    required this.address,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String name;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _freshness(int? ageSeconds) {
  if (ageSeconds == null) {
    return 'position non précisée';
  }
  if (ageSeconds < 60) {
    return 'position à jour';
  }
  if (ageSeconds < 3600) {
    return 'position il y a ${ageSeconds ~/ 60} min';
  }
  return 'position il y a ${ageSeconds ~/ 3600} h';
}

Color _freshnessColor(int? ageSeconds) {
  if (ageSeconds == null) {
    return AppColors.textFaint;
  }
  if (ageSeconds <= 60) {
    return AppColors.green;
  }
  if (ageSeconds <= 300) {
    return AppColors.goldDark;
  }
  return AppColors.red;
}

