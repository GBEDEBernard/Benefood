import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'geo_point.dart';

/// Itinéraire routier calculé par le serveur (navigation livreur, suivi client).
///
/// `provider` vaut `google` (Routes API, mode deux-roues), `osrm` (routage
/// routier) ou `straight` (repli ligne droite si le réseau est indisponible).
class RoutePlan {
  const RoutePlan({
    required this.provider,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.geometry,
    this.legs = const [],
    this.steps = const [],
  });

  final String provider;
  final int distanceMeters;
  final int durationSeconds;

  /// Polyligne du trajet, du départ vers l'arrivée.
  final List<GeoPoint> geometry;

  /// Détail par tronçon (A→B, B→C…).
  final List<RouteLeg> legs;

  /// Instructions de manœuvre (guidage tour-par-tour), dans l'ordre.
  final List<RouteStep> steps;

  /// `false` quand aucun tracé routier n'a pu être obtenu (ligne droite).
  bool get isRouted => provider != 'straight';

  /// Vrai quand un guidage tour-par-tour est disponible.
  bool get hasSteps => steps.isNotEmpty;

  double get distanceKm => distanceMeters / 1000;

  /// Durée estimée en minutes (arrondie), `null` si inconnue.
  int? get etaMinutes {
    if (durationSeconds <= 0) {
      return null;
    }
    return (durationSeconds / 60).round().clamp(1, 999);
  }

  List<LatLng> get latLng => geometry.map((point) => point.latLng).toList(growable: false);

  factory RoutePlan.fromJson(Map<String, dynamic> json) {
    final rawGeometry = json['geometry'];
    final geometry = <GeoPoint>[];
    if (rawGeometry is List) {
      for (final point in rawGeometry) {
        if (point is List && point.length >= 2) {
          final lat = _d(point[0]);
          final lng = _d(point[1]);
          if (lat != null && lng != null) {
            geometry.add(GeoPoint(lat, lng));
          }
        }
      }
    }

    final rawLegs = json['legs'];
    final legs = <RouteLeg>[];
    if (rawLegs is List) {
      for (final leg in rawLegs.whereType<Map<String, dynamic>>()) {
        legs.add(RouteLeg.fromJson(leg));
      }
    }

    final rawSteps = json['steps'];
    final steps = <RouteStep>[];
    if (rawSteps is List) {
      for (final step in rawSteps.whereType<Map<String, dynamic>>()) {
        steps.add(RouteStep.fromJson(step));
      }
    }

    return RoutePlan(
      provider: json['provider'] is String ? json['provider'] as String : 'straight',
      distanceMeters: _i(json['distance_m']),
      durationSeconds: _i(json['duration_s']),
      geometry: geometry,
      legs: legs,
      steps: steps,
    );
  }
}

/// Instruction de manœuvre d'un itinéraire (guidage tour-par-tour).
///
/// `type` et `modifier` suivent la taxonomie OSRM (`turn`, `roundabout`,
/// `depart`, `arrive`… / `left`, `slight right`, `uturn`…). `instruction` est
/// le texte en français prêt à afficher et à prononcer.
class RouteStep {
  const RouteStep({
    required this.type,
    required this.instruction,
    required this.name,
    required this.distanceMeters,
    required this.durationSeconds,
    this.modifier,
    this.geometry = const [],
  });

  final String type;
  final String? modifier;
  final String instruction;
  final String name;
  final int distanceMeters;
  final int durationSeconds;

  /// Géométrie du segment parcouru jusqu'à la manœuvre suivante.
  final List<GeoPoint> geometry;

  List<LatLng> get latLng => geometry.map((point) => point.latLng).toList(growable: false);

  /// Icône de flèche directionnelle correspondant à la manœuvre.
  IconData get icon {
    return switch (type) {
      'depart' => Icons.trip_origin,
      'arrive' => Icons.flag,
      'merge' => Icons.merge,
      'on ramp' => Icons.ramp_right,
      'off ramp' => Icons.ramp_left,
      'fork' => modifier == 'left' ? Icons.fork_left : Icons.fork_right,
      'roundabout' => Icons.roundabout_left,
      'rotary' => Icons.roundabout_left,
      _ => switch (modifier) {
          'left' => Icons.turn_left,
          'slight left' => Icons.turn_slight_left,
          'sharp left' => Icons.turn_sharp_left,
          'right' => Icons.turn_right,
          'slight right' => Icons.turn_slight_right,
          'sharp right' => Icons.turn_sharp_right,
          'uturn' => Icons.u_turn_left,
          'straight' => Icons.straight,
          _ => Icons.straight,
        },
    };
  }

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    final rawGeometry = json['geometry'];
    final geometry = <GeoPoint>[];
    if (rawGeometry is List) {
      for (final point in rawGeometry) {
        if (point is List && point.length >= 2) {
          final lat = _d(point[0]);
          final lng = _d(point[1]);
          if (lat != null && lng != null) {
            geometry.add(GeoPoint(lat, lng));
          }
        }
      }
    }

    return RouteStep(
      type: json['type'] is String ? json['type'] as String : 'continue',
      modifier: json['modifier'] is String ? json['modifier'] as String : null,
      instruction: json['instruction'] is String ? json['instruction'] as String : '',
      name: json['name'] is String ? json['name'] as String : '',
      distanceMeters: _i(json['distance_m']),
      durationSeconds: _i(json['duration_s']),
      geometry: geometry,
    );
  }
}

/// Tronçon d'itinéraire (distance + durée).
class RouteLeg {
  const RouteLeg({required this.distanceMeters, required this.durationSeconds});

  final int distanceMeters;
  final int durationSeconds;

  factory RouteLeg.fromJson(Map<String, dynamic> json) => RouteLeg(
        distanceMeters: _i(json['distance_m']),
        durationSeconds: _i(json['duration_s']),
      );
}

int _i(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

double? _d(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
