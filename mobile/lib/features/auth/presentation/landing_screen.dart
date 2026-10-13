import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/theme/app_colors.dart';

/// Couleurs relevées sur la maquette « écran chaleureux ».
/// Le dégradé est plus clair en haut à droite et plus profond en bas à gauche.
const Color _gradLight = Color(0xFFFA9409);
const Color _gradMid = Color(0xFFF96A04);
const Color _gradDeep = Color(0xFFE24B02);
const Color _buttonOrange = Color(0xFFFE5C01);

/// Part de la hauteur d'écran occupée par le panneau blanc (maquette : ~48 %).
const double _panelRatio = 0.48;

/// Écran d'accueil avant connexion (J19 §2.2) — identité de marque Béninfood.
///
/// Composition de la maquette :
/// - **haut** : dégradé orange, dessins « line-art » blancs translucides,
///   roue de réglages en haut à droite ;
/// - **centre** : carte blanche carrée aux coins très arrondis contenant
///   uniquement le logo (qui porte déjà « BéninFood » et COMMANDEZ | PAYEZ |
///   RECEVEZ), puis « Béninfood » en blanc et les deux lignes d'accroche ;
/// - **bas** : panneau blanc à grands coins supérieurs arrondis, semis de
///   dessins orange très pâles, boutons « Se connecter » et « Créer un
///   compte », lien « Mot de passe oublié ? ».
///
/// Images (PNG transparents découpés dans la maquette, déclarés dans le
/// pubspec avec `- assets/landing/`) :
/// - `assets/landing/bowl_left.png`   : bol garni, basilic et piment, bord gauche ;
/// - `assets/landing/herbs_right.png` : piment rouge, persil et basilic, bord droit.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key, required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final panelH = (h * _panelRatio).clamp(300.0, 560.0);

          return Stack(
            children: [
              // Dégradé : descend un peu sous le panneau pour remplir les
              // coins arrondis du haut du panneau.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: panelH - 60,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [_gradLight, _gradMid, _gradDeep],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: panelH,
                child: _TopZone(width: w),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: panelH,
                child: _ActionsPanel(width: w),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Partie orange : dessins, photos, réglages et bloc de marque.
class _TopZone extends StatelessWidget {
  const _TopZone({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _TopDecorPainter())),
        // Bol (avec oignon, carottes, poulet), basilic et piment : bord gauche.
        // Découpés dans la maquette : 210 px de large sur 941 px.
        Positioned(
          left: 0,
          bottom: 6,
          child: Image.asset(
            'assets/landing/bowl_left.png',
            width: width * (210 / 941),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        // Piment rouge, persil et basilic : bord droit (199 px sur 941 px).
        Positioned(
          right: 0,
          bottom: 6,
          child: Image.asset(
            'assets/landing/herbs_right.png',
            width: width * (199 / 941),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 12),
                  child: IconButton(
                    tooltip: 'Réglages du serveur',
                    onPressed: () => context.go('/server'),
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  // `scaleDown` évite tout débordement sur les petits écrans.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _Hero(width: width),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Logo dans sa carte, titre et accroches.
class _Hero extends StatelessWidget {
  const _Hero({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final cardSize = (width * 0.387).clamp(120.0, 190.0);
    final radius = cardSize * 0.22;
    final titleSize = (width * 0.1).clamp(34.0, 46.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: cardSize,
          height: cardSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40A83C00),
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: EdgeInsets.all(cardSize * 0.05),
              child: Image.asset(
                'assets/Logo.jpeg',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.storefront,
                  size: 64,
                  color: AppColors.orange,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Béninfood',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Commandez, payez, recevez.\nLe goût du Bénin livré chez vous.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            height: 1.3,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Panneau blanc du bas (grands coins supérieurs arrondis).
class _ActionsPanel extends StatelessWidget {
  const _ActionsPanel({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final cornerRadius = Radius.circular(width * 0.1);
    final hPad = width * 0.134;
    final buttonHeight = (width * 0.125).clamp(48.0, 56.0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: cornerRadius),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, -6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: cornerRadius),
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.white)),
            const Positioned.fill(child: CustomPaint(painter: _PanelDecorPainter())),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, width * 0.17, hPad, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PillButton(
                    label: 'Se connecter',
                    icon: Icons.login,
                    height: buttonHeight,
                    onPressed: () => context.go('/login'),
                  ),
                  const SizedBox(height: 18),
                  _PillButton(
                    label: 'Créer un compte',
                    icon: Icons.person_add_alt_outlined,
                    height: buttonHeight,
                    filled: false,
                    onPressed: () => context.go('/register'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.go('/reset-password'),
                    style: TextButton.styleFrom(
                      foregroundColor: _buttonOrange,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text(
                      'Mot de passe oublié ?',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton du panneau : plein (orange) ou contour (blanc bordé orange).
/// Coins légèrement arrondis comme sur la maquette (pas en « pilule »).
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.height,
    this.filled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double height;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(
        label,
        maxLines: 1,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(height),
        backgroundColor: filled ? _buttonOrange : Colors.white,
        foregroundColor: filled ? Colors.white : _buttonOrange,
        side: filled ? BorderSide.none : const BorderSide(color: _buttonOrange, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: filled ? 3 : 0,
        shadowColor: _buttonOrange.withValues(alpha: 0.45),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dessins (line-art) — positions relevées sur la maquette (941 px de large).
// ---------------------------------------------------------------------------

/// Dessins blancs translucides sur le dégradé. Référence : 941 × 868 px.
class _TopDecorPainter extends CustomPainter {
  const _TopDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final sc = size.width / 941;
    Offset f(double x, double y) => Offset(x * sc, y / 868 * size.height);

    final lineWidth = math.max(1.2, 3.4 * sc);
    final line = _stroke(Colors.white.withValues(alpha: 0.28), lineWidth);
    final dot = Colors.white.withValues(alpha: 0.38);

    _at(canvas, f(65, 135), -0.15, () => _chefHat(canvas, 100 * sc, line));
    _at(canvas, f(220, 165), 0.5, () => _leaf(canvas, 100 * sc, line));
    _at(canvas, f(118, 292), 0.8, () => _chili(canvas, 130 * sc, line));
    _glyph(canvas, Icons.soup_kitchen_outlined, f(85, 500), 150 * sc,
        Colors.white.withValues(alpha: 0.22));

    _at(canvas, f(880, 335), -0.5, () => _fork(canvas, 240 * sc, line));
    _at(canvas, f(810, 395), -0.55, () => _spoon(canvas, 250 * sc, line));
    _at(canvas, f(772, 455), 0.3, () => _leaf(canvas, 90 * sc, line));
    _at(canvas, f(838, 588), 0, () => _tomato(canvas, 150 * sc, line));

    // Petites feuilles vertes colorées.
    _at(canvas, f(182, 378), 0.6,
        () => _leafFilled(canvas, 42 * sc, const Color(0xFFB5D957)));
    _at(canvas, f(735, 185), 0.8,
        () => _leafFilled(canvas, 56 * sc, const Color(0xFF6FB04A)));

    // Points décoratifs.
    for (final d in const [
      [133.0, 185.0, 5.0],
      [50.0, 267.0, 6.0],
      [213.0, 281.0, 6.0],
      [75.0, 228.0, 4.0],
      [115.0, 402.0, 5.0],
      [767.0, 660.0, 6.0],
      [908.0, 463.0, 4.0],
    ]) {
      canvas.drawCircle(f(d[0], d[1]), d[2] * sc, _fill(dot));
    }
  }

  @override
  bool shouldRepaint(_TopDecorPainter oldDelegate) => false;
}

/// Dessins orange très pâles du panneau blanc. Référence : 941 × 804 px
/// (le panneau commence à y = 868 dans la maquette).
class _PanelDecorPainter extends CustomPainter {
  const _PanelDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final sc = size.width / 941;
    Offset f(double x, double y) => Offset(x * sc, (y - 868) / 804 * size.height);

    final ink = _buttonOrange.withValues(alpha: 0.16);
    final line = _stroke(ink, math.max(1.1, 3.0 * sc));
    final dot = _buttonOrange.withValues(alpha: 0.22);

    _glyph(canvas, Icons.room_service_outlined, f(62, 1012), 90 * sc, ink, -0.25);
    _at(canvas, f(52, 1195), -0.4, () => _leaf(canvas, 80 * sc, line));
    _at(canvas, f(92, 1500), -0.6, () => _board(canvas, 270 * sc, line));
    _at(canvas, f(185, 1460), 0.3, () => _chili(canvas, 110 * sc, line));
    _at(canvas, f(268, 1610), 1.2, () => _leaf(canvas, 100 * sc, line));
    _at(canvas, f(575, 1583), 0, () => _tomato(canvas, 150 * sc, line));
    _at(canvas, f(800, 1535), 0.6, () => _knife(canvas, 330 * sc, line));
    _at(canvas, f(848, 1388), 0.1, () => _bellPepper(canvas, 130 * sc, line));
    _at(canvas, f(883, 1285), -0.2, () => _leaf(canvas, 70 * sc, line));
    _glyph(canvas, Icons.rice_bowl_outlined, f(905, 1100), 95 * sc, ink);

    // Points : [x, y, rayon, plein ?]
    for (final d in const [
      [73.0, 934.0, 7.0, 1.0],
      [75.0, 1098.0, 7.0, 0.0],
      [45.0, 1310.0, 6.0, 1.0],
      [73.0, 1363.0, 6.0, 0.0],
      [240.0, 1535.0, 6.0, 1.0],
      [676.0, 1608.0, 6.0, 1.0],
      [725.0, 1604.0, 6.0, 0.0],
      [850.0, 953.0, 7.0, 0.0],
      [902.0, 1225.0, 7.0, 1.0],
      [905.0, 1470.0, 4.0, 1.0],
    ]) {
      final p = f(d[0], d[1]);
      if (d[3] == 1.0) {
        canvas.drawCircle(p, d[2] * sc, _fill(dot));
      } else {
        canvas.drawCircle(p, d[2] * sc, _stroke(dot, math.max(1.0, 2.6 * sc)));
      }
    }
  }

  @override
  bool shouldRepaint(_PanelDecorPainter oldDelegate) => false;
}

// ----------------------------- Outils de dessin ----------------------------

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _fill(Color color) => Paint()..color = color;

/// Dessine en repère local centré sur [at], tourné de [rot] radians.
void _at(Canvas c, Offset at, double rot, VoidCallback draw) {
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(rot);
  draw();
  c.restore();
}

/// Icône Material utilisée comme dessin.
void _glyph(Canvas c, IconData icon, Offset at, double size, Color color,
    [double rot = 0]) {
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

void _leaf(Canvas c, double s, Paint p) {
  final path = Path()
    ..moveTo(0, -s / 2)
    ..quadraticBezierTo(s * 0.42, -s * 0.1, 0, s / 2)
    ..quadraticBezierTo(-s * 0.42, -s * 0.1, 0, -s / 2);
  c.drawPath(path, p);
  c.drawLine(Offset(0, -s * 0.38), Offset(0, s * 0.5), p);
  for (final k in const [-0.12, 0.08, 0.26]) {
    c.drawLine(Offset(0, s * k), Offset(s * 0.18, s * (k - 0.12)), p);
    c.drawLine(Offset(0, s * k), Offset(-s * 0.18, s * (k - 0.12)), p);
  }
}

void _leafFilled(Canvas c, double s, Color color) {
  final path = Path()
    ..moveTo(0, -s / 2)
    ..quadraticBezierTo(s * 0.5, -s * 0.05, 0, s / 2)
    ..quadraticBezierTo(-s * 0.5, -s * 0.05, 0, -s / 2);
  c.drawPath(path, _fill(color));
  c.drawLine(
    Offset(0, -s * 0.35),
    Offset(0, s * 0.45),
    _stroke(Colors.white.withValues(alpha: 0.55), math.max(0.8, s * 0.04)),
  );
}

void _chili(Canvas c, double s, Paint p) {
  final body = Path()
    ..moveTo(-s * 0.10, -s * 0.45)
    ..cubicTo(s * 0.30, -s * 0.40, s * 0.25, s * 0.20, -s * 0.15, s * 0.48)
    ..cubicTo(s * 0.05, s * 0.15, 0, -s * 0.15, -s * 0.10, -s * 0.45);
  c.drawPath(body, p);
  c.drawLine(Offset(-s * 0.10, -s * 0.45), Offset(-s * 0.24, -s * 0.54), p);
}

void _tomato(Canvas c, double s, Paint p) {
  c.drawCircle(Offset(0, s * 0.05), s * 0.4, p);
  final crown = Path()
    ..moveTo(-s * 0.18, -s * 0.32)
    ..lineTo(-s * 0.06, -s * 0.42)
    ..lineTo(0, -s * 0.30)
    ..lineTo(s * 0.08, -s * 0.44)
    ..lineTo(s * 0.18, -s * 0.30);
  c.drawPath(crown, p);
}

void _chefHat(Canvas c, double s, Paint p) {
  final hat = Path()
    ..moveTo(-s * 0.28, s * 0.18)
    ..cubicTo(-s * 0.5, s * 0.12, -s * 0.5, -s * 0.28, -s * 0.2, -s * 0.28)
    ..cubicTo(-s * 0.15, -s * 0.5, s * 0.15, -s * 0.5, s * 0.2, -s * 0.28)
    ..cubicTo(s * 0.5, -s * 0.28, s * 0.5, s * 0.12, s * 0.28, s * 0.18);
  c.drawPath(hat, p);
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-s * 0.28, s * 0.18, s * 0.56, s * 0.2),
      Radius.circular(s * 0.04),
    ),
    p,
  );
}

void _fork(Canvas c, double s, Paint p) {
  final head = Path()
    ..moveTo(-s * 0.14, -s * 0.5)
    ..lineTo(-s * 0.14, -s * 0.1)
    ..quadraticBezierTo(-s * 0.14, s * 0.05, 0, s * 0.05)
    ..quadraticBezierTo(s * 0.14, s * 0.05, s * 0.14, -s * 0.1)
    ..lineTo(s * 0.14, -s * 0.5);
  c.drawPath(head, p);
  c.drawLine(Offset(-s * 0.047, -s * 0.5), Offset(-s * 0.047, -s * 0.1), p);
  c.drawLine(Offset(s * 0.047, -s * 0.5), Offset(s * 0.047, -s * 0.1), p);
  final handle = Path()
    ..moveTo(-s * 0.045, s * 0.05)
    ..lineTo(-s * 0.03, s * 0.46)
    ..quadraticBezierTo(0, s * 0.52, s * 0.03, s * 0.46)
    ..lineTo(s * 0.045, s * 0.05);
  c.drawPath(handle, p);
}

void _spoon(Canvas c, double s, Paint p) {
  c.drawOval(
    Rect.fromCenter(center: Offset(0, -s * 0.28), width: s * 0.3, height: s * 0.4),
    p,
  );
  final handle = Path()
    ..moveTo(-s * 0.04, -s * 0.08)
    ..lineTo(-s * 0.03, s * 0.44)
    ..quadraticBezierTo(0, s * 0.5, s * 0.03, s * 0.44)
    ..lineTo(s * 0.04, -s * 0.08);
  c.drawPath(handle, p);
}

void _knife(Canvas c, double s, Paint p) {
  final blade = Path()
    ..moveTo(-s * 0.5, s * 0.02)
    ..lineTo(s * 0.12, -s * 0.07)
    ..lineTo(s * 0.12, s * 0.07)
    ..quadraticBezierTo(-s * 0.2, s * 0.1, -s * 0.5, s * 0.02);
  c.drawPath(blade, p);
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.12, -s * 0.05, s * 0.38, s * 0.1),
      Radius.circular(s * 0.04),
    ),
    p,
  );
}

void _board(Canvas c, double s, Paint p) {
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s * 0.55, height: s),
      Radius.circular(s * 0.06),
    ),
    p,
  );
  c.drawCircle(Offset(0, -s * 0.4), s * 0.05, p);
}

void _bellPepper(Canvas c, double s, Paint p) {
  final body = Path()
    ..moveTo(0, -s * 0.3)
    ..cubicTo(s * 0.35, -s * 0.45, s * 0.5, -s * 0.1, s * 0.38, s * 0.25)
    ..cubicTo(s * 0.3, s * 0.5, s * 0.08, s * 0.5, 0, s * 0.4)
    ..cubicTo(-s * 0.08, s * 0.5, -s * 0.3, s * 0.5, -s * 0.38, s * 0.25)
    ..cubicTo(-s * 0.5, -s * 0.1, -s * 0.35, -s * 0.45, 0, -s * 0.3);
  c.drawPath(body, p);
  c.drawPath(
    Path()
      ..moveTo(0, -s * 0.28)
      ..quadraticBezierTo(s * 0.15, 0, 0, s * 0.4),
    p,
  );
  c.drawLine(Offset(0, -s * 0.3), Offset(s * 0.03, -s * 0.48), p);
}