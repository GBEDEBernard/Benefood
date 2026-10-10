import 'package:flutter/material.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/widgets/notification_bell.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../restaurant_palette.dart';
import '../widgets/status_chip.dart';

/// Tableau de bord vendeur (mobile) — « Le Délice Fast-Food ».
///
/// Fond gris clair, scrollable verticalement : stats, actions rapides,
/// nouvelles commandes et commandes récentes. Toutes les valeurs sont
/// fournies par l'appelant (données API).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.isOpen,
    required this.onOpenDrawer,
    required this.onToggleOpen,
    this.orderCount = 0,
    this.pendingCount = 0,
    this.revenueToday = 0,
    this.rating = '4,6',
    this.reviewCount = '128 avis',
    this.newOrders = const [],
    this.recentOrders = const [],
    this.onAccept,
    this.onRefuse,
    this.onAddProduct,
    this.onGoToShop,
    this.onOpenOrder,
    this.onOpenOrders,
    this.marketplace,
  });

  final bool isOpen;
  final VoidCallback onOpenDrawer;
  final ValueChanged<bool> onToggleOpen;
  final int orderCount;
  final int pendingCount;
  final int revenueToday;
  final String rating;
  final String reviewCount;
  final List<Order> newOrders;
  final List<Order> recentOrders;
  final ValueChanged<Order>? onAccept;
  final ValueChanged<Order>? onRefuse;
  final VoidCallback? onAddProduct;
  final VoidCallback? onGoToShop;

  /// Ouvre le détail d'une commande (depuis une carte du tableau de bord).
  final ValueChanged<Order>? onOpenOrder;

  /// Ouvre l'onglet complet « Commandes » du shell.
  final VoidCallback? onOpenOrders;
  final MarketplaceApi? marketplace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefreshOrNoop,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _buildTitleRow(),
                const SizedBox(height: 16),
                _buildStatsGrid(),
                const SizedBox(height: 24),
                const _SectionTitle(title: 'Actions rapides'),
                const SizedBox(height: 10),
                _QuickActions(
                  isOpen: isOpen,
                  onToggleOpen: onToggleOpen,
                  onAddProduct: onAddProduct,
                  onGoToShop: onGoToShop,
                  marketplace: marketplace,
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                  title: 'Nouvelles commandes',
                  trailing: _VoirTout(onPressed: onOpenOrders),
                ),
                const SizedBox(height: 10),
                if (newOrders.isEmpty)
                  const _EmptyHint('Aucune nouvelle commande pour le moment.')
                else
                  ...newOrders.map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _NewOrderCard(
                          order: o,
                          onAccept: () => onAccept?.call(o),
                          onRefuse: () => onRefuse?.call(o),
                          onTap: onOpenOrder == null ? null : () => onOpenOrder!(o),
                        ),
                      )),
                const SizedBox(height: 14),
                _SectionTitle(
                  title: 'Commandes récentes',
                  trailing: _VoirTout(onPressed: onOpenOrders),
                ),
                const SizedBox(height: 10),
                if (recentOrders.isEmpty)
                  const _EmptyHint('Aucune commande récente.')
                else
                  ...recentOrders.map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecentOrderCard(
                          order: o,
                          onTap: onOpenOrder == null ? null : () => onOpenOrder!(o),
                        ),
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> onRefreshOrNoop() async {}

  Widget _buildHeader(BuildContext context) {
    return Material(
      color: RestaurantPalette.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              IconButton(
                onPressed: onOpenDrawer,
                icon: const Icon(Icons.menu, color: RestaurantPalette.darkText, size: 26),
                tooltip: 'Ouvrir le menu',
              ),
              const Expanded(
                child: Center(child: _BeninfoodBrand()),
              ),
              if (marketplace != null)
                NotificationBell(api: marketplace!)
              else
                IconButton(
                  onPressed: () => toast(context, 'Notifications disponibles bientôt'),
                  icon: const Icon(Icons.notifications_none),
                  tooltip: 'Notifications',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Tableau de bord',
            style: TextStyle(
              color: RestaurantPalette.forest,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ),
        StatusChip(
          label: isOpen ? 'Ouvert' : 'Fermé',
          background: (isOpen ? RestaurantPalette.success : RestaurantPalette.danger).withValues(alpha: 0.15),
          foreground: isOpen ? RestaurantPalette.success : RestaurantPalette.danger,
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: RestaurantPalette.cardSpacing,
      crossAxisSpacing: RestaurantPalette.cardSpacing,
      mainAxisExtent: 96,
      children: [
        _StatCard(
          title: 'Commandes du jour',
          value: '$orderCount',
          footer: '$orderCount au total',
          footerColor: RestaurantPalette.grayText,
        ),
        _StatCard(
          title: 'En attente d’action',
          value: '$pendingCount',
          footer: '! À traiter',
          footerColor: pendingCount > 0 ? RestaurantPalette.danger : RestaurantPalette.grayText,
        ),
        _StatCard(
          title: 'CA du jour',
          value: formatAmount(revenueToday),
          footer: 'Montant encaissé',
          footerColor: RestaurantPalette.grayText,
        ),
        _StatCard(
          title: 'Note moyenne',
          value: '⭐ $rating',
          footer: reviewCount,
          footerColor: RestaurantPalette.grayText,
        ),
      ],
    );
  }

  static void toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: RestaurantPalette.darkText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _VoirTout extends StatelessWidget {
  const _VoirTout({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: RestaurantPalette.grayText,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      child: const Text('Voir tout', style: TextStyle(fontWeight: FontWeight.w500)),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: RestaurantPalette.cardDecoration,
      child: Text(
        label,
        style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 13),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.footer,
    required this.footerColor,
  });

  final String title;
  final String value;
  final String footer;
  final Color footerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: RestaurantPalette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: RestaurantPalette.grayText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: RestaurantPalette.darkText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            footer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: footerColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.isOpen,
    required this.onToggleOpen,
    this.onAddProduct,
    this.onGoToShop,
    this.marketplace,
  });

  final bool isOpen;
  final ValueChanged<bool> onToggleOpen;
  final VoidCallback? onAddProduct;
  final VoidCallback? onGoToShop;
  final MarketplaceApi? marketplace;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onAddProduct,
            style: _outlineStyle(),
            child: const _ActionLabel('Ajouter un produit'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: onGoToShop,
            style: _outlineStyle(),
            child: const _ActionLabel('Modifier la boutique'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: () => onToggleOpen(!isOpen),
            style: FilledButton.styleFrom(
              backgroundColor: RestaurantPalette.orange,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RestaurantPalette.radius)),
            ),
            child: _ActionLabel(isOpen ? 'Fermer' : 'Ouvrir'),
          ),
        ),
      ],
    );
  }

  ButtonStyle _outlineStyle() => OutlinedButton.styleFrom(
        foregroundColor: RestaurantPalette.darkText,
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        backgroundColor: RestaurantPalette.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RestaurantPalette.radius)),
      );
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    );
  }
}

/// Marque Béninfood affichée au centre de l'en-tête du tableau de bord :
/// logo image (assets/Logo.jpeg) arrondi + écriture bicolore.
class _BeninfoodBrand extends StatelessWidget {
  const _BeninfoodBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset(
            'assets/Logo.jpeg',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: AppColors.greenLight,
              child: Center(child: Icon(Icons.restaurant, size: 18, color: AppColors.green)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.clip,
          text: const TextSpan(
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              height: 1.1,
            ),
            children: [
              TextSpan(text: 'BÉN', style: TextStyle(color: AppColors.green)),
              TextSpan(text: 'INFOOD', style: TextStyle(color: AppColors.orange)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NewOrderCard extends StatelessWidget {
  const _NewOrderCard({required this.order, required this.onAccept, required this.onRefuse, this.onTap});

  final Order order;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _buildInner(),
        ),
      ),
    );
  }

  Widget _buildInner() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.reference,
                    style: const TextStyle(
                      color: RestaurantPalette.darkText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo(order.createdAt),
                    style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatAmount(order.total),
                  style: const TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                  style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: RestaurantPalette.success,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: onRefuse,
                style: FilledButton.styleFrom(
                  backgroundColor: RestaurantPalette.danger.withValues(alpha: 0.12),
                  foregroundColor: RestaurantPalette.danger,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Refuser', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: RestaurantPalette.orange,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Voir détails', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard({required this.order, this.onTap});

  final Order order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = BadgePalette.order(order.status);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: RestaurantPalette.cardDecoration,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _buildInner(palette),
        ),
      ),
    );
  }

  Widget _buildInner((String, Color)? palette) {
    return Row(
      children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.reference,
                  style: const TextStyle(
                    color: RestaurantPalette.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo(order.createdAt),
                  style: const TextStyle(color: RestaurantPalette.grayText, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            formatAmount(order.total),
            style: const TextStyle(
              color: RestaurantPalette.darkText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          if (palette != null)
            StatusBadge(label: palette.$1, color: palette.$2, small: true)
          else
            StatusChip(
              label: order.status,
              background: RestaurantPalette.grayText.withValues(alpha: 0.12),
              foreground: RestaurantPalette.grayText,
            ),
      ],
    );
  }
}

/// Libellé relatif (« il y a 5 min ») à partir d'un ISO 8601.
String timeAgo(String? iso) {
  if (iso == null || iso.isEmpty) {
    return '';
  }
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return '';
  }
  final diff = DateTime.now().difference(parsed.toLocal());
  if (diff.inMinutes < 1) {
    return "à l'instant";
  }
  if (diff.inMinutes < 60) {
    return 'il y a ${diff.inMinutes} min';
  }
  if (diff.inHours < 24) {
    return 'il y a ${diff.inHours} h';
  }
  return 'il y a ${diff.inDays} j';
}