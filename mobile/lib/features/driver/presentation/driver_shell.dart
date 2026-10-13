import 'package:flutter/material.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
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
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _buildFirstTab(),
          OffersScreen(
            marketplace: widget.marketplace,
            onOfferAccepted: () => _missionsKey.currentState?.refresh(),
          ),
          DriverParcelsScreen(
            marketplace: widget.marketplace,
            onOfferAccepted: () => _missionsKey.currentState?.refresh(),
          ),
          DriverHistoryScreen(marketplace: widget.marketplace),
          DriverAccountScreen(
            session: widget.session,
            marketplace: widget.marketplace,
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

  Widget _buildFirstTab() {
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
      );
    }

    return DriverOnboardingScreen(
      marketplace: widget.marketplace,
      profile: profile,
      documents: documents,
      onRefresh: _loadStatus,
    );
  }
}
