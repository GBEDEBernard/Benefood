import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/drawer_kit.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Tiroir latéral de l'espace client Béninfood.
///
/// Même langage visuel que l'espace livreur : carte d'identité orange
/// animée (dégradé tournant, bulles, reflet), navigation en cascade avec
/// sous-titres, accès rapides en tuiles et déconnexion.
class ClientDrawer extends StatelessWidget {
  const ClientDrawer({
    super.key,
    required this.session,
    required this.currentIndex,
    required this.onSelectTab,
    this.cartCount = 0,
    this.statusLabel,
    this.statusColor,
    this.onLogout,
  });

  final SessionProvider session;

  /// Onglet actif (0 accueil … 4 compte).
  final int currentIndex;

  final ValueChanged<int> onSelectTab;

  /// Nombre d'articles dans le panier (badge sur l'icône).
  final int cartCount;

  /// Libellé du statut du dossier client (« Vérifié », « En vérification »…).
  final String? statusLabel;
  final Color? statusColor;

  /// Déconnexion (géré par le shell).
  final VoidCallback? onLogout;

  /// Palette du statut du dossier client.
  static (String, Color) statusPalette(String? status) => switch (status) {
        'active' => ('Vérifié', AppColors.orange),
        'suspended' => ('Suspendu', AppColors.red),
        _ => ('En vérification', AppColors.goldDark),
      };

  static const List<_ClientDrawerItem> _items = [
    _ClientDrawerItem(
      label: 'Accueil',
      subtitle: 'Restaurants, produits et offres',
      outline: Icons.home_outlined,
      filled: Icons.home_rounded,
    ),
    _ClientDrawerItem(
      label: 'Catégories',
      subtitle: 'Tout le catalogue Béninfood',
      outline: Icons.grid_view_outlined,
      filled: Icons.grid_view_rounded,
    ),
    _ClientDrawerItem(
      label: 'Mon panier',
      subtitle: 'Articles en attente de paiement',
      outline: Icons.shopping_bag_outlined,
      filled: Icons.shopping_bag_rounded,
    ),
    _ClientDrawerItem(
      label: 'Mes commandes',
      subtitle: 'Suivre mes livraisons',
      outline: Icons.receipt_long_outlined,
      filled: Icons.receipt_long_rounded,
    ),
    _ClientDrawerItem(
      label: 'Mon compte',
      subtitle: 'Profil, adresses et réglages',
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
    final verified = statusLabel == 'Vérifié';

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
                  badgeIcon: Icons.shopping_bag_rounded,
                  badgeLabel: 'ESPACE CLIENT',
                  avatarUrl: user?.avatarUrl,
                  name: _displayName(user),
                  compact: compact,
                  pillBuilder: (t) => DrawerStatusPill(
                    label: verified ? 'CLIENT VÉRIFIÉ' : 'DOSSIER EN COURS',
                    active: verified,
                    dotColor: AppColors.orange,
                    textColor: AppColors.orangeDark,
                    t: t,
                  ),
                  footerIcon: Icons.phone_rounded,
                  footerText: _contact(user),
                  trailing: statusLabel == null
                      ? null
                      : DrawerStatusChip(
                          label: statusLabel!,
                          dotColor: statusColor ?? AppColors.orange,
                          textColor: statusColor ?? AppColors.orangeDark,
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
                            badge: i == 2 ? cartCount : 0,
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
                            icon: Icons.inventory_2_outlined,
                            label: 'Mes colis',
                            color: AppColors.orange,
                            onTap: () => _open(context, '/client/parcels'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DrawerQuickAction(
                            index: 1,
                            icon: Icons.location_on_outlined,
                            label: 'Mes adresses',
                            color: AppColors.orangeDark,
                            onTap: () => _open(context, '/client/addresses'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DrawerQuickAction(
                            index: 2,
                            icon: Icons.favorite_border_rounded,
                            label: 'Mes favoris',
                            color: AppColors.goldDark,
                            onTap: () => _open(context, '/client/favorites'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DrawerQuickAction(
                            index: 3,
                            icon: Icons.support_agent_rounded,
                            label: 'Réclamations',
                            color: AppColors.orange,
                            onTap: () => _open(context, '/client/complaints'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DrawerQuickAction(
                            index: 4,
                            icon: Icons.confirmation_number_outlined,
                            label: 'Mes coupons',
                            color: AppColors.goldDark,
                            onTap: () => _open(context, '/client/coupons'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DrawerQuickAction(
                            index: 5,
                            icon: Icons.notifications_none_rounded,
                            label: 'Notifications',
                            color: AppColors.orangeDark,
                            onTap: () => _open(context, '/client/notifications'),
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
                    'BÉNINFOOD  •  ESPACE CLIENT',
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

  /// Nom affiché : à défaut, une identité client générique.
  static String _displayName(User? user) {
    final name = (user?.name ?? '').trim();
    return name.isEmpty ? 'Client Béninfood' : name;
  }

  /// Contact affiché dans le bandeau de la carte : téléphone, sinon e-mail.
  static String _contact(User? user) {
    final phone = (user?.phone ?? '').trim();
    if (phone.isNotEmpty) {
      return phone;
    }
    final email = (user?.email ?? '').trim();
    return email.isEmpty ? 'Client Béninfood' : email;
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

/// Entrée de navigation du tiroir client.
class _ClientDrawerItem {
  const _ClientDrawerItem({
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
