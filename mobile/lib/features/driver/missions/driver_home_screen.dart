import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/services/driver_presence_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../shared/models/driver_mission.dart';
import '../../../shared/models/geo_point.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/home_header.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';
import 'mission_detail_screen.dart';

/// Missions livreur : commandes et colis réunis dans un même espace.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.marketplace,
    this.visible = true,
    this.userName,
    this.onOpenMenu,
  });

  final MarketplaceApi marketplace;
  final bool visible;
  final String? userName;
  final VoidCallback? onOpenMenu;

  @override
  State<DriverHomeScreen> createState() => DriverHomeScreenState();
}

class DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<DriverMission> _missions = [];
  Map<String, dynamic> _wallet = const {};
  bool _available = false;
  bool _loading = true;
  bool _toggling = false;
  String? _error;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Au retour au premier plan, la position peut être périmée : on la renvoie
    // tout de suite pour rester visible des clients.
    if (state == AppLifecycleState.resumed && _available) {
      unawaited(DriverPresenceService.reportNow());
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _pulseController.stop();
    if (_available && mounted && widget.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _available && widget.visible) {
          _pulseController.repeat(reverse: true);
        }
      });
    }
  }

  void _syncPulse() {
    if (!mounted) {
      return;
    }
    if (_available && widget.visible) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }
  }

  @override
  void didUpdateWidget(covariant DriverHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      _syncPulse();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DriverPresenceService.pauseHeartbeat();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statusFuture = widget.marketplace.driverStatus();
      final missionsFuture = widget.marketplace.driverMissions();
      final walletFuture = widget.marketplace
          .driverWallet()
          .catchError((Object _) => <String, dynamic>{});

      final results = await Future.wait<dynamic>([
        statusFuture,
        missionsFuture,
      ]);
      final status = results[0] as Map<String, dynamic>;
      final missions = results[1] as List<DriverMission>;
      final wallet = await walletFuture;
      final rawProfile = status['profile'];
      final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;

      if (mounted) {
        setState(() {
          _available = profile?['available'] == true;
          _missions = missions;
          _wallet = wallet;
          _loading = false;
        });
        _syncPulse();
        unawaited(DriverPresenceService.sync(widget.marketplace, _available));
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

  Future<void> _toggleAvailability(bool value) async {
    final previous = _available;
    setState(() {
      _available = value;
      _toggling = true;
    });
    try {
      if (value) {
        final failure = await DriverPresenceService.goOnline(widget.marketplace);
        if (failure != null) {
          if (mounted) {
            setState(() {
              _available = previous;
              _toggling = false;
            });
            _syncPulse();
            showToast(context, _locationFailureMessage(failure), isError: true);
          }
          return;
        }
      } else {
        await DriverPresenceService.goOffline(widget.marketplace);
      }
      if (mounted) {
        setState(() => _toggling = false);
        _syncPulse();
        showToast(
          context,
          value
              ? 'Vous êtes en ligne, votre position est partagée.'
              : 'Vous êtes indisponible.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _available = previous;
          _toggling = false;
        });
        _syncPulse();
        showToast(context, e.message, isError: true);
      }
    }
  }

  static String _locationFailureMessage(LocationFailure failure) => switch (failure) {
    LocationFailure.serviceDisabled =>
      'Activez le GPS de votre téléphone pour passer en ligne.',
    LocationFailure.permissionDenied =>
      'Autorisez la localisation pour recevoir des courses à proximité.',
    LocationFailure.unavailable =>
      'Position GPS introuvable. Réessayez dans un endroit dégagé.',
  };

  Future<void> _openMission(DriverMission mission) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MissionDetailScreen(
              marketplace: widget.marketplace,
              missionId: mission.id,
              kind: mission.kind,
              initialMission: mission,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  int _walletAmount(String key) {
    final value = _wallet[key];
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (widget.userName ?? '').trim().split(' ').first;
    final greeting = firstName.isEmpty || firstName == 'null'
        ? 'Bonjour'
        : 'Bonjour, $firstName';

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: _load,
        child: _buildBody(greeting),
      ),
    );
  }

  Widget _buildBody(String greeting) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          BeninfoodAppBar(
            onMenu: widget.onOpenMenu,
            api: widget.marketplace,
            audience: NotificationAudience.driver,
          ),
          const SizedBox(height: 120),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final active = _missions.where((mission) => mission.isActive).toList();
    final deliveredCount = _missions.where((mission) => mission.isDelivered).length;
    final availableBalance = _walletAmount('available_balance');
    final pendingBalance = _walletAmount('pending_balance');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppDimens.xl),
      children: [
        BeninfoodAppBar(
          onMenu: widget.onOpenMenu,
          api: widget.marketplace,
          audience: NotificationAudience.driver,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            10,
            AppDimens.pagePadding,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active.isEmpty
                          ? 'Prêt pour votre prochaine course ?'
                          : '${active.length} mission${active.length > 1 ? 's' : ''} en cours',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.orangeLight,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.delivery_dining,
                  color: AppColors.orange,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
          child: Column(
            children: [
              _AvailabilityCard(
                available: _available,
                toggling: _toggling,
                onToggle: _toggleAvailability,
                pulseController: _pulseController,
              ),
              const SizedBox(height: AppDimens.md),
              Row(
                children: [
                  Expanded(
                    child: HomeStatTile(
                      icon: Icons.local_shipping_outlined,
                      value: '${active.length}',
                      label: 'En cours',
                      accent: AppColors.orange,
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: HomeStatTile(
                      icon: Icons.check_circle_outline,
                      value: '$deliveredCount',
                      label: 'Terminées',
                      accent: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: HomeStatTile(
                      icon: Icons.account_balance_wallet_outlined,
                      value: formatAmount(availableBalance, showSymbol: false),
                      label: 'Solde dispo.',
                      accent: AppColors.goldDark,
                    ),
                  ),
                ],
              ),
              if (pendingBalance > 0) ...[
                const SizedBox(height: AppDimens.sm),
                _PendingBalanceStrip(amount: pendingBalance),
              ],
            ],
          ),
        ),
        const SectionHeader(title: 'Missions en cours'),
        if (active.isEmpty)
          _EmptyMissionsState(
            pulseController: _pulseController,
            available: _available,
          )
        else
          ...active.asMap().entries.map((entry) {
            final index = entry.key;
            final mission = entry.value;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - value)),
                  child: child,
                ),
              ),
              child: _MissionCard(
                mission: mission,
                delay: Duration(milliseconds: 80 * index),
                onTap: () => _openMission(mission),
              ),
            );
          }),
        const SizedBox(height: AppDimens.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
          child: Text(
            _available
                ? 'Nouvelles offres : commandes et colis arrivent dans vos onglets.'
                : 'Activez votre disponibilité pour recevoir des missions.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint),
          ),
        ),
      ],
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.available,
    required this.toggling,
    required this.onToggle,
    required this.pulseController,
  });

  final bool available;
  final bool toggling;
  final ValueChanged<bool> onToggle;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    final background = available
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A5B2E), Color(0xFF2F7D4A)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF43514B), Color(0xFF68756F)],
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: background,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: (available ? AppColors.green : AppColors.text)
                .withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: pulseController,
                builder: (context, child) => Transform.scale(
                  scale: available ? 1 + pulseController.value * 0.08 : 1,
                  child: child,
                ),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    available ? Icons.bolt : Icons.pause,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      available ? 'Vous êtes en ligne' : 'Vous êtes hors ligne',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      available
                          ? 'Les offres de commandes et de colis vous sont proposées.'
                          : 'Activez le mode en ligne pour recevoir des missions.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: available,
                onChanged: toggling ? null : onToggle,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.white.withValues(alpha: 0.45),
                inactiveThumbColor: Colors.white.withValues(alpha: 0.8),
                inactiveTrackColor: Colors.black.withValues(alpha: 0.22),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatusPill(
                icon: available ? Icons.gps_fixed : Icons.gps_off,
                label: available ? 'Position partagée' : 'Suivi en pause',
              ),
              const SizedBox(width: 8),
              const _StatusPill(
                icon: Icons.notifications_active_outlined,
                label: 'Offres en direct',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingBalanceStrip extends StatelessWidget {
  const _PendingBalanceStrip({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 16, color: AppColors.goldDark),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Gains en attente de confirmation',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.goldDark,
              ),
            ),
          ),
          AmountText(
            amount,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.goldDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMissionsState extends StatelessWidget {
  const _EmptyMissionsState({
    required this.pulseController,
    required this.available,
  });

  final AnimationController pulseController;
  final bool available;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: pulseController,
              builder: (context, child) => Transform.scale(
                scale: 1 + pulseController.value * 0.04,
                child: child,
              ),
              child: Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  color: AppColors.orangeLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.delivery_dining,
                  size: 42,
                  color: AppColors.orange,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Aucune mission en cours',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              available
                  ? 'Vos prochaines commandes et colis acceptés apparaîtront ici.'
                  : 'Activez votre disponibilité puis acceptez une offre.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionCard extends StatefulWidget {
  const _MissionCard({
    required this.mission,
    required this.onTap,
    this.delay = Duration.zero,
  });

  final DriverMission mission;
  final VoidCallback onTap;
  final Duration delay;

  @override
  State<_MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<_MissionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final mission = widget.mission;
    final palette = mission.isParcel
        ? BadgePalette.parcel(mission.status)
        : BadgePalette.delivery(mission.status);
    final routeDistance = mission.distanceKm ??
        _directDistance(mission.pickup.point, mission.dropoff.point);
    final eta = routeDistance == null ? null : estimateMinutes(routeDistance);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            0,
            AppDimens.pagePadding,
            12,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: _hover ? AppColors.orange : AppColors.border,
              width: _hover ? 1.3 : 1,
            ),
            boxShadow: _hover ? AppTheme.softShadow() : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: mission.isParcel
                            ? AppColors.greenLight
                            : AppColors.orangeLight,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: mission.imageUrl != null
                          ? AppNetworkImage(
                              url: mission.imageUrl,
                              icon: mission.isParcel
                                  ? Icons.inventory_2_outlined
                                  : Icons.storefront_outlined,
                            )
                          : Icon(
                              mission.isParcel
                                  ? Icons.inventory_2_outlined
                                  : Icons.storefront_outlined,
                              color: mission.isParcel
                                  ? AppColors.green
                                  : AppColors.orange,
                              size: 25,
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
                                  mission.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                mission.shortKindLabel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: mission.isParcel
                                      ? AppColors.green
                                      : AppColors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mission.reference,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (palette != null)
                      StatusBadge(
                        label: palette.$1,
                        color: palette.$2,
                        small: true,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _RouteSummary(mission: mission),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            size: 14,
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 5),
                          AmountText(
                            mission.earnings,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'gain',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (routeDistance != null)
                      _MetaChip(
                        icon: Icons.route_outlined,
                        label: formatDistance(routeDistance),
                      ),
                    if (eta != null)
                      _MetaChip(
                        icon: Icons.schedule,
                        label: formatEta(eta),
                      ),
                    if (mission.isOrder && mission.itemCount > 0)
                      _MetaChip(
                        icon: Icons.shopping_bag_outlined,
                        label: '${mission.itemCount} art.',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: mission.isParcel
                          ? AppColors.green
                          : AppColors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusMd,
                        ),
                      ),
                    ),
                    icon: Icon(_actionIcon(mission.status), size: 18),
                    label: Text(
                      mission.actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _actionIcon(String status) => switch (status) {
    'assigned' => Icons.play_arrow_rounded,
    'en_route_pickup' || 'in_delivery' => Icons.navigation_outlined,
    'picked_up' => Icons.two_wheeler,
    _ => Icons.arrow_forward,
  };

  static double? _directDistance(GeoPoint? from, GeoPoint? to) {
    if (from == null || to == null) {
      return null;
    }
    return distanceKm(from.latLng, to.latLng);
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.mission});

  final DriverMission mission;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RouteLine(
          color: AppColors.green,
          label: 'Collecte',
          title: mission.pickup.title,
          address: mission.pickup.displayAddress,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 7),
          child: Row(
            children: [
              Container(
                width: 2,
                height: 10,
                color: AppColors.borderStrong,
              ),
            ],
          ),
        ),
        _RouteLine(
          color: AppColors.orange,
          label: mission.isParcel ? 'Livraison' : 'Client',
          title: mission.dropoff.title,
          address: mission.dropoff.displayAddress,
        ),
      ],
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.color,
    required this.label,
    required this.title,
    required this.address,
  });

  final Color color;
  final String label;
  final String title;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Row(
            children: [
              Text(
                '$label · ',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Expanded(
                child: Text(
                  '$title — $address',
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
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
