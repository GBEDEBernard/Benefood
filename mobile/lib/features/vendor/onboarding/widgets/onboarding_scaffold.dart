import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';

/// Gabarit des étapes du parcours vendeur : en-tête (retour + indice « n/4 »),
/// titre, sous-titre, contenu défilant et bouton pleine largeur en bas.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.stepIndex,
    required this.title,
    required this.subtitle,
    required this.nextLabel,
    required this.onNext,
    required this.child,
    this.loading = false,
    this.onBack,
  });

  /// Numéro d'étape affiché (1 à 4).
  final int stepIndex;
  final String title;
  final String subtitle;
  final String nextLabel;
  final VoidCallback? onNext;
  final Widget child;
  final bool loading;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 24, 0),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Retour',
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  color: AppColors.textSecondary,
                  onPressed: onBack,
                )
              else
                const SizedBox(width: 48),
              const Spacer(),
              Text(
                '$stepIndex/4',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                child,
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: AppButton(
            label: nextLabel,
            loading: loading,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}
