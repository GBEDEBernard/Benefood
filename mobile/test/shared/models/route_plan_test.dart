import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/models/route_plan.dart';

void main() {
  group('RoutePlan — itinéraire routier (J178)', () {
    test('parse un itinéraire Google/Osmr avec géométrie et tronçons', () {
      final plan = RoutePlan.fromJson({
        'provider': 'google',
        'distance_m': 4200,
        'duration_s': 780,
        'eta_s': 1014,
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
      expect(plan.durationSeconds, 780);
      expect(plan.effectiveEtaSeconds, 1014);
      expect(plan.etaMinutes, 17);
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

    test('parse les instructions de manœuvre (étapes de guidage)', () {
      final plan = RoutePlan.fromJson({
        'provider': 'osrm',
        'distance_m': 1200,
        'duration_s': 240,
        'geometry': [
          [6.3703, 2.3942],
          [6.3720, 2.3960],
          [6.3740, 2.3990],
        ],
        'steps': [
          {
            'type': 'depart',
            'modifier': 'straight',
            'instruction': 'Partez sur Boulevard de la Marina',
            'name': 'Boulevard de la Marina',
            'distance_m': 500,
            'duration_s': 100,
            'geometry': [
              [6.3703, 2.3942],
              [6.3720, 2.3960],
            ],
          },
          {
            'type': 'turn',
            'modifier': 'left',
            'instruction': 'Tournez à gauche sur Rue Foo',
            'name': 'Rue Foo',
            'distance_m': 700,
            'duration_s': 140,
            'geometry': [
              [6.3720, 2.3960],
              [6.3740, 2.3990],
            ],
          },
        ],
      });

      expect(plan.hasSteps, isTrue);
      expect(plan.steps, hasLength(2));
      expect(plan.steps.first.type, 'depart');
      expect(plan.steps.first.instruction, 'Partez sur Boulevard de la Marina');
      expect(plan.steps.first.icon, isNotNull);
      expect(plan.steps[1].modifier, 'left');
      expect(plan.steps[1].geometry, hasLength(2));
    });

    test('tolère des étapes vides ou malformées', () {
      final plan = RoutePlan.fromJson({
        'provider': 'straight',
        'steps': [
          'invalid',
          {'type': 'continue'},
        ],
      });

      expect(plan.steps, hasLength(1));
      expect(plan.steps.single.type, 'continue');
      expect(plan.steps.single.distanceMeters, 0);
      expect(plan.steps.single.geometry, isEmpty);
    });
  });
}
