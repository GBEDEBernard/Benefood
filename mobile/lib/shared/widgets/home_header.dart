import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// En-tête d'accueil premium Béninfood : salut personnalisé, sous-titre,
/// pastille de marque et actions carrées arrondies.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String subtitle;

  /// Pastille à gauche du salut (logo, icône de rôle…).
  final Widget? leading;

  /// Boutons d'action carrés (48×48, fond blanc, bordure chaude).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          12,
          AppDimens.pagePadding,
          4,
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            for (final action in actions) ...[const SizedBox(width: 8), action],
          ],
        ),
      ),
    );
  }
}

/// Bouton d'action carré arrondi pour [HomeHeader].
class HomeHeaderAction extends StatelessWidget {
  const HomeHeaderAction({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Icon(icon, size: 21, color: AppColors.text),
    );
    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: IconButton(onPressed: onPressed, icon: button),
      );
    }
    return IconButton(onPressed: onPressed, icon: button);
  }
}

/// Pastille d'icône réutilisée (accueil livreur / vendeur).
class HomeBadgeIcon extends StatelessWidget {
  const HomeBadgeIcon({
    super.key,
    required this.icon,
    this.color = AppColors.orange,
    this.background = AppColors.orangeLight,
    this.size = 48,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Tuile de statistique premium : valeur en couleur d'accent + libellé discret.
class HomeStatTile extends StatelessWidget {
  const HomeStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accent = AppColors.orange,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  Color get _background {
    if (identical(accent, AppColors.orange)) return AppColors.orangeLight;
    if (identical(accent, AppColors.green)) return AppColors.greenLight;
    if (identical(accent, AppColors.goldDark)) return AppColors.goldLight;
    return AppColors.surfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
