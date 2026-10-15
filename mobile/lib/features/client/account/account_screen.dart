import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/profile_widgets.dart';

/// Profil client (J153) : carte verte, statistiques, menu « Mon compte ».
///
/// Données entièrement dynamiques : photo de profil (upload), compteurs
/// `GET /me/stats`, cloche avec pastille réelle et sections routées. Le rendu
/// s'appuie sur les widgets partagés de `profile_widgets.dart`, partagés avec
/// les espaces vendeur et livreur.
class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.session,
    required this.marketplace,
    this.onOpenMenu,
    required this.onSelectTab,
  });

  final SessionProvider session;
  final MarketplaceApi marketplace;

  /// Ouvre le tiroir latéral (menu hamburger) — géré par le shell client.
  final VoidCallback? onOpenMenu;

  final ValueChanged<int> onSelectTab;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? _stats;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await widget.marketplace.meStats();
      if (mounted) {
        setState(() => _stats = stats);
      }
    } catch (_) {
      // Les compteurs restent au dernier état connu (ou « … »).
    }
  }

  int _statInt(String key) => (_stats?[key] as num?)?.toInt() ?? 0;

  bool get _statsLoaded => _stats != null;

  Future<void> _openRoute(String path) async {
    await context.push(path);
    if (mounted) {
      await _loadStats();
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
      );
      if (picked == null) {
        return;
      }
      setState(() => _uploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      await widget.marketplace.uploadAvatar(bytes, fileName: picked.name);
      await widget.session.refreshProfile();
      await _loadStats();
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Déconnexion',
      message: 'Voulez-vous vraiment vous déconnecter ?',
      confirmLabel: 'Déconnecter',
    );
    if (!confirmed || !mounted) {
      return;
    }
    await widget.session.logout();
    if (mounted) {
      context.go('/landing');
    }
  }

  void _showWalletSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.greenLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 30,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: AppDimens.md),
                const Text(
                  'Portefeuille Béninfood',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppDimens.sm),
                Text(
                  formatAmount(_statInt('wallet_balance')),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: AppDimens.sm),
                const Text(
                  'Solde disponible sur votre compte client.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimens.lg),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileHeader(
            marketplace: widget.marketplace,
            uploadingAvatar: _uploadingAvatar,
            onMenu: widget.onOpenMenu,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  const ProfilePageTitle('Mon profil'),
                  ProfileHero(
                    user: user,
                    badges: _buildBadges(),
                    stats: _buildStats(),
                    uploadingAvatar: _uploadingAvatar,
                    onEditAvatar: _pickAvatar,
                    onShowQr: () => showContactQrSheet(context, user),
                  ),
                  const SizedBox(height: AppDimens.xl),
                  const ProfileSectionTitle('Mon compte'),
                  ProfileMenuCard(entries: _buildMenuEntries()),
                  if ((user?.contexts.length ?? 1) > 1) ...[
                    const ProfileSectionTitle('Espaces accessibles'),
                    ProfileSpacesMenu(
                      session: widget.session,
                      currentContext: AppContext.client,
                    ),
                  ],
                  const SizedBox(height: AppDimens.lg),
                  ProfileLogoutButton(onConfirm: _confirmLogout),
                  const SizedBox(height: AppDimens.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBadges() {
    return [
      const ProfileLabelBadge(
        icon: Icons.shopping_bag_outlined,
        label: 'Espace client',
      ),
      if (_statsLoaded && _statInt('orders_count') >= 5)
        const ProfileLabelBadge(
          icon: Icons.workspace_premium_outlined,
          label: 'Client fidèle',
        ),
    ];
  }

  List<ProfileStat> _buildStats() {
    return [
      ProfileStat(
        icon: Icons.shopping_bag_outlined,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        value: _statsLoaded ? '${_statInt('orders_count')}' : '…',
        label: 'Commandes',
        onTap: () => widget.onSelectTab(3),
      ),
      ProfileStat(
        icon: Icons.favorite_border,
        tint: AppColors.redLight,
        accent: AppColors.red,
        value: _statsLoaded ? '${_statInt('favorites_count')}' : '…',
        label: 'Favoris',
        onTap: () => _openRoute('/client/favorites'),
      ),
      ProfileStat(
        icon: Icons.confirmation_number_outlined,
        tint: AppColors.goldLight,
        accent: AppColors.goldDark,
        value: _statsLoaded ? '${_statInt('coupons_count')}' : '…',
        label: 'Coupons',
        onTap: () => _openRoute('/client/coupons'),
      ),
      ProfileStat(
        icon: Icons.account_balance_wallet_outlined,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        value: _statsLoaded
            ? formatAmount(_statInt('wallet_balance'), showSymbol: false).trim()
            : '…',
        suffix: 'FCFA',
        label: 'Portefeuille',
        onTap: _showWalletSheet,
      ),
    ];
  }

  List<ProfileMenuEntry> _buildMenuEntries() {
    return [
      ProfileMenuEntry(
        icon: Icons.person_outline,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        title: 'Informations personnelles',
        subtitle: 'Nom, e-mail, photo...',
        onTap: () => _openRoute('/client/profile/edit'),
      ),
      ProfileMenuEntry(
        icon: Icons.location_on_outlined,
        tint: AppColors.orangeLight,
        accent: AppColors.orange,
        title: 'Adresses enregistrées',
        subtitle: 'Maison, travail, autres...',
        onTap: () => _openRoute('/client/addresses'),
      ),
      ProfileMenuEntry(
        icon: Icons.delivery_dining_outlined,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        title: 'Mes livreurs',
        subtitle: 'Vos livreurs favoris, contactables...',
        onTap: () => _openRoute('/client/favorite-drivers'),
      ),
      ProfileMenuEntry(
        icon: Icons.credit_card,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        title: 'Méthodes de paiement',
        subtitle: 'Cartes, mobile money...',
        onTap: () => _openRoute('/client/payment-methods'),
      ),
      ProfileMenuEntry(
        icon: Icons.notifications_none,
        tint: AppColors.orangeLight,
        accent: AppColors.orange,
        title: 'Notifications',
        subtitle: 'Commandes, alertes, offres...',
        onTap: () => _openRoute('/client/notifications'),
      ),
      ProfileMenuEntry(
        icon: Icons.shield_outlined,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        title: 'Sécurité',
        subtitle: 'Mot de passe, appareils...',
        onTap: () => _openRoute('/client/security'),
      ),
      ProfileMenuEntry(
        icon: Icons.help_outline,
        tint: AppColors.orangeLight,
        accent: AppColors.orange,
        title: 'Aide et support',
        subtitle: 'Questions fréquentes, nous contacter...',
        onTap: () => _openRoute('/client/complaints'),
      ),
    ];
  }
}
