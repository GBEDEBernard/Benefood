import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../account/account_screen.dart';
import '../cart/cart_screen.dart';
import '../categories/categories_screen.dart';
import '../home/home_screen.dart';
import '../orders/orders_screen.dart';

/// Espace Client (J148+) : accueil, catégories, panier, commandes, profil.
///
/// Barre de navigation inférieure sur mesure avec bouton panier flottant,
/// plus un tiroir latéral ouvert depuis le menu hamburger de l'accueil.
class ClientShell extends StatefulWidget {
  const ClientShell({
    super.key,
    required this.session,
    required this.marketplace,
  });

  final SessionProvider session;
  final MarketplaceApi marketplace;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;
  int _cartCount = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _refreshCartCount();
  }

  /// Nombre d'articles du panier (badge du bouton flottant).
  Future<void> _refreshCartCount() async {
    try {
      final cart = await widget.marketplace.cart();
      if (!mounted) {
        return;
      }
      setState(() => _cartCount = cart.itemsCount);
    } catch (_) {
      // Badge purement indicatif : une erreur réseau ne doit pas bloquer.
    }
  }

  void _selectTab(int index) {
    if (_index == index) {
      return;
    }
    setState(() => _index = index);
    _refreshCartCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _ClientDrawer(session: widget.session, onSelectTab: _selectTab),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            marketplace: widget.marketplace,
            session: widget.session,
            onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onCartChanged: _refreshCartCount,
          ),
          CategoriesScreen(marketplace: widget.marketplace),
          CartScreen(marketplace: widget.marketplace),
          OrdersScreen(marketplace: widget.marketplace),
          AccountScreen(session: widget.session),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// Barre blanche + bouton panier circulaire surélevé (badge rouge).
  Widget _buildBottomBar() {
    return SizedBox(
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 64,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F18231F),
                    blurRadius: 14,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        label: 'Accueil',
                        active: _index == 0,
                        onTap: () => _selectTab(0),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.grid_view_outlined,
                        activeIcon: Icons.grid_view,
                        label: 'Catégories',
                        active: _index == 1,
                        onTap: () => _selectTab(1),
                      ),
                    ),
                    const SizedBox(width: 76),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.shopping_bag_outlined,
                        activeIcon: Icons.shopping_bag,
                        label: 'Commandes',
                        active: _index == 3,
                        onTap: () => _selectTab(3),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: 'Profil',
                        active: _index == 4,
                        onTap: () => _selectTab(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _CartButton(count: _cartCount, onTap: () => _selectTab(2)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Élément de la barre inférieure : icône + libellé (orange si actif).
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.orange : AppColors.text;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, size: 23, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton panier flottant : cercle orange surélevé, icône blanche,
/// pastille rouge avec le nombre d'articles.
class _CartButton extends StatelessWidget {
  const _CartButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.orange,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 4),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.shopping_cart,
                color: AppColors.surface,
                size: 26,
              ),
              if (count > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.surface,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        height: 1,
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

/// Tiroir latéral ouvert par le hamburger de l'accueil.
class _ClientDrawer extends StatelessWidget {
  const _ClientDrawer({required this.session, required this.onSelectTab});

  final SessionProvider session;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final user = session.user;
    final name = (user?.name ?? '').trim();
    final detail = (user?.email?.isNotEmpty ?? false)
        ? user!.email!
        : (user?.phone ?? '');

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/Logo.jpeg',
                    height: 44,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const BrandMark(iconSize: 26, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  if (name.isNotEmpty)
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerTile(
                    icon: Icons.person_outline,
                    label: 'Mon compte',
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelectTab(4);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Mes commandes',
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelectTab(3);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Mon panier',
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelectTab(2);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.location_on_outlined,
                    label: 'Mes adresses',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/client/addresses');
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.support_agent,
                    label: 'Mes réclamations',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/client/complaints');
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(AppDimens.pagePadding),
              child: Text(
                'Béninfood • Le goût du Bénin, livré chez vous',
                style: TextStyle(fontSize: 12, color: AppColors.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne de menu du tiroir latéral.
class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.orangeLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: AppColors.orange),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}
