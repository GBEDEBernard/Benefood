import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/core/utils/formatters.dart';

void main() {
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