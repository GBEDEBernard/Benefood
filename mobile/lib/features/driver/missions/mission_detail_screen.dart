import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/driver_mission.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/call_button.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/package_item_tile.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';
import 'mission_navigation_screen.dart';

/// Détail d'une mission livreur : commande restaurant ou colis.
class MissionDetailScreen extends StatefulWidget {
  const MissionDetailScreen({
    super.key,
    required this.marketplace,
    required this.missionId,
    required this.kind,
    this.initialMission,
  });

  final MarketplaceApi marketplace;
  final String missionId;
  final DriverMissionKind kind;
  final DriverMission? initialMission;

  @override
  State<MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends State<MissionDetailScreen> {
  DriverMission? _mission;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mission = widget.initialMission;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final missions = await widget.marketplace.driverMissions();
      DriverMission? match;
      for (final mission in missions) {
        if (mission.id == widget.missionId && mission.kind == widget.kind) {
          match = mission;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _mission = match ?? _mission;
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

  Future<void> _startPickup() async {
    final mission = _mission;
    if (mission == null) {
      return;
    }
    setState(() => _actionLoading = true);
    try {
      if (mission.isParcel) {
        await widget.marketplace.startParcelPickup(mission.id);
      } else {
        await widget.marketplace.startDeliveryPickup(mission.id);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _mission = mission.copyWithStatus('en_route_pickup');
        _actionLoading = false;
      });
      await _openNavigation();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _startDelivery() async {
    final mission = _mission;
    if (mission == null) {
      return;
    }
    setState(() => _actionLoading = true);
    try {
      if (mission.isParcel) {
        await widget.marketplace.startParcelDelivery(mission.id);
      } else {
        await widget.marketplace.markInDelivery(mission.id);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _mission = mission.copyWithStatus('in_delivery');
        _actionLoading = false;
      });
      await _openNavigation();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _confirmHandover() async {
    final mission = _mission;
    if (mission == null) {
      return;
    }
    final code = await _askHandoverCode();
    if (code == null || !mounted) {
      return;
    }
    setState(() => _actionLoading = true);
    try {
      await widget.marketplace.confirmHandover(mission.id, code);
      if (mounted) {
        showToast(context, 'Remise du colis confirmée.');
        await _load();
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

  Future<String?> _askHandoverCode() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la remise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saisissez le code communiqué par le client pour reprendre la livraison.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Code de remise *'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(context).pop(value);
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _openNavigation() async {
    final mission = _mission;
    if (mission == null) {
      return;
    }
    final updated = await Navigator.of(context).push<DriverMission>(
      MaterialPageRoute(
        builder: (_) => MissionNavigationScreen(
          marketplace: widget.marketplace,
          mission: mission,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (updated != null) {
      setState(() => _mission = updated);
    }
    await _load();
  }

  Future<void> _reportIncident() async {
    final mission = _mission;
    if (mission == null) {
      return;
    }
    final message = await _askIncidentMessage();
    if (message == null || !mounted) {
      return;
    }
    setState(() => _actionLoading = true);
    try {
      await widget.marketplace.reportIncident(mission.id, message);
      if (mounted) {
        setState(() => _actionLoading = false);
        showToast(context, 'Incident signalé.');
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<String?> _askIncidentMessage() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
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
      body: Column(
        children: [
          BeninfoodAppBar(
            onMenu: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                context.go('/driver');
              }
            },
            api: widget.marketplace,
            audience: NotificationAudience.driver,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _mission == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _mission == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final mission = _mission;
    if (mission == null) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Mission introuvable',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          AppDimens.sm,
          AppDimens.pagePadding,
          AppDimens.xl,
        ),
        children: [
          _MissionHero(mission: mission),
          const SizedBox(height: AppDimens.md),
          if (mission.isActive && mission.hasPendingHandover) ...[
            _HandoverCard(loading: _actionLoading, onConfirm: _confirmHandover),
            const SizedBox(height: AppDimens.md),
          ],
          if (mission.isActive) _buildAction(mission),
          if (mission.isDelivered) ...[
            const SizedBox(height: AppDimens.md),
            const _CompletedBanner(),
          ],
          const SizedBox(height: AppDimens.md),
          _MapPreview(mission: mission),
          const SizedBox(height: AppDimens.md),
          _StopsCard(mission: mission),
          if (mission.items.isNotEmpty) ...[
            const SizedBox(height: AppDimens.md),
            PackageContentCard(
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
          ],
          if (mission.isOrder &&
              (mission.description?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: AppDimens.md),
            _NoteCard(note: mission.description!.trim()),
          ],
          const SizedBox(height: AppDimens.md),
          _FeeCard(mission: mission),
          const SizedBox(height: AppDimens.md),
          _MissionTimeline(mission: mission),
          if (mission.isOrder && mission.isActive) ...[
            const SizedBox(height: AppDimens.md),
            TextButton.icon(
              onPressed: _actionLoading ? null : _reportIncident,
              icon: const Icon(Icons.report_problem_outlined, size: 18),
              label: const Text('Signaler un incident'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAction(DriverMission mission) {
    if (mission.hasPendingHandover) {
      return const SizedBox.shrink();
    }

    final requiredAction = switch (mission.status) {
      'assigned' => _startPickup,
      'picked_up' => _startDelivery,
      _ => _openNavigation,
    };

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _actionLoading ? null : requiredAction,
            style: FilledButton.styleFrom(
              backgroundColor: mission.isParcel
                  ? AppColors.green
                  : AppColors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
            ),
            icon: _actionLoading
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_actionIcon(mission.status), size: 21),
            label: Text(
              mission.actionLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          switch (mission.status) {
            'assigned' => 'Confirmez votre départ vers le point de collecte.',
            'en_route_pickup' =>
              'La confirmation de collecte se fait dans la navigation.',
            'picked_up' =>
              'La livraison sera activée après confirmation du départ.',
            'in_delivery' =>
              'Saisissez le code client pour finaliser la livraison.',
            _ => '',
          },
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint),
        ),
      ],
    );
  }

  static IconData _actionIcon(String status) => switch (status) {
    'assigned' => Icons.play_arrow_rounded,
    'en_route_pickup' || 'in_delivery' => Icons.navigation_outlined,
    'picked_up' => Icons.two_wheeler,
    _ => Icons.arrow_forward,
  };
}

class _MissionHero extends StatelessWidget {
  const _MissionHero({required this.mission});

  final DriverMission mission;

  @override
  Widget build(BuildContext context) {
    final palette = mission.isParcel
        ? BadgePalette.parcel(mission.status)
        : BadgePalette.delivery(mission.status);
    final gradient = mission.isParcel
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF124C33), Color(0xFF2F7D4A)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB34B00), Color(0xFFF07A1A)],
          );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: (mission.isParcel ? AppColors.green : AppColors.orange)
                .withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                child: Text(
                  mission.kindLabel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (palette != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  child: Text(
                    palette.$1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: palette.$2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                ),
                clipBehavior: Clip.antiAlias,
                child: AppNetworkImage(
                  url: mission.imageUrl,
                  icon: mission.isParcel
                      ? Icons.inventory_2_outlined
                      : Icons.storefront_outlined,
                  iconColor: mission.isParcel
                      ? AppColors.green
                      : AppColors.orange,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mission.reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 19,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Votre gain',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                AmountText(
                  mission.earnings,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

class _HandoverCard extends StatelessWidget {
  const _HandoverCard({required this.loading, required this.onConfirm});

  final bool loading;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.orangeLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.handshake_outlined,
                  color: AppColors.orangeDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reprise du colis',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.orangeDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Ce colis vous a été remis par un autre livreur. Demandez le code de remise au client pour confirmer la reprise.',
              style: TextStyle(fontSize: 12.5, color: AppColors.orangeDark),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: loading ? null : onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orangeDark,
                  foregroundColor: Colors.white,
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
                    : const Icon(Icons.lock_open_outlined, size: 18),
                label: const Text('Confirmer la remise'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.green),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mission terminée',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Merci, votre gain a été enregistré.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
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

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.mission});

  final DriverMission mission;

  @override
  Widget build(BuildContext context) {
    final current = mission.currentStop;
    final other = mission.isPickupPhase ? mission.dropoff : mission.pickup;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: AppMap(
        target: current.point,
        targetLabel: current.title,
        targetImageUrl: current.imageUrl,
        targetIcon: mission.isPickupPhase
            ? Icons.storefront_outlined
            : Icons.location_on_outlined,
        targetColor: mission.isPickupPhase ? AppColors.gold : AppColors.orange,
        secondary: other.point,
        secondaryLabel: other.title,
        secondaryImageUrl: other.imageUrl,
        secondaryIcon: mission.isPickupPhase
            ? Icons.place_outlined
            : Icons.inventory_2_outlined,
        secondaryColor: mission.isPickupPhase
            ? AppColors.orange
            : AppColors.gold,
        height: 210,
      ),
    );
  }
}

class _StopsCard extends StatelessWidget {
  const _StopsCard({required this.mission});

  final DriverMission mission;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        children: [
          _StopTile(
            label: mission.isParcel ? 'Expéditeur' : 'Point de collecte',
            stop: mission.pickup,
            icon: mission.isParcel
                ? Icons.inventory_2_outlined
                : Icons.storefront_outlined,
            color: AppColors.green,
          ),
          const Divider(height: 1, indent: 62),
          _StopTile(
            label: mission.isParcel ? 'Destinataire' : 'Client',
            stop: mission.dropoff,
            icon: Icons.person_pin_circle_outlined,
            color: AppColors.orange,
          ),
        ],
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.label,
    required this.stop,
    required this.icon,
    required this.color,
  });

  final String label;
  final DriverMissionStop stop;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final phone = stop.contactPhone?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stop.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stop.displayAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (stop.contactName != null &&
                    stop.contactName!.trim().isNotEmpty &&
                    stop.contactName!.trim() != stop.title.trim()) ...[
                  const SizedBox(height: 2),
                  Text(
                    stop.contactName!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (phone.isNotEmpty)
            CallButton(label: 'Appeler', phone: phone, compact: true),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notes, size: 18, color: AppColors.goldDark),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({required this.mission});

  final DriverMission mission;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        children: [
          _FeeRow(
            label: 'Votre gain',
            amount: mission.earnings,
            emphasized: true,
          ),
          if (mission.clientFee != mission.earnings) ...[
            const SizedBox(height: 9),
            _FeeRow(
              label: 'Frais de livraison client',
              amount: mission.clientFee,
            ),
          ],
          if (mission.distanceKm != null) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(
                  Icons.route_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 7),
                const Text(
                  'Distance estimée',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  formatDistance(mission.distanceKm),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final int amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasized ? 13.5 : 12.5,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
            color: emphasized ? AppColors.text : AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        AmountText(
          amount,
          style: TextStyle(
            fontSize: emphasized ? 16 : 12.5,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            color: emphasized ? AppColors.orange : AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _MissionTimeline extends StatelessWidget {
  const _MissionTimeline({required this.mission});

  final DriverMission mission;

  List<_TimelineStep> get _steps => [
    _TimelineStep('Acceptée', Icons.check_circle_outline, AppColors.green),
    _TimelineStep(
      'En route vers la collecte',
      Icons.navigation_outlined,
      AppColors.orange,
    ),
    _TimelineStep(
      mission.isParcel ? 'Colis récupéré' : 'Commande récupérée',
      Icons.inventory_2_outlined,
      AppColors.gold,
    ),
    _TimelineStep('En route vers le client', Icons.two_wheeler, AppColors.blue),
    _TimelineStep(
      mission.isParcel ? 'Livré' : 'Livrée',
      Icons.verified_outlined,
      AppColors.green,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final current = mission.currentStep;
    final steps = _steps;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progression',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final completed = index <= current;
            final isCurrent = index == current;
            final color = completed ? step.color : AppColors.textFaint;
            final isLast = index == steps.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 28,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: completed
                                ? color.withValues(alpha: 0.13)
                                : AppColors.surfaceVariant,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: completed ? color : AppColors.borderStrong,
                              width: isCurrent ? 2 : 1.2,
                            ),
                          ),
                          child: Icon(
                            completed ? Icons.check : step.icon,
                            size: 14,
                            color: color,
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                color: index < current
                                    ? steps[index + 1].color.withValues(
                                        alpha: 0.45,
                                      )
                                    : AppColors.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 3, bottom: isLast ? 0 : 17),
                      child: Text(
                        step.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isCurrent
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: isCurrent
                              ? AppColors.text
                              : completed
                              ? AppColors.textSecondary
                              : AppColors.textFaint,
                        ),
                      ),
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      margin: const EdgeInsets.only(bottom: 17),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusPill,
                        ),
                      ),
                      child: Text(
                        'En cours',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineStep {
  const _TimelineStep(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
