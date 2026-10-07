import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/call_button.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/state_widgets.dart';
import 'order_tracking_screen.dart';

/// Mes commandes (J152) — suivi et historique : en-tête brandé, onglets de
/// filtre, cartes par statut avec barre de progression et actions.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;

  /// 0 = Toutes, 1 = En cours, 2 = Terminées, 3 = Annulées.
  int _tab = 0;

  /// Statuts non terminaux (filtre « En cours »).
  static const _activeStatuses = {
    'awaiting_payment',
    'paid',
    'accepted',
    'preparing',
    'ready',
    'assigned',
    'picked_up',
    'in_delivery',
    'out_for_delivery',
  };

  static const _tabLabels = ['Toutes', 'En cours', 'Terminées', 'Annulées'];
  static const _tabIcons = [
    Icons.format_list_bulleted,
    Icons.delivery_dining,
    Icons.check_circle_outline,
    Icons.cancel_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await widget.marketplace.orders(perPage: 50);
      if (mounted) {
        setState(() {
          _orders = orders;
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

  List<Order> get _visible {
    switch (_tab) {
      case 1:
        return _orders
            .where((o) => _activeStatuses.contains(o.status))
            .toList();
      case 2:
        return _orders.where((o) => o.status == 'delivered').toList();
      case 3:
        return _orders
            .where((o) => o.status == 'cancelled' || o.status == 'refunded')
            .toList();
      default:
        return _orders;
    }
  }

  void _openDetails(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OrderTrackingScreen(
          marketplace: widget.marketplace,
          orderId: order.id,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- divers

  void _showRatingSheet(Order order) {
    var stars = 5;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Noter votre commande',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.vendor?.businessName ??
                          'Commande #${order.reference}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          GestureDetector(
                            onTap: () => setSheetState(() => stars = i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Icon(
                                i <= stars
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 38,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (mounted) {
                            showToast(context, 'Merci pour votre avis !');
                          }
                        },
                        child: const Text(
                          'Envoyer mon avis',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final visible = _loading || _error != null ? <Order>[] : _visible;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildTitle(),
            _buildTabs(),
            Expanded(child: _buildList(visible)),
          ],
        ),
      ),
    );
  }

  /// En-tête blanc : logo central + cloche avec pastille « 2 ».
  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 44),
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/Logo.jpeg',
                height: 44,
                fit: BoxFit.contain,
              ),
            ),
          ),
          NotificationBell(api: widget.marketplace),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        20,
        AppDimens.pagePadding,
        16,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Mes commandes',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  /// 4 onglets uniformes : actif = orange + soulignement orange épais.
  Widget _buildTabs() {
    return Container(
      color: AppColors.surface,
      child: Row(
        children: [
          for (var i = 0; i < _tabLabels.length; i++)
            Expanded(
              child: _StatusTab(
                icon: _tabIcons[i],
                label: _tabLabels[i],
                active: _tab == i,
                onTap: () => setState(() => _tab = i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<Order> visible) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 24),
          Center(child: CircularProgressIndicator(color: AppColors.orange)),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [ErrorState(message: _error!, onRetry: _load)],
      );
    }
    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Aucune commande',
            subtitle: 'Vos commandes apparaîtront ici.',
            actionLabel: 'Explorer',
            onAction: () => context.go('/client/search'),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          4,
          AppDimens.pagePadding,
          AppDimens.xl,
        ),
        children: [
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Aucune commande dans cet onglet.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            for (final order in visible) ...[
              _OrderCard(
                order: order,
                onTap: () => _openDetails(order),
                onContact: () async {
                  final ok = await launchPhoneCall(
                    order.delivery?.driver?.phone,
                  );
                  if (!ok && mounted) {
                    showToast(
                      context,
                      'Numéro de téléphone indisponible.',
                      isError: true,
                    );
                  }
                },
                onRate: () => _showRatingSheet(order),
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------- header

/// Onglet de filtre : icône + libellé, soulignement orange si actif.
class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.orange : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.orange : AppColors.border,
              width: active ? 3 : 1,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------- cards

/// Carte de commande : photo ronde, infos, badge ID, prix, progression,
/// actions adaptées au statut.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTap,
    required this.onContact,
    required this.onRate,
  });

  final Order order;
  final VoidCallback onTap;
  final VoidCallback onContact;
  final VoidCallback onRate;

  bool get _isActive =>
      _OrdersScreenState._activeStatuses.contains(order.status);
  bool get _isDelivered => order.status == 'delivered';
  bool get _isCancelled =>
      order.status == 'cancelled' || order.status == 'refunded';

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusSubtitle) = _statusInfo();

    // Photo : plat d'abord, sinon logo de la boutique, sinon icône.
    final photoUrl =
        (order.items.isNotEmpty ? order.items.first.imageUrl : null) ??
        order.vendor?.logoUrl;
    final photoFallback = order.items.isNotEmpty
        ? Icons.fastfood_outlined
        : Icons.storefront;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.softShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo ronde du plat / de la boutique.
                  ClipOval(
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: AppNetworkImage(
                        url: photoUrl,
                        icon: photoFallback,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Colonnes centrales : nom, adresse, date, statut.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.vendor?.businessName ??
                              'Commande #${order.reference}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        if (order.deliveryAddress != null &&
                            order.deliveryAddress!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            order.deliveryAddress!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '${_frFullDate(order.createdAt)} • ${_frTime(order.createdAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                            if (statusSubtitle.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  statusSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Colonne droite : badge ID + prix.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _badgeId,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _badgeFg,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatAmount(order.total),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_isActive) ...[
                _OrderProgress(order: order),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _OutlineAction(
                        label: 'Voir détails',
                        color: AppColors.green,
                        onTap: onTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onContact,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.call, size: 16),
                        label: const Text(
                          'Contacter le livreur',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_isDelivered) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: onRate,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.greenLight,
                      foregroundColor: AppColors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Noter votre commande',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ] else if (_isCancelled) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: _OutlineAction(
                    label: 'Voir détails',
                    color: AppColors.red,
                    height: 46,
                    onTap: onTap,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Badge ID : jaune (en cours), vert (terminée), rouge (annulée).
  String get _badgeId {
    final last = order.reference.split('-').last.toUpperCase();
    return '#$last';
  }

  Color get _badgeBg {
    if (_isActive) {
      return AppColors.goldLight;
    }
    if (_isDelivered) {
      return AppColors.greenLight;
    }
    return AppColors.redLight;
  }

  Color get _badgeFg {
    if (_isActive) {
      return AppColors.goldDark;
    }
    if (_isDelivered) {
      return AppColors.green;
    }
    return AppColors.red;
  }

  (String, Color, String) _statusInfo() {
    switch (order.status) {
      case 'awaiting_payment':
        return ('À payer', AppColors.goldDark, 'Paiement en attente');
      case 'paid':
      case 'accepted':
        return ('En cours', AppColors.green, 'Commande confirmée');
      case 'preparing':
        return ('En cours', AppColors.green, 'Préparation en cours');
      case 'ready':
        return ('En cours', AppColors.green, 'Prête à partir');
      case 'assigned':
        return ('En cours', AppColors.green, 'Livreur assigné');
      case 'picked_up':
        return ('En cours', AppColors.green, 'Colis récupéré');
      case 'in_delivery':
      case 'out_for_delivery':
        return ('En cours', AppColors.green, 'Livraison en cours');
      case 'delivered':
        return (
          'Terminée',
          AppColors.green,
          'Livrée le ${_frDayMonth(order.updatedAt ?? order.createdAt)}'
              ' à ${_frTime(order.updatedAt ?? order.createdAt)}',
        );
      case 'cancelled':
        return (
          'Annulée',
          AppColors.red,
          (order.cancellationReason?.isNotEmpty ?? false)
              ? order.cancellationReason!
              : 'Commande annulée',
        );
      case 'refunded':
        return ('Annulée', AppColors.red, 'Commande remboursée');
      default:
        return (order.status.replaceAll('_', ' '), AppColors.textSecondary, '');
    }
  }
}

/// Barre de progression (commandes en cours) : 3 étapes reliées.
class _OrderProgress extends StatelessWidget {
  const _OrderProgress({required this.order});

  final Order order;

  static const _labels = ['Confirmée', 'En livraison', 'Livrée'];

  /// Étape active : 0 avant assignation, 1 une fois le livreur engagé.
  int get _activeIndex {
    switch (order.status) {
      case 'assigned':
      case 'picked_up':
      case 'in_delivery':
      case 'out_for_delivery':
        return 1;
      default:
        return 0;
    }
  }

  bool _done(int index) {
    switch (index) {
      case 0:
        return order.status != 'awaiting_payment' && order.status != 'draft';
      case 1:
        return const {
          'picked_up',
          'in_delivery',
          'out_for_delivery',
          'delivered',
        }.contains(order.status);
      default:
        return order.status == 'delivered';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Expanded(
            child: _ProgressStep(
              icon: _done(0) ? Icons.check_circle : Icons.check_circle_outline,
              label: _labels[0],
              done: _done(0),
              active: _activeIndex == 0,
            ),
          ),
          _ProgressLink(done: _done(1)),
          Expanded(
            child: _ProgressStep(
              icon: Icons.delivery_dining,
              label: _labels[1],
              done: _done(1),
              active: _activeIndex == 1,
            ),
          ),
          _ProgressLink(done: _done(2)),
          Expanded(
            child: _ProgressStep(
              icon: Icons.home,
              label: _labels[2],
              done: _done(2),
              active: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.icon,
    required this.label,
    required this.done,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.green
        : active
        ? AppColors.orange
        : AppColors.textFaint;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Ligne reliant deux étapes : verte si l'étape suivante est atteinte.
class _ProgressLink extends StatelessWidget {
  const _ProgressLink({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: 26,
        height: 3,
        decoration: BoxDecoration(
          color: done ? AppColors.green : AppColors.borderStrong,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Bouton contour arrondi (« Voir détails »).
class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.height = 46,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.4),
          minimumSize: Size(0, height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ dates FR

const _months = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

DateTime? _parse(String? iso) {
  if (iso == null || iso.isEmpty) {
    return null;
  }
  return DateTime.tryParse(iso)?.toLocal();
}

/// « 04 Mai 2025 »
String _frFullDate(String? iso) {
  final date = _parse(iso);
  if (date == null) {
    return '—';
  }
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${_months[date.month - 1]} ${date.year}';
}

/// « 02 Mai »
String _frDayMonth(String? iso) {
  final date = _parse(iso);
  if (date == null) {
    return '—';
  }
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${_months[date.month - 1]}';
}

/// « 12:30 »
String _frTime(String? iso) {
  final date = _parse(iso);
  if (date == null) {
    return '--:--';
  }
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
