/// Lecture légère du suivi d'une mission active.
///
/// Ce modèle ne remplace pas les ressources détaillées : il ne conserve que les
/// trois positions, les distances calculées côté serveur et le `position`
/// historique consommé par les écrans existants.
class DeliveryTrackingSnapshot {
  const DeliveryTrackingSnapshot({
    required this.active,
    this.status,
    this.points = const {},
    this.straightKm = const {},
    this.roadDistanceM,
    this.roadProvider,
    this.roadDurationS,
    this.etaSeconds,
    this.etaMinutes,
    this.etaAvailable = false,
    this.legacyPosition,
  });

  final bool active;
  final String? status;
  final Map<String, TrackingPoint> points;
  final Map<String, double?> straightKm;
  final int? roadDistanceM;
  final String? roadProvider;
  final int? roadDurationS;
  final int? etaSeconds;
  final int? etaMinutes;
  final bool etaAvailable;

  /// Payload au format historique `position` des ressources `Order`/`Parcel`.
  final Map<String, dynamic>? legacyPosition;

  TrackingPoint? point(String role) => points[role];

  GeoPointLike? pointLocation(String role) => points[role]?.location;

  factory DeliveryTrackingSnapshot.fromJson(Map<String, dynamic> json) {
    final points = <String, TrackingPoint>{};
    if (json['points'] is Map) {
      (json['points'] as Map).forEach((key, value) {
        if (value is Map<String, dynamic>) {
          points[key.toString()] = TrackingPoint.fromJson(value);
        }
      });
    }

    final straight = <String, double?>{};
    final distances = json['distances'] is Map
        ? json['distances'] as Map
        : const <dynamic, dynamic>{};
    if (distances['straight_km'] is Map) {
      (distances['straight_km'] as Map).forEach((key, value) {
        straight[key.toString()] = _doubleOrNull(value);
      });
    }

    final eta = json['eta'] is Map<String, dynamic>
        ? json['eta'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return DeliveryTrackingSnapshot(
      active: json['active'] == true,
      status: _stringOrNull(json['status']),
      points: points,
      straightKm: straight,
      roadDistanceM: _intOrNull(distances['road_m']),
      roadProvider: _stringOrNull(distances['road_provider']),
      roadDurationS: _intOrNull(distances['road_duration_s']),
      etaSeconds: _intOrNull(eta['seconds']),
      etaMinutes: _intOrNull(eta['minutes']),
      etaAvailable: eta['available'] == true,
      legacyPosition: json['legacy_position'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['legacy_position'] as Map)
          : null,
    );
  }
}

/// Une des trois positions du suivi : client, boutique ou livreur.
class TrackingPoint {
  const TrackingPoint({
    required this.role,
    this.location,
    this.label,
  });

  final String role;
  final GeoPointLike? location;
  final String? label;

  factory TrackingPoint.fromJson(Map<String, dynamic> json) => TrackingPoint(
        role: _stringOrNull(json['role']) ?? '',
        location: TrackingPoint._location(json),
        label: _stringOrNull(json['label']),
      );

  static GeoPointLike? _location(Map<String, dynamic> json) {
    final latitude = _doubleOrNull(json['latitude']);
    final longitude = _doubleOrNull(json['longitude']);
    if (latitude == null || longitude == null) {
      return null;
    }
    return GeoPointLike(latitude: latitude, longitude: longitude);
  }
}

/// Coordonnées minimales, sans dépendance vers le widget de carte.
class GeoPointLike {
  const GeoPointLike({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

double? _doubleOrNull(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int? _intOrNull(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

String? _stringOrNull(dynamic value) =>
    value is String && value.isNotEmpty ? value : null;
