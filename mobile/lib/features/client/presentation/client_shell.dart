import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../account/account_screen.dart';
import '../cart/cart_screen.dart';
import '../categories/categories_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/client_onboarding_screen.dart';
import '../orders/orders_screen.dart';
import '../widgets/client_drawer.dart';

/// Passerelle de navigation vers les onglets de l'espace client depuis une
/// page secondaire (produit, boutique, recherche…). Une page demandant un
/// onglet y dépose son index puis revient sur `/client`.
class ClientNavigation {
  ClientNavigation._();

  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  static void openTab(BuildContext context, int index) {
    requestedTab.value = index;
    context.go('/client');
  }
}

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
  int _cartVersion = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _statusLoading = true;
  bool _needsOnboarding = false;

  /// Statut du dossier client (carte d'identité du tiroir latéral).
  Map<String, dynamic>? _status;

  /// Indicateur : ne montre le spinner de chargement du statut qu'à la
  /// toute première vérification. Les rafraîchissements suivants (uploads de
  /// documents…) gardent l'onboarding monté afin de ne pas réinitialiser le
  /// parcours vers la page de bienvenue.
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    final requested = ClientNavigation.requestedTab.value;
    if (requested != null) {
      _index = requested;
      ClientNavigation.requestedTab.value = null;
    }
    ClientNavigation.requestedTab.addListener(_onRequestedTab);
    _refreshCartCount();
    _loadStatus();
  }

  @override
  void dispose() {
    ClientNavigation.requestedTab.removeListener(_onRequestedTab);
    super.dispose();
  }

  void _onRequestedTab() {
    final requested = ClientNavigation.requestedTab.value;
    if (requested == null || !mounted) {
      return;
    }
    ClientNavigation.requestedTab.value = null;
    _selectTab(requested);
  }

  /// Vérifie l'activation du compte client : tant que le dossier
  /// d'identification n'est pas complété, l'onboarding s'affiche à la place
  /// de l'espace client (J19).
  Future<void> _loadStatus() async {
    if (mounted && !_loadedOnce) {
      setState(() => _statusLoading = true);
    }
    try {
      final status = await widget.marketplace.clientStatus();
      if (!mounted) {
        return;
      }
      final profile = status['profile'];
      final active = profile is Map<String, dynamic> && profile['status'] == 'active';
      setState(() {
        _status = status;
        _needsOnboarding = !active;
        _statusLoading = false;
        _loadedOnce = true;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _needsOnboarding = e.isNotFound || e.code == 'client.not_onboarded';
        _statusLoading = false;
        _loadedOnce = true;
      });
    }
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
    setState(() {
      _index = index;
      if (index == 2) {
        _cartVersion++;
      }
    });
    _refreshCartCount();
  }

  /// Déconnexion depuis le tiroir latéral.
  Future<void> _logout() async {
    await widget.session.logout();
    if (mounted) {
      context.go('/landing');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_statusLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_needsOnboarding) {
      return ClientOnboardingScreen(
        marketplace: widget.marketplace,
        user: widget.session.user,
        onCompleted: _loadStatus,
      );
    }

    final rawProfile = _status?['profile'];
    final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
    final rawStatus = profile?['status'];
    final palette = ClientDrawer.statusPalette(
      rawStatus is String ? rawStatus : null,
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: ClientDrawer(
        session: widget.session,
        currentIndex: _index,
        onSelectTab: _selectTab,
        cartCount: _cartCount,
        statusLabel: palette.$1,
        statusColor: palette.$2,
        onLogout: _logout,
      ),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            marketplace: widget.marketplace,
            session: widget.session,
            onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onCartChanged: _refreshCartCount,
          ),
          CategoriesScreen(
            marketplace: widget.marketplace,
            onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          CartScreen(
            key: ValueKey('cart-$_cartVersion'),
            marketplace: widget.marketplace,
            onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          OrdersScreen(
            marketplace: widget.marketplace,
            onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          AccountScreen(
            session: widget.session,
            marketplace: widget.marketplace,
            onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onSelectTab: _selectTab,
          ),
        ],
      ),
      bottomNavigationBar: ClientBottomBar(
        cartCount: _cartCount,
        activeIndex: _index,
        onSelect: _selectTab,
      ),
    );
  }
}

/// Barre blanche + bouton panier circulaire surélevé (badge rouge).
///
/// Partagée entre l'accueil (onglets) et les pages secondaires afin que les
/// accès panier / commandes restent visibles partout dans l'espace client.
class ClientBottomBar extends StatelessWidget {
  const ClientBottomBar({
    super.key,
    required this.cartCount,
    required this.activeIndex,
    required this.onSelect,
  });

  final int cartCount;

  /// Onglet actif, ou `null` depuis une page secondaire (aucun surligné).
  final int? activeIndex;

  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
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
                        active: activeIndex == 0,
                        onTap: () => onSelect(0),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.grid_view_outlined,
                        activeIcon: Icons.grid_view,
                        label: 'Catégories',
                        active: activeIndex == 1,
                        onTap: () => onSelect(1),
                      ),
                    ),
                    const SizedBox(width: 76),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.shopping_bag_outlined,
                        activeIcon: Icons.shopping_bag,
                        label: 'Commandes',
                        active: activeIndex == 3,
                        onTap: () => onSelect(3),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: 'Profil',
                        active: activeIndex == 4,
                        onTap: () => onSelect(4),
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
              child: _CartButton(count: cartCount, onTap: () => onSelect(2)),
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
