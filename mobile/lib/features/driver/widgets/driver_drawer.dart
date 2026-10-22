import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/drawer_kit.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Remplace toute teinte verte (ex. statut « Actif » du back) par l'orange.
Color _noGreen(Color color) {
  final hue = HSLColor.fromColor(color).hue;
  return (hue >= 70 && hue <= 170) ? AppColors.orange : color;
}

/// Tiroir latéral de l'espace livreur Béninfood.
///
/// Dominante orange sur fond crème : carte d'identité animée (dégradé qui
/// tourne, bulles, reflet), navigation en cascade, accès rapides et
/// déconnexion. Responsive (largeur plafonnée, mode compact sur écrans courts).
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
    final media = MediaQuery.of(context);
    final width = math.min(media.size.width * 0.88, 340.0);
    final compact = media.size.height < 620;
    final user = session.user;

    return MediaQuery(
      // Polices système plafonnées pour que le tiroir ne déborde jamais.
      data: media.copyWith(
        textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.12),
      ),
      child: Drawer(
        width: width,
        elevation: 0,
        backgroundColor: AppColors.background,
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
              DrawerStagger(
                index: 0,
                child: DrawerIdentityCard(
                  badgeIcon: Icons.delivery_dining_rounded,
                  badgeLabel: 'ESPACE LIVREUR',
                  avatarUrl: user?.avatarUrl,
                  name: _displayName(user),
                  compact: compact,
                  pillBuilder: (t) => DrawerStatusPill(
                    label: available ? 'EN LIGNE' : 'HORS LIGNE',
                    active: available,
                    dotColor: AppColors.orange,
                    textColor: AppColors.orangeDark,
                    t: t,
                  ),
                  footerIcon: vehicle != null && vehicle!.isNotEmpty
                      ? Icons.two_wheeler_rounded
                      : Icons.verified_rounded,
                  footerText: vehicle != null && vehicle!.isNotEmpty
                      ? vehicle!
                      : 'Livreur vérifié Béninfood',
                  trailing: statusLabel == null
                      ? null
                      : DrawerStatusChip(
                          label: statusLabel!,
                          dotColor: _noGreen(statusColor ?? AppColors.orange),
                        ),
                ),
              ),
              SizedBox(height: compact ? 8 : 14),
              DrawerStagger(
                index: 1,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(22, 0, 22, 10),
                  child: DrawerSectionHeader(
                    label: 'NAVIGATION',
                    trailing: DrawerAccentBar(),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      DrawerStagger(
                        index: i + 2,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: DrawerNavTile(
                            label: _items[i].label,
                            subtitle: _items[i].subtitle,
                            outline: _items[i].outline,
                            filled: _items[i].filled,
                            active: i == currentIndex,
                            compact: compact,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).pop();
                              onSelectTab(i);
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    DrawerStagger(
                      index: _items.length + 2,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: DrawerSectionHeader(label: 'ACCÈS RAPIDES'),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DrawerQuickAction(
                            index: 0,
                            icon: Icons.insights_rounded,
                            label: 'Statistiques',
                            color: AppColors.orange,
                            onTap: () => _open(context, '/driver/stats'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DrawerQuickAction(
                            index: 1,
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Portefeuille',
                            color: AppColors.orangeDark,
                            onTap: () => _open(context, '/driver/wallet'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DrawerQuickAction(
                            index: 2,
                            icon: Icons.people_alt_rounded,
                            label: 'Mes clients',
                            color: AppColors.goldDark,
                            onTap: () => _open(context, '/driver/favorite-clients'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              DrawerStagger(
                index: _items.length + 3,
                child: _buildLogout(context),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'BÉNINFOOD  •  ESPACE LIVREUR',
                    style: TextStyle(
                      color: DrawerPalette.footer,
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
      ),
    );
  }

  /// Nom affiché : à défaut, une identité livreur générique.
  static String _displayName(User? user) {
    final name = (user?.name ?? '').trim();
    return name.isEmpty ? 'Livreur Béninfood' : name;
  }

  /// Bouton de déconnexion (avec confirmation).
  Widget _buildLogout(BuildContext context) {
    return DrawerLogoutButton(
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
