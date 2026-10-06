import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:beninfood/core/utils/geo.dart';

void main() {
  group('distanceKm', () {
    test('mesure une distance à vol d’oiseau connue', () {
      // Cotonou -> Abomey-Calavi, ~13 km à l’axe.
      final km = distanceKm(const LatLng(6.3668, 2.4251), const LatLng(6.4483, 2.3556));
      expect(km, closeTo(11.5, 1.5));
    });

    test('vaut zéro pour un point identique', () {
      expect(distanceKm(const LatLng(6.3668, 2.4251), const LatLng(6.3668, 2.4251)), 0);
    });
  });

  group('bearingDegrees', () {
    test('oriente vers le nord', () {
      expect(bearingDegrees(const LatLng(6.0, 2.4), const LatLng(6.1, 2.4)), closeTo(0, 1));
    });

    test('oriente vers l’est', () {
      expect(bearingDegrees(const LatLng(6.0, 2.4), const LatLng(6.0, 2.5)), closeTo(90, 1));
    });

    test('oriente vers le sud', () {
      expect(bearingDegrees(const LatLng(6.0, 2.4), const LatLng(5.9, 2.4)), closeTo(180, 1));
    });

    test('oriente vers l’ouest', () {
      expect(bearingDegrees(const LatLng(6.0, 2.4), const LatLng(6.0, 2.3)), closeTo(270, 1));
    });
  });

  group('compassLabel', () {
    test('nomme les 8 points de la rose des vents', () {
      expect(compassLabel(0), 'Nord');
      expect(compassLabel(45), 'Nord-Est');
      expect(compassLabel(90), 'Est');
      expect(compassLabel(180), 'Sud');
      expect(compassLabel(315), 'Nord-Ouest');
      expect(compassLabel(359), 'Nord');
    });
  });

  group('estimateMinutes / formatEta', () {
    test('estime un temps de trajet', () {
      expect(estimateMinutes(0), isNull);
      expect(estimateMinutes(2.2), 6);
    });

    test('formate la durée', () {
      expect(formatEta(12), '12 min');
      expect(formatEta(65), '1h05');
      expect(formatEta(null), '—');
    });
  });
}