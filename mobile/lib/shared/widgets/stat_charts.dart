import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';

/// Périodes d'analyse proposées par les tableaux de bord statistiques.
///
/// La clé correspond au paramètre `period` attendu par l'API (`7d`, `30d`,
/// `90d`, `12m`).
enum StatPeriod {
  week('7d', '7 j'),
  month('30d', '30 j'),
  quarter('90d', '90 j'),
  year('12m', '12 mois');

  const StatPeriod(this.key, this.label);

  final String key;
  final String label;

  /// Libellé de la période précédente, utilisé dans les comparaisons.
  String get previousLabel => switch (this) {
    StatPeriod.week => 'semaine précédente',
    StatPeriod.month => 'période précédente',
    StatPeriod.quarter => 'trimestre précédent',
    StatPeriod.year => 'année précédente',
  };
}

/// Sélecteur segmenté de période (7 j / 30 j / 90 j / 12 mois).
class StatPeriodSelector extends StatelessWidget {
  const StatPeriodSelector({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final StatPeriod period;
  final ValueChanged<StatPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3EF),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        children: [
          for (final option in StatPeriod.values)
            Expanded(
              child: _PeriodSegment(
                label: option.label,
                selected: option == period,
                onTap: () => onChanged(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodSegment extends StatelessWidget {
  const _PeriodSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x1418231F),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF18231F)
                  : const Color(0xFF6B7670),
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Courbe de tendance avec remplissage dégradé et repères de dates.
class StatTrendChart extends StatelessWidget {
  const StatTrendChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    this.valueFormatter,
    this.height = 150,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final String Function(num value)? valueFormatter;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const StatEmpty(message: 'Aucune donnée sur la période.');
    }

    final maxValue = values.reduce(math.max);
    final hasData = maxValue > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (valueFormatter != null && hasData)
          Row(
            children: [
              Text(
                valueFormatter!(maxValue),
                style: const TextStyle(
                  color: Color(0xFF18231F),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'au plus haut',
                style: TextStyle(color: Color(0xFF8A948E), fontSize: 11),
              ),
            ],
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: height,
          child: TweenAnimationBuilder<double>(
            // Une nouvelle série rejoue le tracé, sans clignotement de la carte.
            key: ValueKey(values.join('|')),
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) => CustomPaint(
              painter: _TrendPainter(
                values: values,
                color: color,
                maxValue: hasData ? maxValue : 1,
                showDots: values.length <= 32,
                progress: progress,
              ),
            ),
          ),
        ),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ChartLabels(labels: labels),
        ],
      ],
    );
  }
}

class _ChartLabels extends StatelessWidget {
  const _ChartLabels({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final indexes = <int>{};
    if (labels.length <= 4) {
      indexes.addAll(List.generate(labels.length, (i) => i));
    } else {
      indexes.addAll({
        0,
        (labels.length - 1) ~/ 3,
        ((labels.length - 1) * 2) ~/ 3,
        labels.length - 1,
      });
    }
    final ordered = indexes.toList()..sort();

    return Row(
      children: [
        for (var i = 0; i < ordered.length; i++)
          Expanded(
            child: Text(
              labels[ordered[i]],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: i == 0
                  ? TextAlign.left
                  : i == ordered.length - 1
                  ? TextAlign.right
                  : TextAlign.center,
              style: const TextStyle(color: Color(0xFF8A948E), fontSize: 10.5),
            ),
          ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.color,
    required this.maxValue,
    required this.showDots,
    required this.progress,
  });

  final List<double> values;
  final Color color;
  final double maxValue;
  final bool showDots;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const topPadding = 6.0;
    final chartHeight = size.height - topPadding;

    // Grille horizontale discrète (3 niveaux).
    final gridPaint = Paint()
      ..color = const Color(0xFFEDEFEA)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = topPadding + chartHeight * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset pointAt(int index) {
      final dx = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final ratio = (values[index] / maxValue).clamp(0.0, 1.0);
      return Offset(dx, topPadding + chartHeight * (1 - ratio));
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = pointAt(i);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (showDots && progress > 0.98) {
      final dotPaint = Paint()..color = color;
      final haloPaint = Paint()..color = Colors.white;
      for (var i = 0; i < values.length; i++) {
        final point = pointAt(i);
        canvas.drawCircle(point, 3.6, haloPaint);
        canvas.drawCircle(point, 2.4, dotPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.showDots != showDots ||
      oldDelegate.progress != progress;
}

/// Montant animé : interpolation douce à chaque nouvelle valeur reçue.
class StatAnimatedAmount extends StatelessWidget {
  const StatAnimatedAmount({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.duration = const Duration(milliseconds: 700),
  });

  final num value;
  final String Function(num value) formatter;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int maxLines;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => Text(
        formatter(animated),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

/// Indicateur d'actualisation : pastille, heure de mise à jour et bouton
/// de rafraîchissement manuel.
class StatLiveStatus extends StatelessWidget {
  const StatLiveStatus({
    super.key,
    required this.updatedAt,
    required this.refreshing,
    required this.onRefresh,
  });

  final DateTime? updatedAt;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final color = refreshing
        ? const Color(0xFFFF6600)
        : const Color(0xFF1A5B2E);
    final label = refreshing
        ? 'Actualisation…'
        : updatedAt == null
        ? 'En attente des données'
        : 'Actualisé à ${_time(updatedAt!)}';

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7670),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        InkWell(
          onTap: refreshing ? null : onRefresh,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: refreshing
                  ? const Color(0xFFB4BDB7)
                  : const Color(0xFF6B7670),
            ),
          ),
        ),
      ],
    );
  }

  String _time(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Bandeau discret signalant qu'une actualisation silencieuse a échoué :
/// Les dernières données connues restent affichées.
class StatSyncBanner extends StatelessWidget {
  const StatSyncBanner({
    super.key,
    required this.message,
    required this.onRetry,
    this.refreshing = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.md),
      padding: const EdgeInsets.fromLTRB(
        AppDimens.md,
        AppDimens.sm,
        AppDimens.sm,
        AppDimens.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD9B8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: Color(0xFFCC5200),
          ),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF7A4A1D), fontSize: 11.5),
            ),
          ),
          TextButton(
            onPressed: refreshing ? null : onRetry,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFCC5200),
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              refreshing ? '…' : 'Réessayer',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloc vide compact utilisé dans les cartes statistiques.
class StatEmpty extends StatelessWidget {
  const StatEmpty({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.xl,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEFEA)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.insights_outlined,
            size: 26,
            color: Color(0xFFB4BDB7),
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8A948E), fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
