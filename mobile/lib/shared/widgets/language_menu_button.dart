import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/i18n/app_language.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/language_controller.dart';
import '../../core/theme/app_colors.dart';

/// Sélecteur de langue compact affiché à côté de la cloche de notification.
///
/// Les langues disponibles viennent de `GET /languages` (avec repli local) :
/// français, anglais et fon. Le choix est mémorisé et synchronisé avec le
/// profil connecté.
class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageController.instance,
      builder: (context, _) {
        final controller = LanguageController.instance;
        final current = controller.language;
        return PopupMenuButton<String>(
          tooltip: '${context.tr('Langue')} : ${current.nativeName}',
          padding: EdgeInsets.zero,
          offset: const Offset(0, 48),
          color: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          onSelected: (code) {
            unawaited(controller.setLanguage(code));
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              height: 34,
              child: Text(
                context.tr('Choisir la langue'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textFaint,
                ),
              ),
            ),
            for (final language in controller.languages)
              PopupMenuItem<String>(
                value: language.code,
                child: _LanguageRow(
                  language: language,
                  selected: language.code == controller.code,
                ),
              ),
          ],
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.language_rounded,
                  size: 22,
                  color: AppColors.text,
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      current.shortCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.language, required this.selected});

  final AppLanguage language;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.orangeLight : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            language.shortCode,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: selected ? AppColors.orangeDark : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            language.nativeName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ),
        if (selected)
          const Icon(Icons.check_rounded, size: 19, color: AppColors.green),
      ],
    );
  }
}
