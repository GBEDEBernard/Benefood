import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Tiroir latéral premium de l'espace livreur Béninfood.
///
/// Identité visuelle : vert profond, orange et crème — aligné sur le tiroir
/// vendeur. Contenu : identité du livreur (photo, statut en ligne), navigation
/// vers les onglets, accès rapides et déconnexion.
class DriverDrawer extends StatelessWidget {
  const DriverDrawer({
    super.key,
    required this.session,
    required this.currentIndex,
    required this.onSelectTab,
    this.available = false,
    this.statusLabel,
    this.statusColor,
    this.vehicle,
    this.onLogout,
  });

  final SessionProvider session;

  /// Onglet actif (0 missions … 4 compte).
  final int currentIndex;

  final ValueChanged<int> onSelectTab;

  /// Livreur en ligne (disponible pour de nouvelles missions).
  final bool available;

  /// Libellé du statut du dossier livreur (« Actif », « En vérification »…).
  final String? statusLabel;
  final Color? statusColor;

  /// Moyen de transport du livreur (« Moto TVN-4521 »).
  final String? vehicle;

  /// Déconnexion (géré par le shell).
  final VoidCallback? onLogout;

  static const _ink = AppColors.green;
  static const _inkDeep = Color(0xFF0E3B1D);
  static const _cream = AppColors.background;
  static const _muted = Color(0xFF7A887F);
  static const _line = Color(0xFFECE7DE);
  static const _greenWash = Color(0xFFEAF3EC);

  static const List<_DrawerItem> _items = [
    _DrawerItem(
      label: 'Mes missions',
      subtitle: 'Courses en cours et à venir',
      outline: Icons.delivery_dining_outlined,
      filled: Icons.delivery_dining_rounded,
    ),
    _DrawerItem(
      label: 'Offres disponibles',
      subtitle: 'Accepter de nouvelles courses',
      outline: Icons.local_offer_outlined,
      filled: Icons.local_offer_rounded,
    ),
    _DrawerItem(
      label: 'Mes colis',
      subtitle: 'Colis à collecter et livrer',
      outline: Icons.inventory_2_outlined,
      filled: Icons.inventory_2_rounded,
    ),
    _DrawerItem(
      label: 'Historique',
      subtitle: 'Missions terminées',
      outline: Icons.history_outlined,
      filled: Icons.history_rounded,
    ),
    _DrawerItem(
      label: 'Mon compte',
      subtitle: 'Profil, gains et réglages',
      outline: Icons.person_outline,
      filled: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.88, 340.0);
    final user = session.user;

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
            _buildHeader(context, user),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: Row(
                children: [
                  Text(
                    'NAVIGATION',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.7,
                    ),
                  ),
                  Spacer(),
                  _AccentBar(),
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
                          Navigator.of(context).pop();
                          onSelectTab(i);
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
                          icon: Icons.insights_rounded,
                          label: 'Statistiques',
                          color: const Color(0xFFBA672C),
                          onTap: () => _open(context, '/driver/stats'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Portefeuille',
                          color: const Color(0xFF5274A5),
                          onTap: () => _open(context, '/driver/wallet'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.people_alt_rounded,
                          label: 'Mes clients',
                          color: const Color(0xFF2E7953),
                          onTap: () => _open(context, '/driver/favorite-clients'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildLogout(context),
            const SizedBox(height: 10),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'BÉNINFOOD  •  ESPACE LIVREUR',
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

  /// Carte d'identité : photo, nom, statut en ligne et badge livreur.
  Widget _buildHeader(BuildContext context, User? user) {
    final name = (user?.name ?? '').trim();
    final displayName = name.isEmpty ? 'Livreur Béninfood' : name;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.fromLTRB(16, 18, 14, 17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ink, _inkDeep],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.22),
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
                        Icon(
                          Icons.delivery_dining_rounded,
                          color: Color(0xFFFFC078),
                          size: 13,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'ESPACE LIVREUR',
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
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _DriverAvatar(url: user?.avatarUrl, name: displayName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
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
                        _OnlinePill(available: available),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    vehicle != null && vehicle!.isNotEmpty
                        ? Icons.two_wheeler_rounded
                        : Icons.verified_rounded,
                    size: 15,
                    color: const Color(0xFFFFC078),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (vehicle != null && vehicle!.isNotEmpty)
                          ? vehicle!
                          : 'Livreur vérifié Béninfood',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE3EFE5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (statusLabel != null) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          statusColor ?? const Color(0xFF9BE2AF),
                          Colors.white,
                          0.45,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bouton de déconnexion (avec confirmation).
  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Material(
        color: const Color(0xFFFFF0EA),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () async {
            HapticFeedback.mediumImpact();
            final confirmed = await showConfirmDialog(
              context,
              title: 'Déconnexion',
              message: 'Voulez-vous vraiment vous déconnecter ?',
              confirmLabel: 'Déconnecter',
            );
            if (!confirmed || !context.mounted) {
              return;
            }
            Navigator.of(context).pop();
            onLogout?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFF6D9CC)),
            ),
            child: const Row(
              children: [
                Icon(Icons.logout_rounded, size: 20, color: Color(0xFFCE5738)),
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
                Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFCE8B75)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, String route) {
    HapticFeedback.selectionClick();
    // Le routeur est résolu avant la fermeture du tiroir : le contexte du
    // tiroir devient inutilisable une fois la route retirée du navigator.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(route);
  }
}

/// Barre d'accentuation du titre de section.
class _AccentBar extends StatelessWidget {
  const _AccentBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 3,
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

/// Pastille « en ligne / hors ligne ».
class _OnlinePill extends StatelessWidget {
  const _OnlinePill({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available
        ? const Color(0xFF9BE2AF)
        : const Color(0xFFFFB3A1);
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
            available ? 'EN LIGNE' : 'HORS LIGNE',
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

/// Avatar du livreur : photo de profil ou initiales.
class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;

    return Container(
      width: 62,
      height: 62,
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFC078), AppColors.orange],
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
                  errorBuilder: (_, _, _) => _fallback(),
                )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: AppColors.orange,
      child: Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Ligne de navigation du tiroir.
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _DrawerItem item;
  final bool active;
  final VoidCallback onTap;

  static const _inkSoftColor = Color(0xFF52705D);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: active ? DriverDrawer._greenWash : Colors.transparent,
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
                    color: active ? DriverDrawer._ink : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active
                          ? DriverDrawer._ink
                          : const Color(0xFFECE7DE),
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: DriverDrawer._ink.withValues(alpha: 0.15),
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
                          color: active
                              ? DriverDrawer._ink
                              : const Color(0xFF34483B),
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
                          color: DriverDrawer._muted,
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
                      color: AppColors.orange,
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
}

/// Tuile d'accès rapide.
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
            border: Border.all(color: DriverDrawer._line),
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

/// Entrée de navigation du tiroir.
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
