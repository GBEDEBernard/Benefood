import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Étape finale — Demande soumise : confirmation, badge « En attente de
/// vérification », checklist d'avancement et sortie vers le tableau de bord.
class SubmittedStep extends StatelessWidget {
  const SubmittedStep({super.key, required this.onGoToDashboard});

  final VoidCallback onGoToDashboard;

  /// Checklist : (état, libellé).
  static const _checklist = <(bool done, bool current, String label)>[
    (true, false, 'Informations soumises'),
    (true, false, 'Documents reçus'),
    (false, true, 'En cours de vérification'),
    (false, false, 'Compte à activer'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const _ConfirmationMark(),
          const SizedBox(height: 20),
          const Text(
            'D\u2019demande soumise !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Votre compte est en attente de vérification.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.orangeLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'En attente de vérification',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orangeDark,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nous examinons vos informations et vous notifierons dès que '
            'votre compte sera activé.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.textFaint),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _checklist.length; i++) ...[
                  _ChecklistRow(
                    done: _checklist[i].$1,
                    current: _checklist[i].$2,
                    label: _checklist[i].$3,
                  ),
                  if (i < _checklist.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Container(width: 2, height: 16, color: AppColors.border),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: onGoToDashboard,
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.text, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: const Text('Aller au tableau de bord'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Cercle vert avec presse-papiers blanc et coche de validation.
class _ConfirmationMark extends StatelessWidget {
  const _ConfirmationMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.content_paste, size: 40, color: AppColors.surface),
            ),
            Positioned(
              right: 2,
              bottom: 4,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 20, color: AppColors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne de la checklist (fait / en cours / à venir).
class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.done,
    required this.current,
    required this.label,
  });

  final bool done;
  final bool current;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = done
        ? AppColors.green
        : current
            ? AppColors.orange
            : AppColors.borderStrong;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.green : AppColors.surface,
              border: done ? null : Border.all(color: borderColor, width: 2),
            ),
            child: done
                ? const Icon(Icons.check, size: 16, color: AppColors.surface)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: done || current ? FontWeight.w600 : FontWeight.w500,
                color: done ? AppColors.text : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
