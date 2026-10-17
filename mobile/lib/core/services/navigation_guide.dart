import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../utils/geo.dart';
import '../../shared/models/geo_point.dart';
import '../../shared/models/route_plan.dart';

/// État de guidage calculé à partir de la position du livreur et de l'itinéraire.
class NavigationState {
  const NavigationState({
    required this.instruction,
    required this.icon,
    required this.distanceToManeuverMeters,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.offRoute,
    required this.distanceFromRouteMeters,
    required this.stepIndex,
    required this.arrived,
    this.nextInstruction,
  });

  /// Instruction de la prochaine manœuvre (« Tournez à gauche… »).
  final String instruction;
  final IconData icon;

  /// Distance restante avant la prochaine manœuvre (mètres).
  final int distanceToManeuverMeters;

  /// Distance restante jusqu'à l'arrivée, le long de la route (mètres).
  final int remainingMeters;

  /// Durée estimée restante (secondes).
  final int remainingSeconds;

  /// Vrai si le livreur s'est écarté de l'itinéraire au-delà du seuil.
  final bool offRoute;

  /// Distance perpendiculaire à l'itinéraire (mètres).
  final int distanceFromRouteMeters;

  /// Index de la prochaine manœuvre dans `RoutePlan.steps`.
  final int stepIndex;

  /// Vrai quand le livreur est arrivé (à quelques mètres de la fin).
  final bool arrived;

  /// Manœuvre suivante, pour l'aperçu « puis … ».
  final String? nextInstruction;

  int? get etaMinutes {
    if (remainingSeconds <= 0) {
      return null;
    }
    return (remainingSeconds / 60).round().clamp(1, 999);
  }
}

/// Calcule un guidage tour-par-tour en projetant la position sur l'itinéraire.
///
/// Service sans état : chaque appel à [update] renvoie l'état de guidage courant
/// (manœuvre à venir, distance restante, hors-itinéraire, arrivée).
class NavigationGuide {
  const NavigationGuide({this.offRouteThresholdMeters = 150, this.arrivalThresholdMeters = 30});

  /// Écart latéral au-delà duquel on considère le livreur hors-itinéraire.
  final double offRouteThresholdMeters;

  /// Distance à la fin en dessous de laquelle le livreur est « arrivé ».
  final double arrivalThresholdMeters;

  /// Construit l'état de guidage pour [position] sur [route].
  ///
  /// Renvoie `null` si la route ou la position est inexploitable (tracé trop
  /// court). Dans ce cas l'appelant retombe sur le guidage à vol d'oiseau.
  NavigationState? update(RoutePlan route, GeoPoint position) {
    final geometry = route.geometry;
    if (geometry.length < 2) {
      return null;
    }

    final projection = _project(position, geometry);
    final traveled = projection.alongMeters;
    final totalMeters = projection.totalMeters;
    final remaining = math.max(0, totalMeters - traveled);

    final maneuvers = _maneuvers(route, projection);
    final target = maneuvers.firstWhere(
      (maneuver) => maneuver.alongMeters > traveled + 1,
      orElse: () => maneuvers.last,
    );

    final arrived = remaining <= arrivalThresholdMeters ||
        (target.type == 'arrive' && target.alongMeters - traveled <= arrivalThresholdMeters);

    final remainingSeconds = totalMeters <= 0
        ? 0
        : (route.durationSeconds * (remaining / totalMeters)).round();

    final nextIndex = maneuvers.indexOf(target) + 1;

    return NavigationState(
      instruction: target.instruction,
      icon: target.icon,
      distanceToManeuverMeters: math.max(0, (target.alongMeters - traveled).round()),
      remainingMeters: remaining.round(),
      remainingSeconds: remainingSeconds,
      offRoute: projection.distanceFromRoute > offRouteThresholdMeters,
      distanceFromRouteMeters: projection.distanceFromRoute.round(),
      stepIndex: target.index,
      arrived: arrived,
      nextInstruction: nextIndex < maneuvers.length ? maneuvers[nextIndex].instruction : null,
    );
  }

  /// Extrait les manœuvres de l'itinéraire avec leur distance cumulée.
  List<_Maneuver> _maneuvers(RoutePlan route, _Projection projection) {
    final maneuvers = <_Maneuver>[];
    final cumulative = _cumulativeDistances(route.geometry);

    for (var i = 0; i < route.steps.length; i++) {
      final step = route.steps[i];
      if (step.geometry.isEmpty) {
        continue;
      }
      final point = step.geometry.first;
      final along = projection.alongByPoint[_key(point.latLng)] ?? _cumulativeAt(cumulative, route.geometry, point);
      if (along == null) {
        continue;
      }
      maneuvers.add(_Maneuver(
        index: i,
        alongMeters: along,
        instruction: step.instruction.isEmpty ? _defaultInstruction(step) : step.instruction,
        type: step.type,
        icon: step.icon,
      ));
    }

    if (maneuvers.isEmpty) {
      maneuvers.add(_Maneuver(
        index: -1,
        alongMeters: cumulative.last,
        instruction: 'Continuez jusqu\'à la destination',
        type: 'continue',
        icon: Icons.straight,
      ));
    }

    maneuvers.sort((a, b) => a.alongMeters.compareTo(b.alongMeters));
    return maneuvers;
  }

  String _defaultInstruction(RouteStep step) =>
      step.name.isEmpty ? 'Continuez tout droit' : 'Continuez sur ${step.name}';

  _Projection _project(GeoPoint position, List<GeoPoint> geometry) {
    final total = _cumulativeDistances(geometry);
    var alongByPoint = <String, double>{};
    for (var i = 0; i < geometry.length; i++) {
      alongByPoint.putIfAbsent(_key(geometry[i].latLng), () => total[i]);
    }

    final p = position.latLng;
    var bestDistance = double.infinity;
    var bestAlong = 0.0;

    for (var i = 0; i < geometry.length - 1; i++) {
      final a = geometry[i].latLng;
      final b = geometry[i + 1].latLng;
      final result = _projectOnSegment(p, a, b);
      if (result.distance < bestDistance) {
        bestDistance = result.distance;
        bestAlong = total[i] + result.t * (total[i + 1] - total[i]);
      }
    }

    return _Projection(
      alongMeters: bestAlong.clamp(0, total.isEmpty ? 0 : total.last),
      totalMeters: total.isEmpty ? 0 : total.last,
      distanceFromRoute: bestDistance,
      alongByPoint: alongByPoint,
    );
  }

  double? _cumulativeAt(List<double> cumulative, List<GeoPoint> geometry, GeoPoint point) {
    for (var i = 0; i < geometry.length; i++) {
      if (geometry[i] == point) {
        return cumulative[i];
      }
    }
    return null;
  }

  List<double> _cumulativeDistances(List<GeoPoint> geometry) {
    final cumulative = <double>[0];
    for (var i = 1; i < geometry.length; i++) {
      cumulative.add(cumulative[i - 1] + distanceKm(geometry[i - 1].latLng, geometry[i].latLng) * 1000);
    }
    return cumulative;
  }

  _SegmentProjection _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    const metersPerDegLat = 111320.0;
    final cosLat = math.cos(a.latitude * math.pi / 180);
    final ax = a.longitude * metersPerDegLat * cosLat;
    final ay = a.latitude * metersPerDegLat;
    final bx = b.longitude * metersPerDegLat * cosLat;
    final by = b.latitude * metersPerDegLat;
    final px = p.longitude * metersPerDegLat * cosLat;
    final py = p.latitude * metersPerDegLat;

    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      return _SegmentProjection(0, _euclidean(px, py, ax, ay));
    }
    final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
    final projX = ax + t * dx;
    final projY = ay + t * dy;
    return _SegmentProjection(t, _euclidean(px, py, projX, projY));
  }

  double _euclidean(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  String _key(LatLng point) => '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';
}

class _Maneuver {
  const _Maneuver({
    required this.index,
    required this.alongMeters,
    required this.instruction,
    required this.type,
    required this.icon,
  });

  final int index;
  final double alongMeters;
  final String instruction;
  final String type;
  final IconData icon;
}

class _Projection {
  const _Projection({
    required this.alongMeters,
    required this.totalMeters,
    required this.distanceFromRoute,
    required this.alongByPoint,
  });

  final double alongMeters;
  final double totalMeters;
  final double distanceFromRoute;
  final Map<String, double> alongByPoint;
}

class _SegmentProjection {
  const _SegmentProjection(this.t, this.distance);

  final double t;
  final double distance;
}
