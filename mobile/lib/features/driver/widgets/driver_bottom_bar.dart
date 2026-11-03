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
    final hasSelection = activeIndex != null;
    final theme = Theme.of(context);
    final navTheme = theme.navigationBarTheme;

    return Theme(
      data: theme.copyWith(
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: navTheme.elevation,
          shadowColor: navTheme.shadowColor,
          height: navTheme.height,
          indicatorColor:
              hasSelection ? AppColors.orangeMist : Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11.5,
              fontWeight: states.contains(WidgetState.selected) && hasSelection
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected) && hasSelection
                  ? AppColors.orangeVivid
                  : AppColors.neutralTextSecondary,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: states.contains(WidgetState.selected) && hasSelection
                  ? 25
                  : 23,
              color: states.contains(WidgetState.selected) && hasSelection
                  ? AppColors.orangeVivid
                  : AppColors.neutralTextSecondary,
            ),
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: activeIndex ?? 0,
        onDestinationSelected: onSelect,
        animationDuration: const Duration(milliseconds: 280),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.delivery_dining_outlined),
            selectedIcon: Icon(Icons.delivery_dining_rounded),
            label: 'Missions',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer_rounded),
            label: 'Offres',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Colis',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Historique',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Compte',
          ),
        ],
      ),
    );
  }
}
