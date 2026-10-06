import 'package:latlong2/latlong.dart';

/// Point géographique simple (latitude / longitude).
///
/// Enveloppe les coordonnées reçues de l'API pour éviter de propager des
/// `double?` dans les écrans (carte, guidage, distance).
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => '$latitude, $longitude';
}

/// Adresse figée au moment de la commande (`orders.address_snapshot`).
///
/// L'API renvoie un objet JSON :
/// `{label, full_address, landmark, city, area, latitude, longitude, notes}`.
/// Certaines commandes antérieures ou adresses saisies sans coordonnées
/// n'ont pas de `latitude`/`longitude` : [hasCoordinates] le signale.
class AddressSnapshot {
  const AddressSnapshot({
    this.label,
    this.fullAddress,
    this.landmark,
    this.city,
    this.area,
    this.latitude,
    this.longitude,
    this.notes,
  });

  final String? label;
  final String? fullAddress;
  final String? landmark;
  final String? city;
  final String? area;
  final double? latitude;
  final double? longitude;
  final String? notes;

  bool get hasCoordinates => latitude != null && longitude != null;

  GeoPoint? get point => hasCoordinates ? GeoPoint(latitude!, longitude!) : null;

  /// Libellé lisible pour l'UI : quartier + rue, puis la ville.
  /// Renvoie une chaîne vide si l'adresse ne contient aucun texte exploitable.
  String get display {
    final parts = <String>[
      if (fullAddress != null && fullAddress!.trim().isNotEmpty) fullAddress!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
    ];
    if (parts.isEmpty) {
      return landmark?.trim() ?? '';
    }
    return parts.join(', ');
  }

  factory AddressSnapshot.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return AddressSnapshot(
        label: _s(json['label']),
        fullAddress: _s(json['full_address']),
        landmark: _s(json['landmark']),
        city: _s(json['city']),
        area: _s(json['area']),
        latitude: _d(json['latitude']),
        longitude: _d(json['longitude']),
        notes: _s(json['notes']),
      );
    }
    // Ancienne forme : une simple chaîne.
    if (json is String && json.trim().isNotEmpty) {
      return AddressSnapshot(fullAddress: json);
    }
    return const AddressSnapshot();
  }
}

String? _s(dynamic value) => value is String && value.trim().isNotEmpty ? value.trim() : null;

double? _d(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}