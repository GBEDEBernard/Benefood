import 'package:flutter/material.dart';

/// Décor photographique « food » de la marque Béninfood.
///
/// Deux visuels découpés en PNG transparent (`assets/landing/`) :
/// - [bowlAsset] : bol garni (oignon, carottes, poulet), basilic, piment ;
/// - [herbsAsset] : piment rouge, persil et basilic.
///
/// Ils sont utilisés en surimpression des bannières d'identité (tiroirs
/// latéraux, cartes de profil) et en fond des écrans de profil. Chaque image
/// est estompée par un fondu vers un coin : elle se fond dans le fond
/// colouré sans jamais nuire à la lisibilité du texte.
class FoodDecor extends StatelessWidget {
  const FoodDecor({
    super.key,
    this.bowlOpacity = 0.22,
    this.herbsOpacity = 0.18,
    this.bowlWidth = 172,
    this.herbsWidth = 120,
    this.bowlLeft,
    this.bowlRight = -30,
    this.bowlBottom = -34,
    this.herbsLeft,
    this.herbsRight = -14,
    this.herbsTop = -24,
  });

  /// Bol garni (bas de carte).
  static const String bowlAsset = 'assets/landing/bowl_left.png';

  /// Herbes et piment (haut de carte).
  static const String herbsAsset = 'assets/landing/herbs_right.png';

  /// Opacité du bol (0 → invisible).
  final double bowlOpacity;

  /// Opacité des herbes (0 → invisible).
  final double herbsOpacity;

  final double bowlWidth;
  final double herbsWidth;

  /// Position latérale du bol (gauche ou droite, jamais les deux).
  final double? bowlLeft;
  final double bowlRight;
  final double bowlBottom;

  /// Position latérale des herbes (gauche ou droite, jamais les deux).
  final double? herbsLeft;
  final double herbsRight;
  final double herbsTop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Bol garni : fondu vers le coin bas-droit de l'image.
        Positioned(
          left: bowlLeft,
          right: bowlLeft == null ? bowlRight : null,
          bottom: bowlBottom,
          width: bowlWidth,
          child: Opacity(
            opacity: bowlOpacity,
            child: _faded(
              image: bowlAsset,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Herbes & piment : fondu vers le coin haut-droit de l'image.
        Positioned(
          left: herbsLeft,
          right: herbsLeft == null ? herbsRight : null,
          top: herbsTop,
          width: herbsWidth,
          child: Opacity(
            opacity: herbsOpacity,
            child: _faded(
              image: herbsAsset,
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
          ),
        ),
      ],
    );
  }

  /// Estompe une image vers un coin pour qu'elle se fonde dans le fond.
  Widget _faded({
    required String image,
    required Alignment begin,
    required Alignment end,
  }) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: begin,
        end: end,
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(bounds),
      child: Image.asset(
        image,
        fit: BoxFit.contain,
        cacheWidth: 480,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Décor « food » en fond d'écran des pages de profil.
///
/// Composition en diagonale : herbes en haut à droite, bol en bas à gauche,
/// très estompées pour ne jamais concurrencer le contenu.
class FoodDecorPageBackground extends StatelessWidget {
  const FoodDecorPageBackground({super.key, this.intensity = 1});

  /// 0 → décor invisible, 1 → opacité nominale.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FoodDecor(
        bowlOpacity: 0.14 * intensity,
        herbsOpacity: 0.12 * intensity,
        bowlWidth: 250,
        herbsWidth: 190,
        bowlLeft: -74,
        bowlBottom: -86,
        herbsRight: -58,
        herbsTop: -62,
      ),
    );
  }
}
