import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/auth/session_provider.dart';
import '../../core/data/marketplace_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../models/user.dart';
import 'brand_logo.dart';
import 'notification_bell.dart';

// ------------------------------------------------------------------- en-tête

/// En-tête des écrans de profil : logo central + cloche dynamique
/// (pastille = notifications non lues réelles, J171).
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.marketplace,
    this.uploadingAvatar = false,
  });

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

/// Grand titre de page (« Mon profil »).
class ProfilePageTitle extends StatelessWidget {
  const ProfilePageTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        6,
        AppDimens.pagePadding,
        14,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
          letterSpacing: -0.6,
        ),
      ),
    );
  }
}

/// Titre de section (« Mon compte », « Ma boutique »...).
class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle(this.title, {super.key});

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

// -------------------------------------------------------------- carte verte

/// Pastille claire de la carte verte : libellé sur fond translucide.
class ProfileStatusPill extends StatelessWidget {
  const ProfileStatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
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

/// Pastille de rôle (« Espace vendeur », « Espace livreur »...).
class ProfileLabelBadge extends StatelessWidget {
  const ProfileLabelBadge({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.gold),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
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

/// Une statistique du bandeau blanc.
class ProfileStat {
  const ProfileStat({
    required this.icon,
    required this.tint,
    required this.accent,
    required this.value,
    required this.label,
    this.suffix,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color accent;
  final String value;
  final String label;
  final String? suffix;
  final VoidCallback? onTap;
}

/// Carte verte d'identité + bandeau de statistiques en surimpression
/// (design partagé client / vendeur / livreur, J171).
class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.user,
    required this.stats,
    this.badges = const [],
    this.uploadingAvatar = false,
    required this.onEditAvatar,
    required this.onShowQr,
  });

  final User? user;
  final List<Widget> badges;
  final List<ProfileStat> stats;
  final bool uploadingAvatar;
  final VoidCallback onEditAvatar;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 52),
            child: _GreenIdentityCard(
              user: user,
              badges: badges,
              uploadingAvatar: uploadingAvatar,
              onEditAvatar: onEditAvatar,
              onShowQr: onShowQr,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ProfileStatsCard(stats: stats),
          ),
        ],
      ),
    );
  }
}

/// Carte verte (#1A5B2E) : avatar, identité, badges et coordonnées.
class _GreenIdentityCard extends StatelessWidget {
  const _GreenIdentityCard({
    required this.user,
    required this.badges,
    required this.uploadingAvatar,
    required this.onEditAvatar,
    required this.onShowQr,
  });

  final User? user;
  final List<Widget> badges;
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
          ProfileAvatar(
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
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: badges,
                  ),
                ],
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
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
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

/// Bandeau blanc de statistiques, en chevauchement sous la carte verte.
class ProfileStatsCard extends StatelessWidget {
  const ProfileStatsCard({super.key, required this.stats});

  final List<ProfileStat> stats;

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
          for (final stat in stats)
            Expanded(child: _ProfileStatItem(stat: stat)),
        ],
      ),
    );
  }
}

/// Une colonne de statistique : icône teintée, chiffre, libellé.
class _ProfileStatItem extends StatelessWidget {
  const _ProfileStatItem({required this.stat});

  final ProfileStat stat;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: stat.tint,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm + 1),
            ),
            child: Icon(stat.icon, size: 18, color: stat.accent),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: stat.value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    height: 1.1,
                  ),
                ),
                if (stat.suffix != null)
                  TextSpan(
                    text: ' ${stat.suffix}',
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
            stat.label,
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
    );

    final onTap = stat.onTap;
    if (onTap == null) {
      return content;
    }
    return InkWell(onTap: onTap, child: content);
  }
}

// ------------------------------------------------------------------- menu

/// Une entrée du menu « Mon compte ».
class ProfileMenuEntry {
  const ProfileMenuEntry({
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
}

/// Carte-liste des entrées « Mon compte » (icône, titre, sous-titre, chevron).
class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({super.key, required this.entries});

  final List<ProfileMenuEntry> entries;

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
              for (var i = 0; i < entries.length; i++) ...[
                _MenuTile(entry: entries[i]),
                if (i < entries.length - 1)
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
  const _MenuTile({required this.entry});

  final ProfileMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: entry.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: entry.tint,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm + 3),
        ),
        child: Icon(entry.icon, size: 19, color: entry.accent),
      ),
      title: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      subtitle: Text(
        entry.subtitle,
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

/// Section « Espaces accessibles » : bascule vers les autres rôles
/// (client / vendeur / livreur) de l'utilisateur.
class ProfileSpacesMenu extends StatelessWidget {
  const ProfileSpacesMenu({
    super.key,
    required this.session,
    required this.currentContext,
  });

  final SessionProvider session;
  final String currentContext;

  static const _items = <(String, IconData, String, String, String)>[
    (
      AppContext.client,
      Icons.shopping_bag_outlined,
      'Espace client',
      'Commandes, favoris, coupons...',
      '/client',
    ),
    (
      AppContext.vendor,
      Icons.storefront_outlined,
      'Espace vendeur',
      'Produits, commandes, statistiques...',
      '/vendor',
    ),
    (
      AppContext.driver,
      Icons.delivery_dining_outlined,
      'Espace livreur',
      'Missions, disponibilité, gains...',
      '/driver',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = session.user;
    final items = _items
        .where(
          (item) =>
              item.$1 != currentContext &&
              (user?.contexts.contains(item.$1) ?? false),
        )
        .toList();

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
              for (var i = 0; i < items.length; i++) ...[
                _MenuTile(
                  entry: ProfileMenuEntry(
                    icon: items[i].$2,
                    tint: AppColors.greenLight,
                    accent: AppColors.green,
                    title: items[i].$3,
                    subtitle: items[i].$4,
                    onTap: () {
                      session.switchRole(items[i].$1);
                      context.go(items[i].$5);
                    },
                  ),
                ),
                if (i < items.length - 1)
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

// ------------------------------------------------------------- déconnexion

/// Bouton « Se déconnecter » pleine largeur (fond orange très clair).
class ProfileLogoutButton extends StatelessWidget {
  const ProfileLogoutButton({super.key, required this.onConfirm});

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

// --------------------------------------------------------------------- QR

/// Feuille « Ma carte de contact » : QR MECARD (nom, téléphone, e-mail).
void showContactQrSheet(BuildContext context, User? user) {
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
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
