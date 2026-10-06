import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/home_header.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Tableau de bord vendeur (J154) : boutique, statut, statistiques, commandes.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.marketplace,
    required this.onGoToTab,
    this.userName,
  });

  final MarketplaceApi marketplace;
  final ValueChanged<int> onGoToTab;
  final String? userName;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _status;
  List<Product> _products = [];
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;

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
      final status = await widget.marketplace.vendorStatus();
      final products = await widget.marketplace.vendorProducts();
      final orders = await widget.marketplace.vendorOrders(perPage: 50);
      if (mounted) {
        setState(() {
          _status = status;
          _products = products;
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

  int get _pendingOrders => _orders
      .where((o) => o.canVendorAccept || o.canVendorRefuse || o.canVendorPrepare || o.canVendorReady)
      .length;

  List<Order> get _recentOrders {
    final sorted = [..._orders];
    sorted.sort((a, b) {
      final aDate = DateTime.tryParse(a.createdAt ?? '') ;
      final bDate = DateTime.tryParse(b.createdAt ?? '');
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });
    return sorted.take(3).toList();
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
            subtitle: 'Chargement de votre boutique…',
            leading: const HomeBadgeIcon(icon: Icons.storefront_outlined),
          ),
          const SizedBox(height: 120),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final rawVendor = _status?['vendor'];
    final vendor = rawVendor is Map<String, dynamic> ? rawVendor : null;
    final status = _stringOrNull(vendor?['status']);
    final palette = BadgePalette.vendor(status);
    final businessName = _stringOrNull(vendor?['business_name']) ?? 'Ma boutique';
    final city = _stringOrNull(vendor?['city']);
    final phone = _stringOrNull(vendor?['phone']);
    final recent = _recentOrders;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppDimens.xl),
      children: [
        HomeHeader(
          title: greeting,
          subtitle: 'Votre boutique en un coup d’œil',
          leading: const HomeBadgeIcon(icon: Icons.storefront_outlined),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Carte héro : la boutique ---
              _ShopCard(
                businessName: businessName,
                city: city,
                phone: phone,
                badge: palette,
              ),
              const SizedBox(height: AppDimens.md),
              // --- Statistiques ---
              Row(
                children: [
                  Expanded(
                    child: HomeStatTile(
                      icon: Icons.shopping_bag_outlined,
                      value: '${_products.length}',
                      label: 'Produits',
                      accent: AppColors.orange,
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: HomeStatTile(
                      icon: Icons.schedule,
                      value: '$_pendingOrders',
                      label: 'En attente',
                      accent: AppColors.goldDark,
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: HomeStatTile(
                      icon: Icons.receipt_long_outlined,
                      value: '${_orders.length}',
                      label: 'Commandes',
                      accent: AppColors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Dernières commandes'),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimens.pagePadding, vertical: 8),
            child: Text(
              'Aucune commande pour le moment.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          )
        else
          ...recent.map((order) => _RecentOrderCard(
                order: order,
                onTap: () => widget.onGoToTab(2),
              )),
        const SizedBox(height: AppDimens.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                label: 'Gérer mes produits',
                icon: Icons.shopping_bag_outlined,
                onPressed: () => widget.onGoToTab(1),
              ),
              const SizedBox(height: AppDimens.md),
              AppButton(
                label: 'Voir toutes les commandes',
                icon: Icons.receipt_long_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => widget.onGoToTab(2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Carte héro premium : identité de la boutique + statut + contacts.
class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.businessName,
    required this.city,
    required this.phone,
    required this.badge,
  });

  final String businessName;
  final String? city;
  final String? phone;
  final (String, Color)? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.storefront_outlined, color: AppColors.green, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (badge != null) StatusBadge(label: badge!.$1, color: badge!.$2, small: true),
                  ],
                ),
              ),
            ],
          ),
          if ((city != null && city!.isNotEmpty) || (phone != null && phone!.isNotEmpty)) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                if (city != null && city!.isNotEmpty) ...[
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.green),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      city!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
                if (city != null && city!.isNotEmpty && phone != null && phone!.isNotEmpty)
                  const SizedBox(width: 16),
                if (phone != null && phone!.isNotEmpty) ...[
                  const Icon(Icons.phone_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      phone!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Carte compacte de commande récente.
class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = BadgePalette.order(order.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, 0, AppDimens.pagePadding, 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                      if (palette != null) ...[
                        const SizedBox(height: 3),
                        StatusBadge(label: palette.$1, color: palette.$2, small: true),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AmountText(
                  order.total,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20, color: AppColors.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _stringOrNull(dynamic value) => value is String ? value : null;
