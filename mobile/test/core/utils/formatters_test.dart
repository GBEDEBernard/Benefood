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
}
