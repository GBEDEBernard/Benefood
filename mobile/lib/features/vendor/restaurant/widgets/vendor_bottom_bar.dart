import 'package:flutter/material.dart';

import '../restaurant_palette.dart';

/// Barre d'actions rapides du shell vendeur, dans le même style que la barre
/// inférieure de l'espace client (blanc, ombre haute, icône + libellé,
/// actif orange, pastille de compte sur les commandes).
class VendorBottomBar extends StatelessWidget {
  const VendorBottomBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    this.pendingOrders = 0,
  });

  /// Index du shell correspondant à l'onglet actif (0 tableau de bord,
  /// 2 produits, 3 commandes, 4 revenus, 5 profil).
  final int currentIndex;

  final ValueChanged<int> onSelect;

  /// Nombre de commandes en attente affiché en pastille sur « Commandes ».
  final int pendingOrders;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RestaurantPalette.white,
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
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _BarItem(
                  icon: Icons.space_dashboard_outlined,
                  activeIcon: Icons.space_dashboard,
                  label: 'Tableau de bord',
                  active: currentIndex == 0,
                  onTap: () => onSelect(0),
                ),
              ),
              Expanded(
                child: _BarItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2,
                  label: 'Produits',
                  active: currentIndex == 2,
                  onTap: () => onSelect(2),
                ),
              ),
              Expanded(
                child: _BarItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Commandes',
                  active: currentIndex == 3,
                  badge: pendingOrders,
                  onTap: () => onSelect(3),
                ),
              ),
              Expanded(
                child: _BarItem(
                  icon: Icons.payments_outlined,
                  activeIcon: Icons.payments,
                  label: 'Revenus',
                  active: currentIndex == 4,
                  onTap: () => onSelect(4),
                ),
              ),
              Expanded(
                child: _BarItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profil',
                  active: currentIndex == 5,
                  onTap: () => onSelect(5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Élément de la barre : icône + libellé (orange si actif), pastille
/// optionnelle de compteur au-dessus de l'icône.
class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = active ? RestaurantPalette.orange : RestaurantPalette.grayText;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(active ? activeIcon : icon, size: 23, color: color),
                if (badge > 0)
                  Positioned(
                    top: -7,
                    right: -11,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: RestaurantPalette.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: RestaurantPalette.white, width: 2),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          color: RestaurantPalette.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 26,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
