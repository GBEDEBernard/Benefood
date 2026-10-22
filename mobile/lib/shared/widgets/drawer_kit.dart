import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'app_network_image.dart';
import 'food_decor.dart';

/// Palette chaude commune aux tiroirs latéraux premium de l'application
/// (espace livreur, espace client).
///
/// Dominante orange sur fond crème : typographie brun très foncé, textes
/// secondaires warm et contours sable.
class DrawerPalette {
  const DrawerPalette._();

  /// Titres et libellés principaux.
  static const Color ink = Color(0xFF2B1608);

  /// Textes secondaires (sous-titres, sections).
  static const Color muted = Color(0xFF6B5645);

  /// Contour chaud des éléments inactifs.
  static const Color line = Color(0xFFF0E2D2);

  /// Fond de l'élément actif (pilule orange claire).
  static const Color wash = Color(0xFFFFF0E0);

  /// Pied de tiroir.
  static const Color footer = Color(0xFFB09A86);

  /// Bloc de déconnexion.
  static const Color logoutBackground = Color(0xFFFFEFEA);
  static const Color logoutBorder = Color(0xFFF6D9CC);
  static const Color logoutIcon = Color(0xFFCE5738);
  static const Color logoutLabel = Color(0xFF9D422C);
  static const Color logoutChevron = Color(0xFFCE8B75);
}

/// Entrée en cascade : fondu + glissement depuis la gauche.
class DrawerStagger extends StatelessWidget {
  const DrawerStagger({super.key, required this.index, required this.child});

  /// Position dans la cascade (plus la valeur est haute, plus l'entrée est
  /// tardive).
  final int index;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 340 + index * 55),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(-26 * (1 - value), 0),
          child: child,
        ),
      ),
    );
  }
}

/// Pastille translucide en haut de la carte d'identité (« ESPACE LIVREUR »,
/// « ESPACE CLIENT »…).
class DrawerBadge extends StatelessWidget {
  const DrawerBadge({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Décor « food » des bannières de tiroir : le bol garni et les herbes
/// (piment, persil, basilic) sont posés en fond de carte, estompés dans le
/// dégradé pour apporter une touche « food photography » sans jamais nuire
/// à la lisibilité du texte.
class DrawerFoodDecor extends StatelessWidget {
  const DrawerFoodDecor({
    super.key,
    this.intensity = 1,
    this.compact = false,
  });

  /// 0 → décor invisible, 1 → opacité nominale.
  final double intensity;

  /// Écrans bas : gabarit allégé.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: FoodDecor(
          bowlOpacity: 0.22 * intensity,
          herbsOpacity: 0.18 * intensity,
          bowlWidth: compact ? 128 : 172,
          herbsWidth: compact ? 92 : 120,
          bowlRight: -30,
          bowlBottom: -34,
          herbsRight: -14,
          herbsTop: -24,
        ),
      ),
    );
  }
}

/// Reflet mobile qui traverse la carte d'identité.
class DrawerSheen extends StatelessWidget {
  const DrawerSheen({super.key, required this.t});

  /// Position de l'animation (0 → 1).
  final double t;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment(-1.9 + 3.8 * t, 0),
          child: Transform.rotate(
            angle: 0.35,
            child: Container(
              width: 70,
              height: 420,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bulle flottante décorative de la carte d'identité.
class DrawerBubble extends StatelessWidget {
  const DrawerBubble({
    super.key,
    required this.t,
    required this.size,
    required this.alpha,
    required this.phase,
    this.left,
    this.right,
    this.top,
    this.bottom,
  });

  final double t;
  final double size;
  final double alpha;
  final double phase;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    final a = (t + phase) * 2 * math.pi;
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Transform.translate(
        offset: Offset(8 * math.sin(a), 7 * math.cos(a)),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: alpha),
          ),
        ),
      ),
    );
  }
}

/// Avatar dans un anneau qui tourne : photo de profil ou initiales.
class DrawerAvatar extends StatelessWidget {
  const DrawerAvatar({
    super.key,
    required this.url,
    required this.name,
    required this.t,
    required this.size,
  });

  final String? url;
  final String name;
  final double t;
  final double size;

  @override
  Widget build(BuildContext context) {
    final raw = url;
    final resolved =
        (raw == null || raw.trim().isEmpty) ? null : resolveMediaUrl(raw);

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          transform: GradientRotation(t * 2 * math.pi),
          colors: const [
            Colors.white,
            Color(0xFFFFD9A8),
            Color(0xFFFFF4E6),
            Colors.white,
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: AppColors.orangeDark,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: resolved != null
              ? Image.network(
                  resolved,
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
      color: AppColors.orangeLight,
      child: Center(
        child: Text(
          initials(name),
          style: TextStyle(
            color: AppColors.orangeDark,
            fontSize: size * 0.31,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  /// Initiales du nom (« Jean Koffi » → « JK »).
  static String initials(String name) {
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

/// Pastille d'état sur la carte d'identité : fond blanc et point coloré
/// quand l'état est favorable, fond translucide sinon.
class DrawerStatusPill extends StatelessWidget {
  const DrawerStatusPill({
    super.key,
    required this.label,
    required this.active,
    required this.dotColor,
    required this.textColor,
    required this.t,
    this.pulse = true,
  });

  final String label;

  /// `true` : fond blanc, point `dotColor`, texte `textColor`.
  /// `false` : fond sombre translucide, texte blanc.
  final bool active;

  final Color dotColor;
  final Color textColor;
  final double t;

  /// Anime le point lorsque l'état est favorable.
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final wave = (math.sin(t * 2 * math.pi * 6) + 1) / 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (active && pulse)
                  Container(
                    width: 7 + 7 * wave,
                    height: 7 + 7 * wave,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor.withValues(alpha: 0.4 * (1 - wave)),
                    ),
                  ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? dotColor : const Color(0xFFE8D8C8),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: active ? textColor : Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille blanche de statut en bas de la carte d'identité.
class DrawerStatusChip extends StatelessWidget {
  const DrawerStatusChip({
    super.key,
    required this.label,
    required this.dotColor,
    this.textColor = AppColors.orangeDark,
  });

  final String label;
  final Color dotColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'identité animée : dégradé qui tourne, bulles flottantes, reflet,
/// avatar à anneau rotatif et bandeau de contact.
class DrawerIdentityCard extends StatefulWidget {
  const DrawerIdentityCard({
    super.key,
    required this.badgeIcon,
    required this.badgeLabel,
    required this.avatarUrl,
    required this.name,
    required this.pillBuilder,
    required this.footerIcon,
    required this.footerText,
    this.trailing,
    this.compact = false,
  });

  final IconData badgeIcon;
  final String badgeLabel;

  final String? avatarUrl;
  final String name;

  /// Pastille d'état (construite par l'appelant avec la position de
  /// l'animation pour rester générique).
  final Widget Function(double t) pillBuilder;

  final IconData footerIcon;
  final String footerText;

  /// Pastille de statut optionnelle en fin de bandeau.
  final Widget? trailing;

  /// Mode compact (écrans bas) : hauteur réduite, sous-titres masqués.
  final bool compact;

  @override
  State<DrawerIdentityCard> createState() => _DrawerIdentityCardState();
}

class _DrawerIdentityCardState extends State<DrawerIdentityCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final angle = math.pi / 4 + 0.6 * math.sin(t * 2 * math.pi);

        return Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: Alignment(math.cos(angle), math.sin(angle)),
              end: Alignment(-math.cos(angle), -math.sin(angle)),
              colors: const [
                AppColors.orange,
                AppColors.orangeDark,
                Color(0xFFFF9A3D),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.38),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              DrawerBubble(
                t: t,
                size: 120,
                alpha: 0.13,
                phase: 0.0,
                right: -34,
                top: -38,
              ),
              DrawerBubble(
                t: t,
                size: 90,
                alpha: 0.09,
                phase: 0.4,
                left: -30,
                bottom: -44,
              ),
              DrawerBubble(
                t: t,
                size: 34,
                alpha: 0.12,
                phase: 0.7,
                right: 60,
                bottom: 40,
              ),
              DrawerFoodDecor(compact: compact),
              DrawerSheen(t: t),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  compact ? 14 : 18,
                  14,
                  compact ? 13 : 17,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DrawerBadge(
                      icon: widget.badgeIcon,
                      label: widget.badgeLabel,
                    ),
                    SizedBox(height: compact ? 10 : 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        DrawerAvatar(
                          url: widget.avatarUrl,
                          name: widget.name,
                          t: t,
                          size: compact ? 54 : 64,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.18,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              widget.pillBuilder(t),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 10 : 15),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    SizedBox(height: compact ? 9 : 12),
                    Row(
                      children: [
                        Icon(
                          widget.footerIcon,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.footerText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (widget.trailing != null) ...[
                          const SizedBox(width: 6),
                          widget.trailing!,
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Titre de section du tiroir : libellé majusculé + barre d'accentuation.
class DrawerSectionHeader extends StatelessWidget {
  const DrawerSectionHeader({
    super.key,
    required this.label,
    this.trailing,
  });

  final String label;

  /// Barre d'accentuation à droite du libellé (masquée si `null`).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: DrawerPalette.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.7,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// Barre d'accentuation animée du titre de section.
class DrawerAccentBar extends StatelessWidget {
  const DrawerAccentBar({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Container(
        width: 26 * v,
        height: 3,
        decoration: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

/// Ligne de navigation : pilule orange claire, icône qui s'illumine,
/// barre d'accent et légère réduction à l'appui.
class DrawerNavTile extends StatefulWidget {
  const DrawerNavTile({
    super.key,
    required this.label,
    required this.subtitle,
    required this.outline,
    required this.filled,
    required this.active,
    required this.compact,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final String subtitle;

  /// Icône de l'état inactif.
  final IconData outline;

  /// Icône de l'état actif.
  final IconData filled;

  final bool active;
  final bool compact;
  final VoidCallback onTap;

  /// Compteur affiché en badge sur l'icône (0 = aucun).
  final int badge;

  @override
  State<DrawerNavTile> createState() => _DrawerNavTileState();
}

class _DrawerNavTileState extends State<DrawerNavTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    const duration = Duration(milliseconds: 260);

    return AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: active ? DrawerPalette.wash : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: active
                ? AppColors.orange.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            splashColor: AppColors.orange.withValues(alpha: 0.14),
            highlightColor: Colors.transparent,
            onHighlightChanged: (v) => setState(() => _down = v),
            onTap: widget.onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: widget.compact ? 7 : 10,
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: active ? AppColors.orange : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: active ? AppColors.orange : DrawerPalette.line,
                          ),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: AppColors.orange.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ]
                              : const [],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: Icon(
                            active ? widget.filled : widget.outline,
                            key: ValueKey(active),
                            color: active ? Colors.white : AppColors.orangeDark,
                            size: 22,
                          ),
                        ),
                      ),
                      if (widget.badge > 0)
                        Positioned(
                          top: -7,
                          right: -7,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 21,
                              minHeight: 21,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              widget.badge > 99 ? '99+' : '${widget.badge}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: duration,
                          style: TextStyle(
                            color: active ? AppColors.orangeDark : DrawerPalette.ink,
                            fontSize: 13.5,
                            fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                          ),
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!widget.compact) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: DrawerPalette.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutBack,
                    width: active ? 26 : 0,
                    height: active ? 26 : 0,
                    decoration: const BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: active
                        ? const Icon(Icons.chevron_right_rounded,
                            color: Colors.white, size: 19)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tuile d'accès rapide : apparaît avec un rebond, réduction à l'appui.
class DrawerQuickAction extends StatefulWidget {
  const DrawerQuickAction({
    super.key,
    required this.index,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  /// Position dans la rangée (décale l'animation d'apparition).
  final int index;

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<DrawerQuickAction> createState() => _DrawerQuickActionState();
}

class _DrawerQuickActionState extends State<DrawerQuickAction> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 1000 + widget.index * 150),
      curve: Interval(0.3 + widget.index * 0.08, 1.0, curve: Curves.elasticOut),
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            splashColor: widget.color.withValues(alpha: 0.16),
            highlightColor: Colors.transparent,
            onHighlightChanged: (v) => setState(() => _down = v),
            onTap: widget.onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 88),
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: DrawerPalette.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 20),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                        color: DrawerPalette.ink,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloc de déconnexion (l'action elle-même est gérée par l'appelant).
class DrawerLogoutButton extends StatelessWidget {
  const DrawerLogoutButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Material(
        color: DrawerPalette.logoutBackground,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          splashColor: const Color(0xFFCE5738).withValues(alpha: 0.14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: DrawerPalette.logoutBorder),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: DrawerPalette.logoutIcon,
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Se déconnecter',
                    style: TextStyle(
                      color: DrawerPalette.logoutLabel,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: DrawerPalette.logoutChevron,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
