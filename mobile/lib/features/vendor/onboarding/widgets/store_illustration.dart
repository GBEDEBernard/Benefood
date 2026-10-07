import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Illustration de l'écran d'accueil du parcours vendeur : devanture de
/// boutique à auvent orange rayé, comptoir avec plats et plantes en pot.
///
/// Tracée en pur `Canvas` (aucun asset image à embarquer).
class StoreIllustration extends StatelessWidget {
  const StoreIllustration({super.key, this.height = 170});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _StorePainter()),
    );
  }
}

class _StorePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final groundY = h * 0.84;

    final strokeBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.borderStrong;

    // --- Cadre doux de l'illustration ---
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = AppColors.surfaceVariant,
    );

    // --- Sol ---
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, groundY, w, h),
        const Radius.circular(18),
      ),
      Paint()..color = AppColors.border,
    );

    // --- Corps de la boutique ---
    final shop = Rect.fromLTRB(w * 0.17, h * 0.34, w * 0.83, groundY);
    canvas.drawRect(shop, Paint()..color = AppColors.surface);
    canvas.drawRect(shop, strokeBorder);

    // --- Porte ---
    final door = Rect.fromLTRB(w * 0.62, h * 0.46, w * 0.79, groundY);
    canvas.drawRRect(
      RRect.fromRectAndRadius(door, const Radius.circular(6)),
      Paint()..color = AppColors.greenLight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(door, const Radius.circular(6)),
      strokeBorder,
    );
    // Poignée dorée.
    canvas.drawCircle(
      Offset(w * 0.65, h * 0.66),
      w * 0.014,
      Paint()..color = AppColors.gold,
    );

    // --- Vitrine ---
    final window = Rect.fromLTRB(w * 0.23, h * 0.44, w * 0.54, h * 0.64);
    canvas.drawRect(window, Paint()..color = AppColors.greenLight);
    canvas.drawRect(window, strokeBorder);
    final mullion = Paint()
      ..strokeWidth = 2.5
      ..color = AppColors.surface;
    canvas.drawLine(
      Offset(window.center.dx, window.top),
      Offset(window.center.dx, window.bottom),
      mullion,
    );
    canvas.drawLine(
      Offset(window.left, window.center.dy),
      Offset(window.right, window.center.dy),
      mullion,
    );

    // --- Comptoir avec plats ---
    final counter = Rect.fromLTRB(w * 0.21, h * 0.66, w * 0.56, h * 0.78);
    canvas.drawRRect(
      RRect.fromRectAndRadius(counter, const Radius.circular(6)),
      Paint()..color = AppColors.goldLight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(counter, const Radius.circular(6)),
      strokeBorder,
    );
    final plateColors = [
      AppColors.orange,
      AppColors.green,
      AppColors.gold,
    ];
    for (var i = 0; i < 3; i++) {
      final center = Offset(
        w * (0.29 + 0.095 * i),
        h * 0.665,
      );
      final plateR = h * 0.045;
      canvas.drawCircle(
        center,
        plateR,
        Paint()..color = AppColors.surface,
      );
      canvas.drawCircle(center, plateR, strokeBorder);
      canvas.drawCircle(
        center,
        plateR * 0.55,
        Paint()..color = plateColors[i],
      );
    }

    // --- Auvent à festons ---
    _paintAwning(
      canvas,
      Rect.fromLTRB(w * 0.10, h * 0.24, w * 0.90, h * 0.37),
      segments: 6,
    );

    // --- Plantes en pot ---
    _paintPlant(canvas, x: w * 0.07, h: h, groundY: groundY, size: w);
    _paintPlant(canvas, x: w * 0.93, h: h, groundY: groundY, size: w);
  }

  void _paintAwning(Canvas canvas, Rect rect, {required int segments}) {
    final seg = rect.width / segments;

    final path = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom);

    // Bord inférieur festonné : arcs successifs vers le bas.
    for (var i = 0; i < segments; i++) {
      final center = Offset(rect.right - seg * (i + 0.5), rect.bottom);
      path.arcTo(
        Rect.fromCircle(center: center, radius: seg / 2),
        0,
        math.pi,
        false,
      );
    }
    path.close();

    canvas.drawPath(path, Paint()..color = AppColors.surface);

    // Rayures orange alternées, découpées par le feston.
    canvas.save();
    canvas.clipPath(path);
    for (var i = 0; i < segments; i += 2) {
      canvas.drawRect(
        Rect.fromLTRB(
          rect.left + seg * i,
          rect.top,
          rect.left + seg * (i + 1),
          rect.bottom + seg,
        ),
        Paint()..color = AppColors.orange,
      );
    }
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.borderStrong,
    );
  }

  void _paintPlant(
    Canvas canvas, {
    required double x,
    required double h,
    required double groundY,
    required double size,
  }) {
    final potWidth = size * 0.085;
    final potTop = groundY - h * 0.13;
    final leafPaint = Paint()..color = AppColors.green;

    // Feuilles.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, potTop - h * 0.06),
        width: potWidth * 0.75,
        height: h * 0.12,
      ),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x - potWidth * 0.5, potTop - h * 0.03),
        width: potWidth * 0.6,
        height: h * 0.09,
      ),
      leafPaint..color = AppColors.green.withValues(alpha: 0.85),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + potWidth * 0.5, potTop - h * 0.03),
        width: potWidth * 0.6,
        height: h * 0.09,
      ),
      leafPaint..color = AppColors.green.withValues(alpha: 0.85),
    );

    // Pot trapézoïdal.
    final pot = Path()
      ..moveTo(x - potWidth / 2, potTop)
      ..lineTo(x + potWidth / 2, potTop)
      ..lineTo(x + potWidth * 0.34, groundY)
      ..lineTo(x - potWidth * 0.34, groundY)
      ..close();
    canvas.drawPath(pot, Paint()..color = AppColors.orange);
    canvas.drawPath(
      pot,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.orangeDark,
    );
  }

  @override
  bool shouldRepaint(_StorePainter oldDelegate) => false;
}
