import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Ligne compacte et cohérente pour afficher un horodatage métier
/// (« Créé le … », « Payé le … ») sur les cartes commandes et colis.
class TimestampLine extends StatelessWidget {
  const TimestampLine({
    super.key,
    required this.label,
    this.iso,
    this.icon = Icons.schedule,
    this.fallback = '',
  });

  final String label;
  final String? iso;
  final IconData icon;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final value = formatDateTime(iso, fallback: fallback);
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    final text = label.isEmpty ? value : '$label $value';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
