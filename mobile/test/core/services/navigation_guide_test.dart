import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/core/services/navigation_guide.dart';
import 'package:beninfood/shared/models/geo_point.dart';
import 'package:beninfood/shared/models/route_plan.dart';

/// Itinéraire synthétique le long du parallèle 6.0 :
/// A(6.0, 2.00) → B(6.0, 2.01) → C(6.0, 2.02), soit ~1107 m par segment.
RoutePlan _route() => RoutePlan(
      provider: 'osrm',
      distanceMeters: 2214,
      durationSeconds: 400,
      geometry: const [
        GeoPoint(6.0, 2.00),
        GeoPoint(6.0, 2.01),
        GeoPoint(6.0, 2.02),
      ],
      steps: const [
        RouteStep(
          type: 'depart',
          modifier: 'straight',
          instruction: 'Partez',
          name: '',
          distanceMeters: 1107,
          durationSeconds: 200,
          geometry: [GeoPoint(6.0, 2.00), GeoPoint(6.0, 2.01)],
        ),
        RouteStep(
          type: 'turn',
          modifier: 'left',
          instruction: 'Tournez à gauche',
          name: 'Rue B',
          distanceMeters: 1107,
          durationSeconds: 200,
          geometry: [GeoPoint(6.0, 2.01), GeoPoint(6.0, 2.02)],
        ),
        RouteStep(
          type: 'arrive',
          modifier: 'left',
          instruction: 'Vous êtes arrivé',
          name: '',
          distanceMeters: 0,
          durationSeconds: 0,
          geometry: [GeoPoint(6.0, 2.02)],
        ),
      ],
    );

void main() {
  const guide = NavigationGuide();

  group('NavigationGuide — guidage tour-par-tour', () {
    test('cible la prochaine manœuvre et calcule la distance restante le long de la route', () {
      final state = guide.update(_route(), const GeoPoint(6.0, 2.001));

      expect(state, isNotNull);
      expect(state!.instruction, 'Tournez à gauche');
      expect(state.stepIndex, 1);
      // ~110 m parcourus, reste ~997 m avant la manœuvre de B.
      expect(state.distanceToManeuverMeters, closeTo(997, 15));
      // Il reste environ 2 tronçons, ~2104 m.
      expect(state.remainingMeters, closeTo(2104, 20));
      expect(state.offRoute, isFalse);
      expect(state.arrived, isFalse);
      expect(state.etaMinutes, greaterThan(0));
    });

    test('détecte le hors-itinéraire au-delà du seuil', () {
      // ~222 m au nord de la route (6.0 → 6.002).
      final state = guide.update(_route(), const GeoPoint(6.002, 2.005));

      expect(state, isNotNull);
      expect(state!.offRoute, isTrue);
      expect(state.distanceFromRouteMeters, greaterThan(150));
    });

    test('ne déclare pas hors-itinéraire un écart faible', () {
      // ~11 m au nord de la route.
      final state = guide.update(_route(), const GeoPoint(6.0001, 2.005));

      expect(state!.offRoute, isFalse);
    });

    test('détecte l’arrivée à proximité du point final', () {
      final state = guide.update(_route(), const GeoPoint(6.0, 2.01995));

      expect(state!.arrived, isTrue);
      expect(state.remainingMeters, lessThan(30));
    });

    test('repli sans aucune étape : guidage jusqu’à la destination', () {
      const route = RoutePlan(
        provider: 'straight',
        distanceMeters: 1107,
        durationSeconds: 180,
        geometry: [GeoPoint(6.0, 2.00), GeoPoint(6.0, 2.01)],
      );

      final state = guide.update(route, const GeoPoint(6.0, 2.001));

      expect(state, isNotNull);
      expect(state!.instruction, contains('destination'));
      expect(state.stepIndex, -1);
    });

    test('renvoie null pour une géométrie inexploitable', () {
      const route = RoutePlan(
        provider: 'straight',
        distanceMeters: 0,
        durationSeconds: 0,
        geometry: [GeoPoint(6.0, 2.0)],
      );

      expect(guide.update(route, const GeoPoint(6.0, 2.0)), isNull);
    });
  });
}
