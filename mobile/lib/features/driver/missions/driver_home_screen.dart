import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/delivery.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/home_header.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../core/utils/formatters.dart';
import 'mission_detail_screen.dart';

/// Missions livreur (J161) : disponibilité et livraisons en cours.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.marketplace,
    this.visible = true,
    this.userName,
  });

  final MarketplaceApi marketplace;
  final bool visible;
  final String? userName;

  @override
  State<DriverHomeScreen> createState() => DriverHomeScreenState();
}

class DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  List<Delivery> _deliveries = [];
  bool _available = false;
  bool _loading = true;
  bool _toggling = false;
  String? _error;
  late final AnimationController _pulseController;

  static const _activeStatuses = {'assigned', 'picked_up', 'in_delivery'};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _load();
  }

  /// Stop the pulse animation during hot-reload/reassemble to prevent
  /// OpenGL frame timeouts and slow rebuilds.
  @override
  void reassemble() {
    super.reassemble();
    _pulseController.stop();
    if (_available && mounted && widget.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _available && widget.visible) {
          _pulseController.repeat(reverse: true);
        } });
    }
  }

  /// Start or stop the pulse animation based on visibility and availability.
  void _syncPulse() {
    if (!mounted) return;
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
    _pulseController.dispose();
    super.dispose();
  }

  /// Rafraîchit les missions depuis l'API.
  /// Appelé depuis DriverShell quand on retourne sur l'onglet Missions
  /// ou après qu'une offre a été acceptée dans l'onglet Offres.
  Future<void> refresh() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await widget.marketplace.driverStatus();
      final deliveries = await widget.marketplace.myDeliveries();
      final rawProfile = status['profile'];
      final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
      if (mounted) {
        setState(() {
          _available = profile?['available'] == true;
          _deliveries = deliveries;
          _loading = false;
        });
        // Only run the pulse animation when the driver is available.
        // This prevents unnecessary 60fps rebuilds on the render thread.
        _syncPulse();
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
      await widget.marketplace.setAvailability(value);
      if (mounted) {
        setState(() => _toggling = false);
        showToast(context, value ? 'Vous êtes disponible.' : 'Vous êtes indisponible.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _available = previous;
          _toggling = false;
        });
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _reportIncident(Delivery delivery) async {
    final message = await _askIncidentMessage();
    if (message == null || !mounted) {
      return;
    }
    try {
      await widget.marketplace.reportIncident(delivery.id, message);
      await _load();
      if (mounted) {
        showToast(context, 'Incident signalé.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<String?> _askIncidentMessage() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signaler un incident'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Décrivez l\'incident *'),
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
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (widget.userName ?? '').trim().split(' ').first;
    final greeting = firstName.isEmpty || firstName == 'null'
        ? 'Bonjour 👋'
        : 'Bonjour, $firstName 👋';

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
          HomeHeader(
            title: greeting,
            subtitle: 'Préparation de vos missions…',
            leading: const HomeBadgeIcon(icon: Icons.delivery_dining),
          ),
          const SizedBox(height: 120),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final active = _deliveries.where((d) => _activeStatuses.contains(d.status)).toList();
    final delivered = _deliveries.where((d) => d.status == 'delivered').toList();
    final earnings = delivered.fold<int>(
      0,
      (sum, d) => sum + (d.partnerAmount ?? d.fee),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppDimens.xl),
      children: [
        HomeHeader(
          title: greeting,
          subtitle: 'Prêt pour vos livraisons du jour ?',
          leading: const HomeBadgeIcon(icon: Icons.delivery_dining),
          actions: [
            HomeHeaderAction(
              icon: Icons.refresh,
              tooltip: 'Rafraîchir',
              onPressed: _load,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
          child: Column(
            children: [
              // --- Carte héro : disponibilité ---
              _AvailabilityCard(
                available: _available,
                toggling: _toggling,
                onToggle: _toggleAvailability,
                pulseController: _pulseController,
              ),
              const SizedBox(height: AppDimens.md),
              // --- Statistiques du jour ---
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
                      value: '${delivered.length}',
                      label: 'Terminées',
                      accent: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: HomeStatTile(
                      icon: Icons.payments_outlined,
                      value: formatAmount(earnings, showSymbol: false),
                      label: 'Gains FCFA',
                      accent: AppColors.goldDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Missions en cours'),
        if (active.isEmpty)
          _EmptyMissionsState(pulseController: _pulseController)
        else
          ...active.asMap().entries.map((entry) {
              final index = entry.key;
              final delivery = entry.value;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
                builder: (context, value, child) => Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                ),
                child: _MissionCard(
                  delivery: delivery,
                  delay: Duration(milliseconds: 100 * index),
                  onTap: () => Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => MissionDetailScreen(
                        marketplace: widget.marketplace,
                        deliveryId: delivery.id,
                        initialDelivery: delivery,
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1, 0);
                        const end = Offset.zero;
                        const curve = Curves.easeOut;
                        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        return SlideTransition(position: animation.drive(tween), child: child);
                      },
                    ),
                  ),
                  onIncident: () => _reportIncident(delivery),
                ),
              );
            }),
        const SizedBox(height: AppDimens.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
          child: Text(
            _available
                ? 'Vous êtes en ligne : les nouvelles offres arrivent ici.'
                : 'Activez votre disponibilité pour recevoir des offres.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint),
          ),
        ),
      ],
    );
  }
}

/// Carte de disponibilité livreur avec animation du toggle.
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: Card(
        key: ValueKey<bool>(available),
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: BorderSide(color: available ? AppColors.orangeLight : AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: pulseController,
                    builder: (context, child) => Transform.scale(
                      scale: available ? 1 + pulseController.value * 0.1 : 1,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: available
                              ? AppColors.orangeLight
                              : AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          available ? Icons.check_circle : Icons.pause_circle_outline,
                          color: available ? AppColors.orange : AppColors.textSecondary,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disponible pour les livraisons',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          available
                              ? 'Vous recevez des offres. Votre position est partagée pendant vos missions.'
                              : 'Vous ne recevez pas d\'offres.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: available,
                    onChanged: toggling ? null : onToggle,
                    activeThumbColor: AppColors.orange,
                    activeTrackColor: AppColors.orange.withValues(alpha: 0.4),
                    inactiveThumbColor: AppColors.textSecondary,
                    inactiveTrackColor: AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                ],
              ),
              if (available) ...[
                const SizedBox(height: 10),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: AppColors.goldLight,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 0.6,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(colors: [AppColors.orange, AppColors.gold]),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state animée pour la liste des missions.
class _EmptyMissionsState extends StatelessWidget {
  const _EmptyMissionsState({required this.pulseController});

  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: pulseController,
              builder: (context, child) => Transform.scale(
                scale: 1 + pulseController.value * 0.05,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.orangeLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delivery_dining, size: 44, color: AppColors.orange),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune mission en cours',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Activez votre disponibilité pour recevoir des offres.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte mission avec effet de survol et couleurs alimentaires.
class _MissionCard extends StatefulWidget {
  const _MissionCard({
    required this.delivery,
    required this.onTap,
    required this.onIncident,
    this.delay = Duration.zero,
  });

  final Delivery delivery;
  final VoidCallback onTap;
  final VoidCallback onIncident;
  final Duration delay;

  @override
  State<_MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<_MissionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = BadgePalette.delivery(widget.delivery.status);
    final reference = widget.delivery.order?.reference ?? 'Mission';
    final vendorName = widget.delivery.vendor?.businessName ?? 'Vendeur';
    final clientAddress = widget.delivery.order?.address;
    final amount = widget.delivery.partnerAmount ?? widget.delivery.fee;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.fromLTRB(AppDimens.pagePadding, 0, AppDimens.pagePadding, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(color: _hover ? AppColors.orange : AppColors.border),
            boxShadow: _hover ? AppTheme.softShadow() : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reference,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (palette != null)
                      StatusBadge(label: palette.$1, color: palette.$2, small: true),
                  ],
                ),
                const SizedBox(height: AppDimens.sm),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.goldLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.storefront_outlined, size: 20, color: AppColors.gold),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vendorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
                      ),
                    ),
                  ],
                ),
                if (clientAddress != null && clientAddress.isNotEmpty) ...[
                  const SizedBox(height: AppDimens.xs),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          clientAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
                // Aperçu photo du colis à collecter
                if ((widget.delivery.order?.items.isNotEmpty ?? false)) ...[
                  const SizedBox(height: AppDimens.xs),
                  SizedBox(
                    height: 34,
                    child: Row(
                      children: [
                        for (final item in widget.delivery.order!.items.take(4))
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: AppColors.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: item.imageUrl != null
                                  ? AppNetworkImage(url: item.imageUrl, icon: Icons.fastfood_outlined)
                                  : const Icon(Icons.fastfood_outlined, size: 15, color: AppColors.textFaint),
                            ),
                          ),
                        if (widget.delivery.order!.items.length > 4)
                          Text(
                            '+${widget.delivery.order!.items.length - 4}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.orangeLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${widget.delivery.order!.itemCount} article${widget.delivery.order!.itemCount > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.orangeDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppDimens.sm),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.orangeLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.payments_outlined, size: 20, color: AppColors.orange),
                    ),
                    const SizedBox(width: 8),
                    AmountText(amount, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.onIncident,
                      child: Text(
                        'Signaler un incident',
                        style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: widget.onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orangeLight,
                      foregroundColor: AppColors.orangeDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
                    ),
                    child: Text(_actionLabel(widget.delivery.status)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _actionLabel(String status) => switch (status) {
        'assigned' => 'J\'ai récupéré la commande',
        'picked_up' => 'Démarrer la livraison',
        'in_delivery' => 'Livrer',
        _ => 'Voir la mission',
      };
}
