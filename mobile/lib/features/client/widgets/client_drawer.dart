import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/drawer_kit.dart';
import '../../../shared/widgets/feedback_widgets.dart';

class _ClientDrawerPalette {
  const _ClientDrawerPalette._();

  static const green = Color(0xFF17652F);
  static const greenDeep = Color(0xFF0B2A19);
  static const greenLight = Color(0xFFEAF5EC);
  static const greenBorder = Color(0xFFE6ECE7);
}

/// Tiroir latéral de l'espace client Béninfood.
///
/// Carte d'identité verte animée, navigation en cascade et accès rapides.
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
    'active' => ('Vérifié', _ClientDrawerPalette.green),
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
                      mainAxisAlignment: MainAxisAlignment.center,
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
                                  color: _ClientDrawerPalette.greenDeep,
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
                            side: const BorderSide(
                              color: _ClientDrawerPalette.greenBorder,
                            ),
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
                  badgeIcon: Icons.shopping_bag_rounded,
                  badgeLabel: 'ESPACE CLIENT',
                  avatarUrl: user?.avatarUrl,
                  name: _displayName(user),
                  compact: compact,
                  pillBuilder: (t) => DrawerStatusPill(
                    label: verified ? 'CLIENT VÉRIFIÉ' : 'DOSSIER EN COURS',
                    active: verified,
                    dotColor: _ClientDrawerPalette.green,
                    textColor: _ClientDrawerPalette.greenDeep,
                    t: t,
                  ),
                  footerIcon: Icons.phone_rounded,
                  footerText: _contact(user),
                  trailing: statusLabel == null
                      ? null
                      : DrawerStatusChip(
                          label: statusLabel!,
                          dotColor: statusColor ?? _ClientDrawerPalette.green,
                          textColor:
                              statusColor ?? _ClientDrawerPalette.greenDeep,
                        ),
                  gradientColors: const [
                    Color(0xFF092417),
                    Color(0xFF124B2A),
                    Color(0xFF1E6935),
                  ],
                  glowColor: _ClientDrawerPalette.green,
                  avatarRingColors: const [
                    Colors.white,
                    Color(0xFFB7E2BD),
                    Color(0xFFE9F7EA),
                    Colors.white,
                  ],
                  avatarFallbackBackground: _ClientDrawerPalette.greenLight,
                  avatarFallbackForeground: _ClientDrawerPalette.greenDeep,
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
                      color: _ClientDrawerPalette.green,
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
                          color: _ClientDrawerPalette.greenBorder,
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
                                badge: i == 2 ? cartCount : 0,
                                accentColor: _ClientDrawerPalette.green,
                                activeBackground:
                                    _ClientDrawerPalette.greenLight,
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
                                  color: _ClientDrawerPalette.greenBorder,
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
                            icon: Icons.support_agent_rounded,
                            label: 'Aide & Support',
                            color: _ClientDrawerPalette.green,
                            onTap: () => _open(context, '/client/complaints'),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: DrawerQuickAction(
                            index: 1,
                            icon: Icons.location_on_outlined,
                            label: 'Adresses',
                            color: _ClientDrawerPalette.green,
                            onTap: () => _open(context, '/client/addresses'),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: DrawerQuickAction(
                            index: 2,
                            icon: Icons.confirmation_number_outlined,
                            label: 'Codes promo',
                            color: _ClientDrawerPalette.green,
                            onTap: () => _open(context, '/client/coupons'),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: DrawerQuickAction(
                            index: 3,
                            icon: Icons.star_outline_rounded,
                            label: 'Favoris',
                            color: _ClientDrawerPalette.green,
                            onTap: () => _open(context, '/client/favorites'),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DrawerQuickAction(
                            index: 4,
                            icon: Icons.inventory_2_outlined,
                            label: 'Mes colis',
                            color: _ClientDrawerPalette.green,
                            onTap: () => _open(context, '/client/parcels'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DrawerQuickAction(
                            index: 5,
                            icon: Icons.notifications_none_rounded,
                            label: 'Mes notifications',
                            color: _ClientDrawerPalette.green,
                            onTap: () =>
                                _open(context, '/client/notifications'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: SizedBox()),
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
