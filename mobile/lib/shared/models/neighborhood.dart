/// Quartier d'une ville (référentiel GET /locations).
class Neighborhood {
  const Neighborhood({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final double? latitude;
  final double? longitude;

  factory Neighborhood.fromJson(Map<String, dynamic> json) => Neighborhood(
        id: json['id'] is String ? json['id'] as String : '',
        name: json['name'] is String ? json['name'] as String : '',
        latitude: _d(json['latitude']),
        longitude: _d(json['longitude']),
      );
}

/// Ville et ses quartiers (GET /locations).
class LocationCity {
  const LocationCity({required this.city, required this.neighborhoods});

  final String city;
  final List<Neighborhood> neighborhoods;

  factory LocationCity.fromJson(Map<String, dynamic> json) => LocationCity(
        city: json['city'] is String ? json['city'] as String : '',
        neighborhoods: (json['neighborhoods'] is List)
            ? (json['neighborhoods'] as List)
                .whereType<Map<String, dynamic>>()
                .map(Neighborhood.fromJson)
                .toList(growable: false)
            : const [],
      );

  Neighborhood? neighborhoodNamed(String? name) {
    if (name == null) {
      return null;
    }
    for (final neighborhood in neighborhoods) {
      if (neighborhood.name == name) {
        return neighborhood;
      }
    }
    return null;
  }
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
