import 'package:flutter/material.dart';

/// Palette du design system « Le Délice Fast-Food ».
abstract final class RestaurantPalette {
  static const Color forest = Color(0xFF0A2A1A);
  static const Color orange = Color(0xFFF97316);
  static const Color white = Colors.white;
  static const Color background = Color(0xFFF5F5F5);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color ready = Color(0xFF3B82F6);
  static const Color darkText = Color(0xFF111827);
  static const Color grayText = Color(0xFF6B7280);

  static const double radius = 12;
  static const double cardSpacing = 12;

  static final BoxDecoration cardDecoration = BoxDecoration(
    color: white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}