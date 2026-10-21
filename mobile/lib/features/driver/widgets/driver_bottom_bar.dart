import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Barre de navigation du livreur (Missions, Offres, Colis, Historique,
/// Compte), dans le style de la barre du shell.
///
/// Partagée entre le shell et les pages secondaires (statistiques) : avec
/// [activeIndex] à `null`, aucun onglet n'est surligné et la barre reste
/// visuellement identique à celle du shell.
class DriverBottomBar extends StatelessWidget {
  const DriverBottomBar({
    super.key,
    required this.activeIndex,
    required this.onSelect,
  });

  /// Onglet actif, ou `null` depuis une page secondaire (aucun surligné).
  final int? activeIndex;

  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bar = NavigationBar(
      selectedIndex: activeIndex ?? 0,
      onDestinationSelected: onSelect,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.delivery_dining_outlined),
          selectedIcon: Icon(Icons.delivery_dining),
          label: 'Missions',
        ),
        NavigationDestination(
          icon: Icon(Icons.local_offer_outlined),
          selectedIcon: Icon(Icons.local_offer),
          label: 'Offres',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Colis',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: 'Historique',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Compte',
        ),
      ],
    );

    if (activeIndex != null) {
      return bar;
    }

    // Aucun onglet actif : on neutralise l'indicateur et les couleurs de
    // l'état « sélectionné » pour que la barre reste neutre.
    final theme = Theme.of(context);
    final navTheme = theme.navigationBarTheme;

    return Theme(
      data: theme.copyWith(
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: navTheme.backgroundColor,
          surfaceTintColor: navTheme.surfaceTintColor,
          elevation: navTheme.elevation,
          shadowColor: navTheme.shadowColor,
          height: navTheme.height,
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => const IconThemeData(
              size: 24,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
      child: bar,
    );
  }
}
