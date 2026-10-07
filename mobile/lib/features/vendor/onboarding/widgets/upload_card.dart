import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Bloc « Téléverser un document » du parcours vendeur : carte blanche à
/// bordure pointillée, aperçu miniature, spinner de chargement et coche
/// verte lorsque le document est envoyé.
class UploadCard extends StatelessWidget {
  const UploadCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon = Icons.description_outlined,
    this.preview,
    this.uploaded = false,
    this.uploading = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData icon;
  final Uint8List? preview;
  final bool uploaded;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final borderColor = uploaded ? AppColors.green : AppColors.borderStrong;
    final subtitleColor = uploaded ? AppColors.green : AppColors.textSecondary;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: uploading ? null : onTap,
        child: CustomPaint(
          painter: _DashedRRectPainter(color: borderColor),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _UploadThumb(icon: icon, preview: preview, uploaded: uploaded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: subtitleColor,
                          fontWeight: uploaded ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (uploading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.orange,
                    ),
                  )
                else if (uploaded)
                  const Icon(Icons.check_circle, color: AppColors.green)
                else
                  const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.orange,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vignette de gauche : aperçu de l'image envoyée ou icône de document.
class _UploadThumb extends StatelessWidget {
  const _UploadThumb({
    required this.icon,
    required this.preview,
    required this.uploaded,
  });

  final IconData icon;
  final Uint8List? preview;
  final bool uploaded;

  @override
  Widget build(BuildContext context) {
    if (preview != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          preview!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => iconBox(),
        ),
      );
    }
    return iconBox();
  }

  Widget iconBox() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: uploaded ? AppColors.green : AppColors.textSecondary,
      ),
    );
  }
}

/// Rectangle arrondi à bordure pointillée (sans dépendance externe).
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 14.0;
    const dash = 6.0;
    const gap = 5.0;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
