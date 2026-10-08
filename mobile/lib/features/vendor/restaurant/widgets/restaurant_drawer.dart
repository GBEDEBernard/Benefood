import 'package:flutter/material.dart';

import '../restaurant_palette.dart';
import 'status_chip.dart';

/// Menu latéral rétractable « Le Délice Fast-Food ».
///
/// S'ouvre par-dessus l'écran principal. Fond vert forêt, élément actif
/// surligné en blanc avec des accents orange.
class RestaurantDrawer extends StatelessWidget {
  const RestaurantDrawer({
    super.key,
    required this.currentIndex,
    required this.isOpen,
    required this.onSelect,
    this.businessName = 'Le Délice Fast-Food',
    this.logoUrl,
  });

  /// Index de l'élément sélectionné dans [_items].
  final int currentIndex;

  /// État d'ouverture de la boutique (« Ouvert » / « Fermé »).
  final bool isOpen;

  /// Nom de la boutique affiché dans l'en-tête.
  final String businessName;

  /// Logo de la boutique affiché dans l'en-tête du menu.
  final String? logoUrl;

  /// Appelé quand l'utilisateur sélectionne un élément du menu.
  final ValueChanged<int> onSelect;

  static const List<_DrawerItem> _items = [
    _DrawerItem(
      label: 'Tableau de bord',
      outline: Icons.dashboard_outlined,
      filled: Icons.dashboard,
    ),
    _DrawerItem(
      label: 'Boutique',
      outline: Icons.storefront_outlined,
      filled: Icons.storefront,
    ),
    _DrawerItem(
      label: 'Produits',
      outline: Icons.inventory_2_outlined,
      filled: Icons.inventory_2,
    ),
    _DrawerItem(
      label: 'Commandes',
      outline: Icons.receipt_long_outlined,
      filled: Icons.receipt_long,
    ),
    _DrawerItem(
      label: 'Revenus',
      outline: Icons.bar_chart_outlined,
      filled: Icons.bar_chart,
    ),
    _DrawerItem(
      label: 'Profil & Paramètres',
      outline: Icons.person_outline,
      filled: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.75,
      backgroundColor: RestaurantPalette.forest,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Divider(color: Color(0x22FFFFFF), height: 1),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) => _buildItem(context, index, _items[index]),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Divider(color: Color(0x22FFFFFF), height: 1),
            ),
            _buildLogout(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          _ShopLogo(url: logoUrl, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              businessName.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.19,
              ),
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(
            label: isOpen ? 'Ouvert' : 'Fermé',
            background: (isOpen ? RestaurantPalette.success : RestaurantPalette.danger).withValues(alpha: 0.2),
            foreground: isOpen ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, _DrawerItem item) {
    final bool active = index == currentIndex;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(RestaurantPalette.radius),
        onTap: () => onSelect(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: active ? RestaurantPalette.white : Colors.transparent,
            borderRadius: BorderRadius.circular(RestaurantPalette.radius),
          ),
          child: Row(
            children: [
              Icon(
                active ? item.filled : item.outline,
                size: 22,
                color: active ? RestaurantPalette.orange : Colors.white,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? RestaurantPalette.orange : Colors.white,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(RestaurantPalette.radius),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Déconnexion…')),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.logout, size: 22, color: RestaurantPalette.danger),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Déconnexion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo de la boutique (rond blanc avec image réseau ou repli orange).
class _ShopLogo extends StatelessWidget {
  const _ShopLogo({required this.size, this.url});

  final double size;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final bool hasUrl = url != null && url!.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: ClipOval(
        child: hasUrl
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ShopLogoFallback(),
              )
            : const _ShopLogoFallback(),
      ),
    );
  }
}

class _ShopLogoFallback extends StatelessWidget {
  const _ShopLogoFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: RestaurantPalette.orange,
      child: Center(
        child: Icon(Icons.storefront, color: Colors.white, size: 30),
      ),
    );
  }
}

class _DrawerItem {
  const _DrawerItem({
    required this.label,
    required this.outline,
    required this.filled,
  });

  final String label;
  final IconData outline;
  final IconData filled;
}