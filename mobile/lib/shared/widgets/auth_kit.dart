import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// Kit visuel partagé par les écrans d'authentification (connexion,
/// inscription, mot de passe oublié…) : même bandeau orange, même panneau
/// blanc, mêmes champs et mêmes boutons que l'écran d'accueil Béninfood.
///
/// Page fixe, jamais de scroll : la hauteur libre est remplie par le panneau
/// et le contenu est réduit (scaleDown) s'il déborde, quel que soit l'écran.

/// Route de l'écran d'accueil (bouton retour quand il n'y a pas d'historique).
const String kLandingRoute = '/';

/// Palette de l'authentification (relevée sur la maquette).
class AuthColors {
  const AuthColors._();

  static const Color gradLight = Color(0xFFFA9409);
  static const Color gradMid = Color(0xFFF96A04);
  static const Color gradDeep = Color(0xFFE24B02);
  static const Color brand = Color(0xFFFE5C01);
  static const Color ink = Color(0xFF1C1C1E);
  static const Color muted = Color(0xFF6B6B70);
  static const Color fieldFill = Color(0xFFF5F5F7);
  static const Color danger = Color(0xFFD93025);
}

const double _panelRadius = 34;
const double _contentMaxWidth = 440;
const double _bowlOverlap = 56;

/// Image du bol (PNG transparent, bol de légumes).
const String _bowlAsset = 'assets/landing/bowl_left.png';
const double _bowlAspect = 865 / 1200;

// ---------------------------------------------------------------------------
// Structure d'écran
// ---------------------------------------------------------------------------

/// Écran d'authentification : bandeau orange + panneau blanc fixe.
///
/// - [hero] = true : grand bol de légumes qui déborde sur le panneau, titre
///   centré dans le panneau (connexion).
/// - [hero] = false : en-tête compact avec le titre en blanc (formulaires
///   longs comme l'inscription).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.hero = false,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool hero;
  final VoidCallback? onBack;

  void _defaultBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(kLandingRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, c) {
          final topInset = MediaQuery.paddingOf(context).top;
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          final maxW = math.min(c.maxWidth, _contentMaxWidth);

          final bowlW = (maxW * 0.68).clamp(210.0, 300.0);
          final bowlH = bowlW * _bowlAspect;
          final bowlTop = topInset + 60;
          final panelTop = hero ? bowlTop + bowlH - _bowlOverlap : topInset + 212;
          final panelPadTop = hero ? _bowlOverlap + 20 : 28.0;
          final contentW = (maxW - 48).clamp(0.0, double.infinity);

          final back = onBack ?? () => _defaultBack(context);

          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: panelTop + _panelRadius + 24,
                child: const _Backdrop(),
              ),
              // Page fixe : le panneau remplit la hauteur libre et le formulaire
              // est réduit (scaleDown) s'il déborde, pour ne jamais scroller.
              Column(
                children: [
                  SizedBox(
                    height: panelTop,
                    child: _TopBar(
                      topInset: topInset,
                      onBack: back,
                      title: hero ? null : title,
                      subtitle: hero ? null : subtitle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(_panelRadius),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 24,
                            offset: Offset(0, -6),
                          ),
                        ],
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24, panelPadTop, 24, 24 + bottomInset),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: contentW,
                                child: _Reveal(
                                    duration: const Duration(milliseconds: 650),
                                    dy: 22,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (hero) ...[
                                          Text(
                                            title,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.4,
                                              color: AuthColors.ink,
                                              height: 1.1,
                                            ),
                                          ),
                                          if (subtitle != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              subtitle!,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                color: AuthColors.muted,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 28),
                                        ],
                                        child,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (hero)
                Positioned(
                  top: bowlTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _Reveal(
                      duration: const Duration(milliseconds: 800),
                      dy: 26,
                      scaleFrom: 0.9,
                      child: _Bowl(width: bowlW),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Bouton retour, petit logo et (mode compact) titre blanc.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.topInset,
    required this.onBack,
    this.title,
    this.subtitle,
  });

  final double topInset;
  final VoidCallback onBack;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, topInset + 10, 24, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onBack,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33A83C00),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Image.asset(
                          'assets/Logo.jpeg',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.storefront,
                            size: 28,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (title != null) ...[
                // Titre + sous-titre alignés en bas, réduits si l'espace manque.
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Bowl extends StatelessWidget {
  const _Bowl({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: width * _bowlAspect,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: width * 0.14,
              right: width * 0.14,
              bottom: 6,
              height: 12,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(40)),
                  boxShadow: [
                    BoxShadow(color: Color(0x55000000), blurRadius: 24, spreadRadius: 1),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                _bowlAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AuthColors.gradLight, AuthColors.gradMid, AuthColors.gradDeep],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(painter: _BackdropPainter()),
    );
  }
}

/// Cercles doux et quelques icônes de cuisine en filigrane.
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final soft = Paint()..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawCircle(Offset(size.width * 0.95, size.height * 0.05), size.height * 0.45, soft);
    canvas.drawCircle(Offset(-size.width * 0.05, size.height * 0.7), size.height * 0.38, soft);

    final ink = Colors.white.withValues(alpha: 0.15);
    _glyph(canvas, Icons.restaurant_menu, Offset(size.width * 0.14, size.height * 0.34), 52, ink, -0.3);
    _glyph(canvas, Icons.eco_outlined, Offset(size.width * 0.30, size.height * 0.14), 36, ink, -0.5);
    _glyph(canvas, Icons.ramen_dining_outlined, Offset(size.width * 0.88, size.height * 0.42), 50, ink, 0.2);
    _glyph(canvas, Icons.soup_kitchen_outlined, Offset(size.width * 0.68, size.height * 0.12), 40, ink, 0.25);
  }

  void _glyph(Canvas c, IconData icon, Offset at, double size, Color color, double rot) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
    )..layout();
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(rot);
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
}

/// Apparition douce : fondu + léger glissement (+ zoom optionnel), une seule fois.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.dy = 24,
    this.scaleFrom = 1.0,
  });

  final Widget child;
  final Duration duration;
  final double dy;
  final double scaleFrom;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * dy),
          child: Transform.scale(
            scale: scaleFrom + (1 - scaleFrom) * v,
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Composants de formulaire
// ---------------------------------------------------------------------------

/// Champ avec libellé au-dessus : fond gris clair, icône qui passe à l'orange
/// au focus, halo discret. [isPassword] ajoute l'œil afficher/masquer.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.isPassword = false,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool isPassword;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final _focus = FocusNode();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  OutlineInputBorder _border(Color? color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: color == null ? BorderSide.none : BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AuthColors.ink,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: AuthColors.brand.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.isPassword && _obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            validator: widget.validator,
            onFieldSubmitted: widget.onSubmitted,
            cursorColor: AuthColors.brand,
            style: const TextStyle(
              fontSize: 15.5,
              color: AuthColors.ink,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: AuthColors.muted.withValues(alpha: 0.7),
                fontSize: 15,
              ),
              filled: true,
              fillColor: AuthColors.fieldFill,
              prefixIcon: Icon(
                widget.icon,
                size: 22,
                color: focused ? AuthColors.brand : AuthColors.muted,
              ),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      tooltip: _obscure ? 'Afficher' : 'Masquer',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AuthColors.muted,
                        size: 22,
                      ),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              border: _border(null, 0),
              enabledBorder: _border(null, 0),
              focusedBorder: _border(AuthColors.brand, 1.6),
              errorBorder: _border(AuthColors.danger, 1.2),
              focusedErrorBorder: _border(AuthColors.danger, 1.6),
              errorStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bouton principal : dégradé orange, ombre, roue de chargement.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFF7A1A), AuthColors.brand],
          ),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AuthColors.brand.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: loading ? null : onPressed,
          child: SizedBox(
            height: 54,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 21, color: Colors.white),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

/// Rappel des trois promesses de l'accueil : COMMANDEZ / PAYEZ / RECEVEZ.
class AuthPromises extends StatelessWidget {
  const AuthPromises({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Promise(icon: Icons.shopping_cart_outlined, label: 'COMMANDEZ'),
        _Promise(icon: Icons.payments_outlined, label: 'PAYEZ'),
        _Promise(icon: Icons.check_circle_outline, label: 'RECEVEZ'),
      ],
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Color(0x14FE5C01),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 21, color: AuthColors.brand),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AuthColors.muted,
          ),
        ),
      ],
    );
  }
}

/// Petite mention « Connexion sécurisée » en bas de formulaire.
class AuthSecureNote extends StatelessWidget {
  const AuthSecureNote({super.key, this.text = 'Connexion sécurisée'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 15, color: AuthColors.muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AuthColors.muted),
          ),
        ),
      ],
    );
  }
}