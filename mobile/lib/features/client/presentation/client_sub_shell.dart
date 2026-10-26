import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/theme/app_colors.dart';
import 'client_shell.dart';

/// Habillage commun des pages secondaires de l'espace client : conserve la
/// barre de navigation inférieure (panier, commandes, profil…) au-dessus de
/// la page courante, comme dans l'accueil.
class ClientSubShell extends StatefulWidget {
  const ClientSubShell({
    super.key,
    required this.marketplace,
    required this.child,
  });

  final MarketplaceApi marketplace;
  final Widget child;

  @override
  State<ClientSubShell> createState() => _ClientSubShellState();
}

class _ClientSubShellState extends State<ClientSubShell> {
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshCartCount();
  }

  Future<void> _refreshCartCount() async {
    try {
      final cart = await widget.marketplace.cart();
      if (mounted) {
        setState(() => _cartCount = cart.itemsCount);
      }
    } catch (_) {
      // Badge purement indicatif : une erreur réseau ne doit pas bloquer.
    }
  }

  void _selectTab(int index) {
    ClientNavigation.openTab(context, index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: widget.child,
      bottomNavigationBar: ClientBottomBar(
        cartCount: _cartCount,
        activeIndex: null,
        onSelect: _selectTab,
      ),
    );
  }
}
