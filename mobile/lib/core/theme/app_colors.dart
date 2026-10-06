import 'package:flutter/material.dart';

/// Charte officielle Béninfood.
///
/// Répartition cible : 60 % ivoire, 20 % orange, 10 % vert,
/// 5 % anthracite, 5 % doré.
/// - **Orange** : marque, boutons « Commander », panier, prix, sélection active.
/// - **Vert** : états positifs — livraison dispo, commande confirmée,
///   restaurant ouvert, localisation, validation, badges.
/// - **Ivoire** : fond général, chaud et gastronomique.
/// - **Anthracite** : titres, textes, prix, noms des restaurants.
/// - **Doré** : promotions et accents (clin d'œil au drapeau béninois).
/// - Le rouge est réservé aux alertes et états critiques.
class AppColors {
  const AppColors._();

  // --- Marque : orange chaleureux (#F26A2C) ---
  static const Color orange = Color(0xFFF26A2C);
  static const Color orangeLight = Color(0xFFFFE9DE);
  static const Color orangeDark = Color(0xFFC24610);

  // --- Vert profond : local, frais, fiable (#167A52) ---
  static const Color green = Color(0xFF167A52);
  static const Color greenLight = Color(0xFFE3F1EA);

  // --- Fond ivoire (#FFF8EE) ---
  static const Color ivory = Color(0xFFFFF8EE);

  // --- Doré : promotions (#F4B83F) ---
  static const Color gold = Color(0xFFF4B83F);
  static const Color goldLight = Color(0xFFFDF2DB);
  static const Color goldDark = Color(0xFF9A6A08);

  // --- Anthracite : textes (#18231F) ---
  static const Color text = Color(0xFF18231F);
  static const Color textSecondary = Color(0xFF5E6B64);
  static const Color textFaint = Color(0xFF8A948E);

  // --- Rouge : alertes / états critiques uniquement ---
  static const Color red = Color(0xFFD93B30);
  static const Color redLight = Color(0xFFFDEBE9);

  // --- Neutres chauds ---
  static const Color background = ivory;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFAF3E7);
  static const Color border = Color(0xFFEFE3D1);
  static const Color borderStrong = Color(0xFFE1D2BC);

  // --- Sémantique ---
  static const Color success = green;
  static const Color warning = goldDark;
  static const Color info = Color(0xFF2B6CB0);
}
