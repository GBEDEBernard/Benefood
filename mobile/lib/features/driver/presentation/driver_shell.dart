import 'package:flutter/material.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../account/driver_account_screen.dart';
import '../history/driver_history_screen.dart';
import '../missions/driver_home_screen.dart';
import '../offers/offers_screen.dart';
import '../onboarding/driver_onboarding_screen.dart';
import '../parcels/parcels_tab_screen.dart';

/// Espace Livreur (J160) : missions, offres, historique, compte.
///
/// Le premier onglet vérifie le statut d'onboarding livreur : si le profil
/// n'est pas `active`, un panneau d'inscription et d'envoi de documents est
/// affiché à la place des missions.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key, required this.session, required this.marketplace});

  final SessionProvider session;
  final MarketplaceApi marketplace;

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;
  final _missionsKey = GlobalKey<DriverHomeScreenState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? _status;
  bool _statusLoading = true;
  String? _statusError;

  /// Comme pour l'onboarding client : le spinner de statut ne s'affiche qu'à
  /// la première vérification. Les rafraîchissements (inscription, uploads de
  /// documents) gardent le parcours livreur monté sur sa page courante.
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (!_loadedOnce) {
      setState(() {
        _statusLoading = true;
        _statusError = null;
      });
    }
    try {
      final status = await widget.marketplace.driverStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _statusLoading = false;
          _loadedOnce = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.isNotFound) {
          // Aucun profil livreur : l'utilisateur doit s'inscrire.
          setState(() {
            _status = null;
            _statusError = null;
            _statusLoading = false;
            _loadedOnce = true;
          });
        } else {
          setState(() {
            _statusError = e.message;
            _statusLoading = false;
            _loadedOnce = true;
          });
        }
      }
    }
  }

  void _onDestinationSelected(int index) {
    setState(() => _index = index);
    // Rafraîchir les missions quand on revient sur l'onglet.
    if (index == 0) {
      _missionsKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    void onOpenMenu() => _scaffoldKey.currentState?.openDrawer();
    return Scaffold(
      key: _scaffoldKey,
      drawer: _DriverDrawer(session: widget.session, onSelectTab: _onDestinationSelected),
      body: IndexedStack(
        index: _index,
        children: [
          _buildFirstTab(onOpenMenu),
          OffersScreen(
            marketplace: widget.marketplace,
            onOfferAccepted: () => _missionsKey.currentState?.refresh(),
            onOpenMenu: onOpenMenu,
          ),
          DriverParcelsScreen(
            marketplace: widget.marketplace,
            onOfferAccepted: () => _missionsKey.currentState?.refresh(),
            onOpenMenu: onOpenMenu,
          ),
          DriverHistoryScreen(
            marketplace: widget.marketplace,
            onOpenMenu: onOpenMenu,
          ),
          DriverAccountScreen(
            session: widget.session,
            marketplace: widget.marketplace,
            onOpenMenu: onOpenMenu,
            onSelectTab: _onDestinationSelected,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), selectedIcon: Icon(Icons.delivery_dining), label: 'Missions'),
          NavigationDestination(icon: Icon(Icons.local_offer_outlined), selectedIcon: Icon(Icons.local_offer), label: 'Offres'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Colis'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Historique'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Compte'),
        ],
      ),
    );
  }

  Widget _buildFirstTab(VoidCallback onOpenMenu) {
    if (_statusLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_statusError != null) {
      return ErrorState(message: _statusError!, onRetry: _loadStatus);
    }

    final rawProfile = _status?['profile'];
    final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
    final rawDocuments = _status?['documents'];
    final documents = rawDocuments is List
        ? rawDocuments.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    if (profile?['status'] == 'active') {
      return DriverHomeScreen(
        key: _missionsKey,
        marketplace: widget.marketplace,
        visible: _index == 0,
        userName: widget.session.user?.name,
        onOpenMenu: onOpenMenu,
      );
    }

    return DriverOnboardingScreen(
      marketplace: widget.marketplace,
      profile: profile,
      documents: documents,
      onRefresh: _loadStatus,
      onOpenMenu: onOpenMenu,
    );
  }
}

/// Tiroir latéral du livreur : identité + navigation vers les onglets.
class _DriverDrawer extends StatelessWidget {
  const _DriverDrawer({required this.session, required this.onSelectTab});

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
                  _DrawerNavTile(
                    icon: Icons.delivery_dining_outlined,
                    label: 'Mes missions',
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelectTab(0);
                    },
                  ),
                  _DrawerNavTile(
                    icon: Icons.local_offer_outlined,
                    label: 'Offres disponibles',
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelectTab(1);
                    },
                  ),
                  _DrawerNavTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Mes colis',
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelectTab(2);
                    },
                  ),
                  _DrawerNavTile(
                    icon: Icons.history_outlined,
                    label: 'Historique',
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelectTab(3);
                    },
                  ),
                  _DrawerNavTile(
                    icon: Icons.person_outline,
                    label: 'Mon compte',
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelectTab(4);
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

/// Ligne de navigation du tiroir livreur.
class _DrawerNavTile extends StatelessWidget {
  const _DrawerNavTile({
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
