import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../restaurant_palette.dart';

/// Barre inférieure de l'espace vendeur : cinq accès, avec la boutique
/// surélevée au centre (bouton orange), le portefeuille actif en orange et
/// une pastille de commandes en attente.
///
/// Les index correspondent au shell vendeur : 0 tableau de bord, 1 boutique,
/// 3 commandes, 4 portefeuille, 8 profil.
class VendorBottomBar extends StatelessWidget {
  const VendorBottomBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    this.pendingOrders = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// Nombre de commandes en attente affiché en pastille sur « Commandes ».
  final int pendingOrders;

  static const int _boutiqueIndex = 1;

  void _tap(int index) {
    HapticFeedback.selectionClick();
    onSelect(index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RestaurantPalette.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF18231F).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 100,
                    child: _BarItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Accueil',
                      active: currentIndex == 0,
                      onTap: () => _tap(0),
                    ),
                  ),
                  Expanded(
                    flex: 110,
                    child: _BarItem(
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long_rounded,
                      label: 'Commandes',
                      active: currentIndex == 3,
                      badge: pendingOrders,
                      onTap: () => _tap(3),
                    ),
                  ),
                  // Emplacement du bouton central surélevé.
                  const Expanded(flex: 75, child: SizedBox()),
                  Expanded(
                    flex: 130,
                    child: _BarItem(
                      icon: Icons.account_balance_wallet_outlined,
                      activeIcon: Icons.account_balance_wallet_rounded,
                      label: 'Portefeuille',
                      active: currentIndex == 4,
                      onTap: () => _tap(4),
                    ),
                  ),
                  Expanded(
                    flex: 85,
                    child: _BarItem(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profil',
                      active: currentIndex == 8,
                      onTap: () => _tap(8),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: -22,
                left: 0,
                right: 0,
                child: Center(
                  child: _BoutiqueButton(
                    active: currentIndex == _boutiqueIndex,
                    onTap: () => _tap(_boutiqueIndex),
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

/// Bouton central surélevé « Boutique » : cercle orange cerclé de blanc,
/// halo qui s'intensifie quand l'onglet est actif.
class _BoutiqueButton extends StatelessWidget {
  const _BoutiqueButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: active ? 1.05 : 1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF8A3D), RestaurantPalette.orange],
                ),
                border: Border.all(color: RestaurantPalette.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: RestaurantPalette.orange
                        .withValues(alpha: active ? 0.48 : 0.28),
                    blurRadius: active ? 20 : 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  active ? Icons.storefront_rounded : Icons.storefront_outlined,
                  key: ValueKey(active),
                  size: 26,
                  color: RestaurantPalette.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 1),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? RestaurantPalette.orange : RestaurantPalette.grayText,
              height: 1.1,
            ),
            child: const Text('Boutique'),
          ),
        ],
      ),
    );
  }
}

/// Élément de la barre : pastille active animée, icône qui bascule et
/// libellé coloré. La pastille de compteur apparaît au-dessus de l'icône.
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
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: SizedBox(
        height: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 30,
              width: 44,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedScale(
                    scale: active ? 1 : 0.6,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: active ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Container(
                        width: 36,
                        height: 28,
                        decoration: BoxDecoration(
                          color: RestaurantPalette.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      active ? activeIcon : icon,
                      key: ValueKey(active),
                      size: 22,
                      color: color,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 17, minHeight: 17),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: RestaurantPalette.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: RestaurantPalette.white,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: RestaurantPalette.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 10.5,
                height: 1.1,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
