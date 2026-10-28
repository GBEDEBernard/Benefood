import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/core/utils/formatters.dart';

void main() {
  group('formatEuroFromXof', () {
    test('convertit à la parité fixe 1 EUR = 655,957 XOF', () {
      expect(formatEuroFromXof(655957), '1 000,00 €');
      expect(formatEuroFromXof(3200), '4,88 €');
      expect(formatEuroFromXof(12500), '19,06 €');
      expect(formatEuroFromXof(3200, showSymbol: false), '4,88');
    });

    test('retombe sur la parité fixe si le taux est invalide', () {
      expect(formatEuroFromXof(655957, rate: 0), '1 000,00 €');
    });
  });

  group('formatDistance (J177/J179)', () {
    test('rend une distance en mètres sous 1 km', () {
      expect(formatDistance(0.35), '350 m');
      expect(formatDistance(0.999), '999 m');
    });

    test('rend une distance en kilomètres (1 décimale)', () {
      expect(formatDistance(1.2), '1,2 km');
      expect(formatDistance(5.0), '5,0 km');
    });

    test('rend un tiret pour une distance nulle ou absente', () {
      expect(formatDistance(null), '—');
      expect(formatDistance(double.nan), '—');
    });
  });

  group('horodatage des missions livreur', () {
    test('formatTime rend l’heure locale HH:MM', () {
      const iso = '2026-10-22T07:30:00Z';
      final local = DateTime.parse(iso).toLocal();
      final expected =
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

      expect(formatTime(iso), expected);
      expect(formatTime(null), '--:--');
      expect(formatTime('pas une date'), '--:--');
    });

    test('formatAgo rend le temps écoulé en clair', () {
      final now = DateTime.parse('2026-10-22T12:00:00Z').toLocal();

      expect(formatAgo(now.toIso8601String(), now: now), 'à l’instant');
      expect(
        formatAgo(
          now.subtract(const Duration(minutes: 12)).toIso8601String(),
          now: now,
        ),
        'il y a 12 min',
      );
      expect(
        formatAgo(
          now.subtract(const Duration(hours: 2)).toIso8601String(),
          now: now,
        ),
        'il y a 2 h',
      );
      expect(
        formatAgo(
          now.subtract(const Duration(days: 3)).toIso8601String(),
          now: now,
        ),
        'il y a 3 j',
      );
      expect(formatAgo(null), '');
    });

    test('formatDayLabel nomme aujourd’hui puis le jour court', () {
      final today = DateTime(2026, 10, 27, 9);

      expect(
        formatDayLabel(today, now: DateTime(2026, 10, 27, 15)),
        'Aujourd’hui',
      );
      expect(
        formatDayLabel(today, now: DateTime(2026, 10, 26, 15)),
        'mar. 27 oct.',
      );
    });
  });
}
