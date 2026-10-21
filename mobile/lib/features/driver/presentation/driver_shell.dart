import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../account/driver_account_screen.dart';
import '../history/driver_history_screen.dart';
import '../missions/driver_home_screen.dart';
import '../offers/offers_screen.dart';
import '../onboarding/driver_onboarding_screen.dart';
import '../parcels/parcels_tab_screen.dart';
import '../widgets/driver_bottom_bar.dart';
import '../widgets/driver_drawer.dart';

/// Espace Livreur (J160) : missions, offres, historique, compte.
///
/// Le premier onglet vérifie le statut d'onboarding livreur : si le profil
/// n'est pas `active`, un panneau d'inscription et d'envoi de documents est
/// affiché à la place des missions.
class DriverShell extends StatefulWidget {
  const DriverShell({
    super.key,
    required this.session,
    required this.marketplace,
    this.initialIndex = 0,
  });

  final SessionProvider session;
  final MarketplaceApi marketplace;

  /// Onglet affiché au démarrage (0 missions … 4 compte). Permet d'ouvrir une
  /// section précise via `/driver?tab=…`.
  final int initialIndex;

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
    _index = _clampIndex(widget.initialIndex);
    _loadStatus();
  }

  @override
  void didUpdateWidget(DriverShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() => _index = _clampIndex(widget.initialIndex));
    }
  }

  /// Borne l'onglet demandé à la plage gérée par le shell.
  static int _clampIndex(int index) => index.clamp(0, 4);

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

  /// Déconnexion depuis le tiroir latéral.
  Future<void> _logout() async {
    await widget.session.logout();
    if (mounted) {
      context.go('/landing');
    }
  }

  @override
  Widget build(BuildContext context) {
    void onOpenMenu() => _scaffoldKey.currentState?.openDrawer();
    final rawProfile = _status?['profile'];
    final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
    final rawStatus = profile?['status'];
    final palette = BadgePalette.driver(rawStatus is String ? rawStatus : null);
    final rawVehicle = profile == null ? null : profile['vehicle'];
    final vehicle = rawVehicle is String ? rawVehicle : null;

    return Scaffold(
      key: _scaffoldKey,
      drawer: DriverDrawer(
        session: widget.session,
        currentIndex: _index,
        onSelectTab: _onDestinationSelected,
        available: profile?['available'] == true,
        statusLabel: palette?.$1,
        statusColor: palette?.$2,
        vehicle: vehicle,
        onLogout: _logout,
      ),
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
      bottomNavigationBar: DriverBottomBar(
        activeIndex: _index,
        onSelect: _onDestinationSelected,
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
