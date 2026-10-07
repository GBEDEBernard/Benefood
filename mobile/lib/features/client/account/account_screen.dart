import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/notification_bell.dart';

/// Profil client (J153) : carte verte, statistiques, menu « Mon compte ».
///
/// Données entièrement dynamiques : photo de profil (upload), compteurs
/// `GET /me/stats`, cloche avec pastille réelle et sections routées.
class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.session,
    required this.marketplace,
    required this.onSelectTab,
  });

  final SessionProvider session;
  final MarketplaceApi marketplace;
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

  void _showQrSheet() {
    final user = widget.session.user;
    final name = (user?.name ?? '').trim();
    final displayName = name.isEmpty ? 'Utilisateur' : name;
    final phone = user?.phone ?? '';
    final email = user?.email;

    final safeName = displayName.replaceAll(RegExp(r'[:;,$]'), ' ').trim();
    final buffer = StringBuffer('MECARD:N:$safeName;');
    if (phone.isNotEmpty) {
      buffer.write('TEL:$phone;');
    }
    if (email != null && email.isNotEmpty) {
      buffer.write('EMAIL:$email;');
    }

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
                const Text(
                  'Ma carte de contact',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppDimens.lg),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: QrImageView(
                    data: buffer.toString(),
                    size: 190,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: AppDimens.lg),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: AppDimens.sm),
                const Text(
                  'Scannez ce code pour enregistrer mes coordonnées.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.session.logout();
      if (mounted) {
        context.go('/landing');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              marketplace: widget.marketplace,
              uploadingAvatar: _uploadingAvatar,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppDimens.pagePadding,
                      6,
                      AppDimens.pagePadding,
                      14,
                    ),
                    child: Text(
                      'Mon profil',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  _ProfileBlock(
                    user: user,
                    uploadingAvatar: _uploadingAvatar,
                    onEditAvatar: _pickAvatar,
                    onShowQr: _showQrSheet,
                    statsCard: _StatsCard(
                      loaded: _statsLoaded,
                      ordersCount: _statInt('orders_count'),
                      favoritesCount: _statInt('favorites_count'),
                      couponsCount: _statInt('coupons_count'),
                      walletBalance: _statInt('wallet_balance'),
                      onTapOrders: () => widget.onSelectTab(3),
                      onTapFavorites: () => _openRoute('/client/favorites'),
                      onTapCoupons: () => _openRoute('/client/coupons'),
                      onTapWallet: _showWalletSheet,
                    ),
                  ),
                  const SizedBox(height: AppDimens.xl),
                  const _SectionTitle('Mon compte'),
                  _AccountMenu(
                    user: user,
                    onPersonalInfo: () => _openRoute('/client/profile/edit'),
                    onAddresses: () => _openRoute('/client/addresses'),
                    onPaymentMethods: () =>
                        _openRoute('/client/payment-methods'),
                    onNotifications: () => _openRoute('/client/notifications'),
                    onSecurity: () => _openRoute('/client/security'),
                    onSupport: () => _openRoute('/client/complaints'),
                  ),
                  if ((user?.contexts.length ?? 1) > 1) ...[
                    const _SectionTitle('Espaces accessibles'),
                    _SpacesMenu(session: widget.session, user: user),
                  ],
                  const SizedBox(height: AppDimens.lg),
                  _LogoutButton(onConfirm: _confirmLogout),
                  const SizedBox(height: AppDimens.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- en-tête

/// En-tête : logo central + cloche dynamique (pastille = non lus réels).
class _Header extends StatelessWidget {
  const _Header({required this.marketplace, required this.uploadingAvatar});

  final MarketplaceApi marketplace;
  final bool uploadingAvatar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 44),
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/Logo.jpeg',
                height: 44,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const BrandMark(),
              ),
            ),
          ),
          if (uploadingAvatar)
            const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            NotificationBell(api: marketplace),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- carte profil

/// Carte verte + statistiques en surimpression.
class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({
    required this.user,
    required this.uploadingAvatar,
    required this.onEditAvatar,
    required this.onShowQr,
    required this.statsCard,
  });

  final User? user;
  final bool uploadingAvatar;
  final VoidCallback onEditAvatar;
  final VoidCallback onShowQr;
  final Widget statsCard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 52),
            child: _GreenProfileCard(
              user: user,
              uploadingAvatar: uploadingAvatar,
              onEditAvatar: onEditAvatar,
              onShowQr: onShowQr,
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: statsCard),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- carte verte

/// Carte verte (#1A5B2E) : avatar, identité, badges et coordonnées.
class _GreenProfileCard extends StatelessWidget {
  const _GreenProfileCard({
    required this.user,
    required this.uploadingAvatar,
    required this.onEditAvatar,
    required this.onShowQr,
  });

  final User? user;
  final bool uploadingAvatar;
  final VoidCallback onEditAvatar;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) {
    final name = (user?.name ?? '').trim();
    final displayName = name.isEmpty ? 'Utilisateur' : name;
    final phone = user?.phone ?? '';
    final email = user?.email;

    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            name: displayName,
            imageUrl: user?.avatarUrl,
            uploading: uploadingAvatar,
            onEdit: onEditAvatar,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [_RatingBadge(), _LoyalBadge()],
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ContactLine(icon: Icons.call_outlined, text: phone),
                ],
                if (email != null && email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _ContactLine(icon: Icons.mail_outline, text: email),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _QrButton(onTap: onShowQr),
        ],
      ),
    );
  }
}

/// Avatar circulaire (photo réelle ou initiales) + bouton crayon.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.imageUrl,
    required this.uploading,
    required this.onEdit,
  });

  final String name;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);

    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.surface.withValues(alpha: 0.45),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Text(
                      initials,
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  )
                : Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
          ),
          if (uploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surface.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.surface,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: AppColors.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onEdit,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.green, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 12,
                    color: AppColors.orange,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first[0]
        : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

/// Badge étoile « ⭐ 4,7 » (fond jaune clair).
class _RatingBadge extends StatelessWidget {
  const _RatingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: const Text(
        '⭐ 4,7',
        style: TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Badge « 🥇 Client fidèle » (icône médaille, texte blanc).
class _LoyalBadge extends StatelessWidget {
  const _LoyalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 13, color: AppColors.gold),
          SizedBox(width: 5),
          Text(
            'Client fidèle',
            style: TextStyle(
              color: AppColors.surface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de coordonnée : petite icône + texte blanc.
class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.75)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.surface,
              fontSize: 12.5,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cadre QR (droite de la carte verte).
class _QrButton extends StatelessWidget {
  const _QrButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm + 2),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm + 2),
          ),
          child: const Icon(Icons.qr_code, size: 26, color: AppColors.surface),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- statistiques

/// Carte blanche de statistiques, en chevauchement sous la carte verte.
class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.loaded,
    required this.ordersCount,
    required this.favoritesCount,
    required this.couponsCount,
    required this.walletBalance,
    required this.onTapOrders,
    required this.onTapFavorites,
    required this.onTapCoupons,
    required this.onTapWallet,
  });

  final bool loaded;
  final int ordersCount;
  final int favoritesCount;
  final int couponsCount;
  final int walletBalance;
  final VoidCallback onTapOrders;
  final VoidCallback onTapFavorites;
  final VoidCallback onTapCoupons;
  final VoidCallback onTapWallet;

  String get _wallet =>
      loaded ? formatAmount(walletBalance, showSymbol: false).trim() : '…';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.shopping_bag_outlined,
              tint: AppColors.greenLight,
              accent: AppColors.green,
              value: loaded ? '$ordersCount' : '…',
              label: 'Commandes',
              onTap: onTapOrders,
            ),
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.favorite_border,
              tint: AppColors.redLight,
              accent: AppColors.red,
              value: loaded ? '$favoritesCount' : '…',
              label: 'Favoris',
              onTap: onTapFavorites,
            ),
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.confirmation_number_outlined,
              tint: AppColors.goldLight,
              accent: AppColors.goldDark,
              value: loaded ? '$couponsCount' : '…',
              label: 'Coupons',
              onTap: onTapCoupons,
            ),
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.account_balance_wallet_outlined,
              tint: AppColors.greenLight,
              accent: AppColors.green,
              value: _wallet,
              suffix: 'FCFA',
              label: 'Portefeuille',
              onTap: onTapWallet,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une colonne de statistique : icône teintée, chiffre, libellé.
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.tint,
    required this.accent,
    required this.value,
    required this.label,
    required this.onTap,
    this.suffix,
  });

  final IconData icon;
  final Color tint;
  final Color accent;
  final String value;
  final String label;
  final String? suffix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm + 1),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      height: 1.1,
                    ),
                  ),
                  if (suffix != null)
                    TextSpan(
                      text: ' $suffix',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.1,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- menu

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        8,
        AppDimens.pagePadding,
        12,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

/// Menu « Mon compte » : 6 entrées avec icône, titre, sous-titre, chevron.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu({
    required this.user,
    required this.onPersonalInfo,
    required this.onAddresses,
    required this.onPaymentMethods,
    required this.onNotifications,
    required this.onSecurity,
    required this.onSupport,
  });

  final User? user;
  final VoidCallback onPersonalInfo;
  final VoidCallback onAddresses;
  final VoidCallback onPaymentMethods;
  final VoidCallback onNotifications;
  final VoidCallback onSecurity;
  final VoidCallback onSupport;

  static const _entries = <(IconData, Color, Color, String, String)>[
    (
      Icons.person_outline,
      AppColors.greenLight,
      AppColors.green,
      'Informations personnelles',
      'Nom, e-mail, photo...',
    ),
    (
      Icons.location_on_outlined,
      AppColors.orangeLight,
      AppColors.orange,
      'Adresses enregistrées',
      'Maison, travail, autres...',
    ),
    (
      Icons.credit_card,
      AppColors.greenLight,
      AppColors.green,
      'Méthodes de paiement',
      'Cartes, mobile money...',
    ),
    (
      Icons.notifications_none,
      AppColors.orangeLight,
      AppColors.orange,
      'Notifications',
      'Commandes, alertes, offres...',
    ),
    (
      Icons.shield_outlined,
      AppColors.greenLight,
      AppColors.green,
      'Sécurité',
      'Mot de passe, appareils...',
    ),
    (
      Icons.help_outline,
      AppColors.orangeLight,
      AppColors.orange,
      'Aide et support',
      'Questions fréquentes, nous contacter...',
    ),
  ];

  VoidCallback _handlerAt(int index) {
    return switch (index) {
      0 => onPersonalInfo,
      1 => onAddresses,
      2 => onPaymentMethods,
      3 => onNotifications,
      4 => onSecurity,
      _ => onSupport,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: DecoratedBox(
        // Ombre hors Material : ListTile peint ses effets sur le Material.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          boxShadow: AppTheme.softShadow(),
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < _entries.length; i++) ...[
                _MenuTile(
                  icon: _entries[i].$1,
                  tint: _entries[i].$2,
                  accent: _entries[i].$3,
                  title: _entries[i].$4,
                  subtitle: _entries[i].$5,
                  onTap: _handlerAt(i),
                ),
                if (i < _entries.length - 1)
                  const Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 16,
                    color: AppColors.border,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne de menu : icône colorée, titre, sous-titre, chevron.
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.tint,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm + 3),
        ),
        child: Icon(icon, size: 19, color: accent),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 22,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Bascule vers les espaces vendeur / livreur (utilisateurs multi-rôles).
class _SpacesMenu extends StatelessWidget {
  const _SpacesMenu({required this.session, required this.user});

  final SessionProvider session;
  final User? user;

  static const _items = <(String, IconData, String, String)>[
    (
      AppContext.vendor,
      Icons.storefront_outlined,
      'Espace vendeur',
      'Produits, commandes, statistiques',
    ),
    (
      AppContext.driver,
      Icons.delivery_dining_outlined,
      'Espace livreur',
      'Missions, disponibilité, gains',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          boxShadow: AppTheme.softShadow(),
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (user!.contexts.contains(_items[i].$1))
                  _MenuTile(
                    icon: _items[i].$2,
                    tint: AppColors.greenLight,
                    accent: AppColors.green,
                    title: _items[i].$3,
                    subtitle: _items[i].$4,
                    onTap: () {
                      session.switchRole(_items[i].$1);
                      context.go(
                        _items[i].$1 == AppContext.vendor
                            ? '/vendor'
                            : '/driver',
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- déconnexion

/// Bouton « Se déconnecter » pleine largeur (fond orange très clair).
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Material(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: InkWell(
          onTap: onConfirm,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.25),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, size: 19, color: AppColors.orange),
                SizedBox(width: 8),
                Text(
                  'Se déconnecter',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange,
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
