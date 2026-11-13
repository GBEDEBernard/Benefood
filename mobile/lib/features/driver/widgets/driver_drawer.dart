import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/drawer_kit.dart';
import '../../../shared/widgets/feedback_widgets.dart';

class _DriverDrawerPalette {
  const _DriverDrawerPalette._();

  static const green = Color(0xFF17652F);
  static const greenDeep = Color(0xFF0B2A19);
  static const greenLight = Color(0xFFEAF5EC);
  static const greenBorder = Color(0xFFE6ECE7);
}

/// Tiroir latéral de l'espace livreur Béninfood.
///
/// Dominante verte sur fond crème : carte d'identité animée (dégradé qui
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
        textScaler: media.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.12,
        ),
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 14, 0),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        const Spacer(),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                            children: [
                              TextSpan(
                                text: 'Bénin',
                                style: TextStyle(
                                  color: _DriverDrawerPalette.greenDeep,
                                ),
                              ),
                              TextSpan(
                                text: 'Food',
                                style: TextStyle(color: AppColors.orange),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Fermer le menu',
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.text,
                            side: const BorderSide(color: DrawerPalette.line),
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              DrawerStagger(
                index: 1,
                child: DrawerIdentityCard(
                  badgeIcon: Icons.delivery_dining_rounded,
                  badgeLabel: 'ESPACE LIVREUR',
                  avatarUrl: user?.avatarUrl,
                  name: _displayName(user),
                  compact: compact,
                  pillBuilder: (t) => DrawerStatusPill(
                    label: available ? 'EN LIGNE' : 'HORS LIGNE',
                    active: available,
                    dotColor: _DriverDrawerPalette.green,
                    textColor: _DriverDrawerPalette.greenDeep,
                    t: t,
                  ),
                  footerIcon: vehicle != null && vehicle!.isNotEmpty
                      ? Icons.two_wheeler_rounded
                      : Icons.verified_rounded,
                  footerText: vehicle != null && vehicle!.isNotEmpty
                      ? vehicle!
                      : 'Livreur vérifié Béninfood',
                  gradientColors: const [
                    Color(0xFF092417),
                    Color(0xFF124B2A),
                    Color(0xFF1E6935),
                  ],
                  glowColor: _DriverDrawerPalette.green,
                  avatarRingColors: const [
                    Colors.white,
                    Color(0xFFB7E2BD),
                    Color(0xFFE9F7EA),
                    Colors.white,
                  ],
                  avatarFallbackBackground: _DriverDrawerPalette.greenLight,
                  avatarFallbackForeground: _DriverDrawerPalette.greenDeep,
                  trailing: statusLabel == null
                      ? null
                      : DrawerStatusChip(
                          label: statusLabel!,
                          dotColor: statusColor ?? _DriverDrawerPalette.green,
                          textColor: _DriverDrawerPalette.greenDeep,
                        ),
                ),
              ),
              SizedBox(height: compact ? 8 : 14),
              DrawerStagger(
                index: 2,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(22, 0, 22, 10),
                  child: DrawerSectionHeader(
                    label: 'NAVIGATION',
                    trailing: DrawerAccentBar(
                      color: _DriverDrawerPalette.green,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _DriverDrawerPalette.greenBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < _items.length; i++) ...[
                            DrawerStagger(
                              index: i + 3,
                              child: DrawerNavTile(
                                label: _items[i].label,
                                subtitle: _items[i].subtitle,
                                outline: _items[i].outline,
                                filled: _items[i].filled,
                                active: i == currentIndex,
                                compact: compact,
                                accentColor: _DriverDrawerPalette.green,
                                activeBackground:
                                    _DriverDrawerPalette.greenLight,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.of(context).pop();
                                  onSelectTab(i);
                                },
                              ),
                            ),
                            if (i < _items.length - 1)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Divider(
                                  height: 1,
                                  color: _DriverDrawerPalette.greenBorder,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    DrawerStagger(
                      index: _items.length + 3,
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
                            color: _DriverDrawerPalette.green,
                            onTap: () => _open(context, '/driver/stats'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DrawerQuickAction(
                            index: 1,
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Portefeuille',
                            color: _DriverDrawerPalette.green,
                            onTap: () => _open(context, '/driver/wallet'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DrawerQuickAction(
                            index: 2,
                            icon: Icons.people_alt_rounded,
                            label: 'Mes clients',
                            color: _DriverDrawerPalette.green,
                            onTap: () =>
                                _open(context, '/driver/favorite-clients'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              DrawerStagger(
                index: _items.length + 4,
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
