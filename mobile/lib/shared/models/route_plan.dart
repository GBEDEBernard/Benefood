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
  });

  final String provider;
  final int distanceMeters;
  final int durationSeconds;

  /// Polyligne du trajet, du départ vers l'arrivée.
  final List<GeoPoint> geometry;

  /// Détail par tronçon (A→B, B→C…).
  final List<RouteLeg> legs;

  /// `false` quand aucun tracé routier n'a pu être obtenu (ligne droite).
  bool get isRouted => provider != 'straight';

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

    return RoutePlan(
      provider: json['provider'] is String ? json['provider'] as String : 'straight',
      distanceMeters: _i(json['distance_m']),
      durationSeconds: _i(json['duration_s']),
      geometry: geometry,
      legs: legs,
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
