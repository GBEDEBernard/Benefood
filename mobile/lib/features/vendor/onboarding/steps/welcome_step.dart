import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../widgets/step_dots.dart';
import '../widgets/store_illustration.dart';

/// Écran d'accueil du parcours vendeur : illustration, promesses et bouton
/// « Commencer » (avec lien « Passer » en haut à droite).
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.onStart, required this.onSkip});

  final VoidCallback onStart;
  final VoidCallback onSkip;

  static const _benefits = [
    'Développez votre activité',
    'Suivez vos ventes en temps réel',
    'Augmentez vos revenus',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onSkip,
            child: const Text(
              'Passer',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StoreIllustration(height: 168),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                    children: const [
                      TextSpan(text: 'Bienvenue chez '),
                      TextSpan(
                        text: 'BÉNIN',
                        style: TextStyle(color: AppColors.green),
                      ),
                      TextSpan(
                        text: 'FOOD',
                        style: TextStyle(color: AppColors.orange),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gérez votre boutique, vos produits et vos commandes '
                  'facilement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                for (final benefit in _benefits) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 22,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          benefit,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 10),
                AppButton(label: 'Commencer', onPressed: onStart),
                const SizedBox(height: 18),
                const StepDots(activeIndex: 0),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
