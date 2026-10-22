import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/drawer_kit.dart';
import '../restaurant_palette.dart';

/// Menu latéral premium de l'espace vendeur Béninfood.
///
/// Identité visuelle : crème, vert profond et orange gourmand.
/// L'API publique est conservée pour ne pas casser les écrans existants.
class RestaurantDrawer extends StatelessWidget {
  const RestaurantDrawer({
    super.key,
    required this.currentIndex,
    required this.isOpen,
    required this.onSelect,
    this.onLogout,
    this.businessName = 'Le Délice Fast-Food',
    this.logoUrl,
  });

  final int currentIndex;
  final bool isOpen;
  final String businessName;
  final String? logoUrl;
  final ValueChanged<int> onSelect;
  final VoidCallback? onLogout;

  static const _ink = Color(0xFF173B2D);
  static const _inkSoft = Color(0xFF315846);
  static const _orange = Color(0xFFF07835);
  static const _cream = Color(0xFFFFFBF5);
  static const _muted = Color(0xFF7A887F);
  static const _line = Color(0xFFECE7DE);
  static const _greenWash = Color(0xFFEAF3EC);

  static const List<_DrawerItem> _items = [
    _DrawerItem(
      label: 'Vue d’ensemble',
      subtitle: 'Résumé de votre activité',
      outline: Icons.space_dashboard_outlined,
      filled: Icons.space_dashboard_rounded,
    ),
    _DrawerItem(
      label: 'Ma boutique',
      subtitle: 'Informations et visibilité',
      outline: Icons.storefront_outlined,
      filled: Icons.storefront_rounded,
    ),
    _DrawerItem(
      label: 'Mes produits',
      subtitle: 'Carte, prix et disponibilités',
      outline: Icons.restaurant_menu_outlined,
      filled: Icons.restaurant_menu_rounded,
    ),
    _DrawerItem(
      label: 'Commandes',
      subtitle: 'Suivre les commandes clients',
      outline: Icons.receipt_long_outlined,
      filled: Icons.receipt_long_rounded,
    ),
    _DrawerItem(
      label: 'Revenus',
      subtitle: 'Ventes et paiements',
      outline: Icons.account_balance_wallet_outlined,
      filled: Icons.account_balance_wallet_rounded,
    ),
    _DrawerItem(
      label: 'Mon dossier',
      subtitle: 'Documents de la boutique',
      outline: Icons.folder_open_outlined,
      filled: Icons.folder_rounded,
    ),
    _DrawerItem(
      label: 'Avis clients',
      subtitle: 'Notes et commentaires',
      outline: Icons.star_outline_rounded,
      filled: Icons.star_rounded,
    ),
    _DrawerItem(
      label: 'Historique',
      subtitle: 'Vos dernières activités',
      outline: Icons.history_rounded,
      filled: Icons.history_rounded,
    ),
    _DrawerItem(
      label: 'Profil et réglages',
      subtitle: 'Compte et préférences',
      outline: Icons.tune_rounded,
      filled: Icons.tune_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.88, 360.0);

    return Drawer(
      width: width,
      elevation: 0,
      backgroundColor: _cream,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 5, 22, 10),
              child: Row(
                children: [
                  const Text(
                    'ESPACE VENDEUR',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.7,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 24,
                    height: 3,
                    decoration: BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                physics: const BouncingScrollPhysics(),
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: _NavTile(
                        item: _items[i],
                        active: i == currentIndex,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelect(i);
                        },
                      ),
                    ),
                  const SizedBox(height: 13),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Text(
                      'ACCÈS RAPIDES',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.inventory_2_outlined,
                          label: 'Mes colis',
                          color: const Color(0xFF2E7953),
                          onTap: () => _open(context, '/vendor/parcels'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.insights_rounded,
                          label: 'Statistiques',
                          color: const Color(0xFFBA672C),
                          onTap: () => _open(context, '/vendor/stats'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Portefeuille',
                          color: const Color(0xFF5274A5),
                          onTap: () => _open(context, '/vendor/wallet'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildLogout(context),
            const SizedBox(height: 12),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'BÉNINFOOD  •  ESPACE PARTENAIRE',
                  style: TextStyle(
                    color: Color(0xFFA3AAA3),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.fromLTRB(16, 18, 14, 17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ink, Color(0xFF24563E)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -23,
            top: -32,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                  width: 18,
                ),
              ),
            ),
          ),
          // Décor food : bol garni et herbes estompés dans le vert profond.
          const DrawerFoodDecor(intensity: 1.15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant_rounded,
                            color: Color(0xFFFFC078), size: 13),
                        SizedBox(width: 5),
                        Text(
                          'MON ESPACE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xFFD7E5D9),
                    size: 23,
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ShopLogo(url: logoUrl, size: 62),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          businessName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.18,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StatusPill(isOpen: isOpen),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 15,
                    color: const Color(0xFFFFC078),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Partenaire Béninfood',
                      style: TextStyle(
                        color: Color(0xFFE3EFE5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Color(0xFFFFC078),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Material(
        color: const Color(0xFFFFF0EA),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).pop();
            if (onLogout != null) {
              onLogout!();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Déconnexion…')),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFF6D9CC)),
            ),
            child: const Row(
              children: [
                Icon(Icons.logout_rounded,
                    size: 20, color: Color(0xFFCE5738)),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Se déconnecter',
                    style: TextStyle(
                      color: Color(0xFF9D422C),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: Color(0xFFCE8B75)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, String route) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
    context.push(route);
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _DrawerItem item;
  final bool active;
  final VoidCallback onTap;

  static const _ink = Color(0xFF173B2D);
  static const _orange = Color(0xFFF07835);
  static const _muted = Color(0xFF7A887F);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEAF3EC) : Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: active ? const Color(0xFFD4E5D7) : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: active ? _ink : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active ? _ink : const Color(0xFFECE7DE),
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: _ink.withValues(alpha: 0.15),
                              blurRadius: 9,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : const [],
                  ),
                  child: Icon(
                    active ? item.filled : item.outline,
                    color: active ? Colors.white : _inkSoftColor,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? _ink : const Color(0xFF34483B),
                          fontSize: 13,
                          fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (active)
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: _orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _inkSoftColor = Color(0xFF52705D);
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFECE7DE)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF34483B),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final color =
        isOpen ? const Color(0xFF9BE2AF) : const Color(0xFFFFB3A1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'OUVERTE' : 'FERMÉE',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopLogo extends StatelessWidget {
  const _ShopLogo({required this.size, this.url});

  final double size;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFC078), Color(0xFFF07835)],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Color(0xFF24563E),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: hasUrl
              ? Image.network(
                  resolveMediaUrl(url!)!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _ShopLogoFallback(),
                )
              : const _ShopLogoFallback(),
        ),
      ),
    );
  }
}

class _ShopLogoFallback extends StatelessWidget {
  const _ShopLogoFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF07835),
      child: Center(
        child: Icon(Icons.restaurant_rounded, color: Colors.white, size: 27),
      ),
    );
  }
}

class _DrawerItem {
  const _DrawerItem({
    required this.label,
    required this.subtitle,
    required this.outline,
    required this.filled,
  });

  final String label;
  final String subtitle;
  final IconData outline;
  final IconData filled;
}