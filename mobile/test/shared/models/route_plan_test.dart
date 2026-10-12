import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/models/route_plan.dart';

void main() {
  group('RoutePlan — itinéraire routier (J178)', () {
    test('parse un itinéraire Google/Osmr avec géométrie et tronçons', () {
      final plan = RoutePlan.fromJson({
        'provider': 'google',
        'distance_m': 4200,
        'duration_s': 780,
        'geometry': [
          [6.3703, 2.3942],
          [6.3668, 2.4251],
        ],
        'legs': [
          {'distance_m': 4200, 'duration_s': 780},
        ],
      });

      expect(plan.provider, 'google');
      expect(plan.isRouted, isTrue);
      expect(plan.distanceKm, closeTo(4.2, 0.001));
      expect(plan.etaMinutes, 13);
      expect(plan.geometry, hasLength(2));
      expect(plan.geometry.first.latitude, 6.3703);
      expect(plan.legs.single.distanceMeters, 4200);
      expect(plan.latLng.first.latitude, 6.3703);
    });

    test('un repli "straight" n’est pas considéré comme routier', () {
      final plan = RoutePlan.fromJson({
        'provider': 'straight',
        'distance_m': 1000,
        'duration_s': 0,
        'geometry': [
          [6.1, 2.1],
        ],
      });

      expect(plan.isRouted, isFalse);
      expect(plan.etaMinutes, isNull);
      expect(plan.legs, isEmpty);
    });

    test('tolère une réponse vide sans lever d’exception', () {
      final plan = RoutePlan.fromJson(const {});

      expect(plan.provider, 'straight');
      expect(plan.distanceMeters, 0);
      expect(plan.geometry, isEmpty);
      expect(plan.latLng, isEmpty);
    });
  });
}
