import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/marketplace_api.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo.dart';
import '../models/driver_selection.dart';
import 'app_map.dart';
import 'app_network_image.dart';
import 'feedback_widgets.dart';
import 'state_widgets.dart';

/// Ouvre la sélection d'un livreur proche pour une commande ou un colis.
///
/// Retourne `true` si un livreur a fini par accepter pendant que la feuille
/// était ouverte, `null` sinon.
Future<bool?> showDriverSelectionSheet(
  BuildContext context,
  MarketplaceApi marketplace, {
  required String targetId,
  required bool isParcel,
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _DriverSelectionSheet(
      marketplace: marketplace,
      targetId: targetId,
      isParcel: isParcel,
      onChanged: onChanged,
    ),
  );
}

class _DriverSelectionSheet extends StatefulWidget {
  const _DriverSelectionSheet({
    required this.marketplace,
    required this.targetId,
    required this.isParcel,
    this.onChanged,
  });

  final MarketplaceApi marketplace;
  final String targetId;
  final bool isParcel;
  final VoidCallback? onChanged;

  @override
  State<_DriverSelectionSheet> createState() => _DriverSelectionSheetState();
}

class _DriverSelectionSheetState extends State<_DriverSelectionSheet> {
  static const _pollInterval = Duration(seconds: 5);

  DriverSelectionPage? _page;
  bool _loading = true;
  bool _polling = false;
  String? _error;
  String? _actionDriverId;
  bool _cancelling = false;
  bool _assignedNotified = false;
  Timer? _pollTimer;

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

  Future<DriverSelectionPage> _fetch() {
    return widget.isParcel
        ? widget.marketplace.parcelNearbyDrivers(widget.targetId)
        : widget.marketplace.orderNearbyDrivers(widget.targetId);
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
      });
      _startPolling();
      _closeIfAssigned(page);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (!silent) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refreshSilently());
  }

  Future<void> _refreshSilently() async {
    if (_polling) {
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
        _error = null;
      });
      _closeIfAssigned(page);
    } on ApiException {
      // Silence : on conserve la dernière liste connue.
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
        showToast(context, 'Le livreur a accepté la course.');
        Navigator.of(context).pop(true);
      }
    });
  }

  Future<void> _request(NearbyDriver driver) async {
    setState(() => _actionDriverId = driver.id);
    try {
      final request = widget.isParcel
          ? await widget.marketplace.requestParcelDriver(
              widget.targetId,
              driver.id,
            )
          : await widget.marketplace.requestOrderDriver(
              widget.targetId,
              driver.id,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _page = DriverSelectionPage(
          pickup: _page?.pickup,
          dropoff: _page?.dropoff,
          radiusKm: _page?.radiusKm ?? 0,
          requestedRadiusKm: _page?.requestedRadiusKm ?? 0,
          maxRadiusKm: _page?.maxRadiusKm ?? 0,
          expanded: _page?.expanded ?? false,
          drivers: _page?.drivers ?? const [],
          request: request,
        );
      });
      widget.onChanged?.call();
      showToast(context, 'Demande envoyée à ${driver.displayName}.');
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _actionDriverId = null);
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

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.delivery_dining_outlined,
                  color: AppColors.orange,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Choisir mon livreur',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: ErrorState(message: _error!, onRetry: _load),
      );
    }

    final page = _page!;
    final request = page.request;

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (page.pickup?.point != null || page.dropoff?.point != null) ...[
            AppMap(
              secondary: page.pickup?.point,
              secondaryLabel: 'Collecte',
              secondaryIcon: Icons.storefront_outlined,
              secondaryColor: AppColors.gold,
              target: page.dropoff?.point,
              targetLabel: 'Livraison',
              targetIcon: Icons.place,
              targetColor: AppColors.orange,
              extraMarkers: [
                for (final driver in page.drivers)
                  if (driver.position != null)
                    AppMapMarker(
                      point: driver.position!.point,
                      label: _shortName(driver.displayName),
                      imageUrl: driver.avatarUrl,
                      heading: driver.position!.heading,
                    ),
              ],
              height: 210,
              initialZoom: 13,
              followOrigin: false,
              showRoute: false,
              expandable: false,
            ),
            const SizedBox(height: AppDimens.md),
          ],
          _RadiusBanner(page: page),
          const SizedBox(height: AppDimens.sm),
          if (request != null && request.isPending)
            _WaitingCard(
              request: request,
              cancelling: _cancelling,
              onCancel: _cancelRequest,
            )
          else ...[
            if (request != null &&
                (request.isRefused || request.isExpired)) ...[
              _RequestNotice(request: request),
              const SizedBox(height: AppDimens.sm),
            ],
            if (page.drivers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppDimens.lg),
                child: EmptyState(
                  icon: Icons.delivery_dining_outlined,
                  title: 'Aucun livreur disponible',
                  subtitle:
                      'Aucun livreur disponible pour le moment. Réessayez dans quelques instants ou laissez la plateforme affecter un livreur automatiquement.',
                  actionLabel: 'Actualiser',
                  onAction: () => _load(),
                ),
              )
            else
              for (var i = 0; i < page.drivers.length; i++) ...[
                _NearbyDriverCard(
                  driver: page.drivers[i],
                  closest: i == 0,
                  busy: _actionDriverId,
                  pickupLabel: widget.isParcel
                      ? 'Livreur → ramassage'
                      : 'Livreur → commerce',
                  dropoffLabel: widget.isParcel
                      ? 'Ramassage → livraison'
                      : 'Commerce → vous',
                  onRequest: () => _request(page.drivers[i]),
                ),
                const SizedBox(height: AppDimens.sm),
              ],
          ],
        ],
      ),
    );
  }

  String _shortName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? name : parts.first;
  }
}

class _RadiusBanner extends StatelessWidget {
  const _RadiusBanner({required this.page});

  final DriverSelectionPage page;

  @override
  Widget build(BuildContext context) {
    final count = page.drivers.length;
    final radius = formatDistance(page.radiusKm);
    final text = page.expanded
        ? 'Rayon élargi à $radius pour trouver $count livreur(s).'
        : '$count livreur(s) à moins de $radius du point de collecte.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.radar, size: 18, color: AppColors.orangeDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.orangeDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyDriverCard extends StatelessWidget {
  const _NearbyDriverCard({
    required this.driver,
    required this.closest,
    required this.busy,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.onRequest,
  });

  final NearbyDriver driver;
  final bool closest;
  final String? busy;
  final String pickupLabel;
  final String dropoffLabel;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = busy == driver.id;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        side: BorderSide(
          color: closest ? AppColors.orange : AppColors.border,
          width: closest ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                const SizedBox(width: 12),
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
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          if (closest) ...[
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orangeDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _driverSubtitle(driver),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: Icons.near_me_outlined,
                  label:
                      '$pickupLabel : ${formatDistance(driver.distanceToPickupKm)}'
                      '${driver.etaToPickupSeconds != null ? ' · ~${_eta(driver.etaToPickupSeconds)}' : ''}',
                ),
                if (driver.pickupToDropoffKm != null)
                  _InfoChip(
                    icon: Icons.alt_route,
                    label:
                        '$dropoffLabel : ${formatDistance(driver.pickupToDropoffKm!)}'
                        '${driver.etaToDropoffSeconds != null ? ' · ~${_eta(driver.etaToDropoffSeconds)}' : ''}',
                  ),
                if (driver.etaTotalSeconds != null)
                  _InfoChip(
                    icon: Icons.route,
                    label: 'Total livraison ~${_eta(driver.etaTotalSeconds)}',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: busy == null ? onRequest : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
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
                    : const Icon(Icons.send_outlined, size: 18),
                label: const Text('Demander'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _driverSubtitle(NearbyDriver driver) {
    final parts = <String>[
      if (driver.vehicle != null && driver.vehicle!.trim().isNotEmpty)
        driver.vehicle!.trim(),
      if (driver.rating != null && driver.rating! > 0)
        '★ ${driver.rating!.toStringAsFixed(1)}',
      '${driver.completedDeliveries} course(s) livrée(s)',
    ];
    return parts.join(' · ');
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
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
      color: AppColors.goldLight,
      elevation: 0,
      margin: EdgeInsets.zero,
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
            const SizedBox(height: 6),
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

class _RequestNotice extends StatelessWidget {
  const _RequestNotice({required this.request});

  final DriverRequestInfo request;

  @override
  Widget build(BuildContext context) {
    final refused = request.isRefused;
    final title = refused
        ? 'Le livreur a décliné la demande'
        : 'La demande a expiré';
    final reason = request.refusalReason;
    final subtitle = reason != null && reason.trim().isNotEmpty
        ? reason.trim()
        : 'Choisissez un autre livreur proche pour votre ${request.isRefused ? 'course' : 'livraison'}.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
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

String _eta(int? seconds) {
  if (seconds == null) {
    return '—';
  }
  return '~${formatEta((seconds / 60).ceil())}';
}
