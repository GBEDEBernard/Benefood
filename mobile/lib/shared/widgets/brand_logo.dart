import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Logo textuel BÉNINFOOD : casque de chef + vapeur (vert et orange),
/// suivi du nom de marque bicolore.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.iconSize = 28, this.fontSize = 19});

  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(iconSize, iconSize),
          painter: _ChefHatPainter(
            hatColor: AppColors.green,
            steamColor: AppColors.orange,
          ),
        ),
        SizedBox(width: iconSize * 0.28),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.clip,
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              height: 1.1,
            ),
            children: const [
              TextSpan(
                text: 'BÉN',
                style: TextStyle(color: AppColors.green),
              ),
              TextSpan(
                text: 'INFOOD',
                style: TextStyle(color: AppColors.orange),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Casque de cuisinier (vert) surmonté de trois volutes de vapeur (orange).
class _ChefHatPainter extends CustomPainter {
  const _ChefHatPainter({required this.hatColor, required this.steamColor});

  final Color hatColor;
  final Color steamColor;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 32;
    final steam = Paint()
      ..color = steamColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * unit
      ..strokeCap = StrokeCap.round;
    final hat = Paint()..color = hatColor;

    // Vapeur : trois petites courbes au-dessus du casque.
    for (var i = 0; i < 3; i++) {
      final x = (10 + i * 6) * unit;
      final path = Path()
        ..moveTo(x, 9 * unit)
        ..cubicTo(
          x - 2.4 * unit,
          7 * unit,
          x + 2.4 * unit,
          5 * unit,
          x,
          3 * unit,
        );
      canvas.drawPath(path, steam);
    }

    // Calotte : trois lobes arrondis.
    canvas.drawCircle(Offset(11 * unit, 17 * unit), 5.4 * unit, hat);
    canvas.drawCircle(Offset(16 * unit, 14.6 * unit), 6.4 * unit, hat);
    canvas.drawCircle(Offset(21 * unit, 17 * unit), 5.4 * unit, hat);
    canvas.drawRect(
      Rect.fromLTWH(6 * unit, 17 * unit, 20 * unit, 5 * unit),
      hat,
    );

    // Bande du casque.
    final brim = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(5 * unit, 22 * unit, 22 * unit, 5 * unit),
          Radius.circular(2.4 * unit),
        ),
      );
    canvas.drawPath(brim, hat);
  }

  @override
  bool shouldRepaint(_ChefHatPainter oldDelegate) =>
      oldDelegate.hatColor != hatColor || oldDelegate.steamColor != steamColor;
}

/// Logo officiel Béninfood (image ronde) dans un cadre arrondi prêt à l'emploi.
///
/// Pensé pour les écrans de bienvenue et d'onboarding : fond blanc, ombre
/// douce et rendu responsive (la taille s'adapte au côté demandé).
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 112,
    this.background = Colors.white,
    this.padding = 10,
    this.showShadow = true,
  });

  /// Côté du carré (largeur = hauteur).
  final double size;
  final Color background;
  final double padding;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final outerRadius = size * 0.26;
    final innerRadius = (outerRadius - padding).clamp(0.0, outerRadius);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(outerRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: size * 0.2,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        child: Image.asset(
          'assets/Logo.jpeg',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.storefront,
            color: AppColors.orange,
          ),
        ),
      ),
    );
  }
}
