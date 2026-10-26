import 'geo_point.dart';

/// Livreur proposé après paiement, avec ses distances et temps de trajet
/// routiers (livreur → collecte, collecte → livraison).
class NearbyDriver {
  const NearbyDriver({
    required this.id,
    this.name,
    this.avatarUrl,
    this.vehicle,
    this.rating,
    this.completedDeliveries = 0,
    this.distanceToPickupKm = 0,
    this.etaToPickupSeconds,
    this.pickupToDropoffKm,
    this.etaToDropoffSeconds,
    this.distanceToDropoffKm,
    this.etaTotalSeconds,
    this.position,
  });

  final String id;
  final String? name;
  final String? avatarUrl;
  final String? vehicle;
  final double? rating;

  /// Courses et colis livrés (indicateur de confiance).
  final int completedDeliveries;
  final double distanceToPickupKm;

  /// Temps estimé livreur → point de collecte (secondes).
  final int? etaToPickupSeconds;
  final double? pickupToDropoffKm;

  /// Temps estimé point de collecte → destination (secondes).
  final int? etaToDropoffSeconds;

  /// Distance totale livreur → destination (km, via collecte).
  final double? distanceToDropoffKm;

  /// Temps total estimé livreur → destination (secondes).
  final int? etaTotalSeconds;
  final DriverLivePosition? position;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : 'Livreur';

  factory NearbyDriver.fromJson(Map<String, dynamic> json) => NearbyDriver(
    id: _s(json['id']),
    name: _stringOrNull(json['name']),
    avatarUrl: _stringOrNull(json['avatar_url']),
    vehicle: _stringOrNull(json['vehicle']),
    rating: _dNull(json['rating']),
    completedDeliveries: _i(json['completed_deliveries']),
    distanceToPickupKm: _d(json['distance_to_pickup_km']),
    etaToPickupSeconds: _iNull(json['eta_to_pickup_s']),
    pickupToDropoffKm: _dNull(json['pickup_to_dropoff_km']),
    etaToDropoffSeconds: _iNull(json['eta_to_dropoff_s']),
    distanceToDropoffKm: _dNull(json['distance_to_dropoff_km']),
    etaTotalSeconds: _iNull(json['eta_total_s']),
    position: json['position'] is Map<String, dynamic>
        ? DriverLivePosition.fromJson(json['position'] as Map<String, dynamic>)
        : null,
  );
}

/// Dernière position GPS connue d'un livreur proche (sans téléphone).
class DriverLivePosition {
  const DriverLivePosition({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.lastLocationAt,
    this.ageSeconds,
  });

  final double latitude;
  final double longitude;
  final double? heading;
  final String? lastLocationAt;
  final int? ageSeconds;

  GeoPoint get point => GeoPoint(latitude, longitude);

  factory DriverLivePosition.fromJson(Map<String, dynamic> json) =>
      DriverLivePosition(
        latitude: _d(json['latitude']),
        longitude: _d(json['longitude']),
        heading: _dNull(json['heading']),
        lastLocationAt: _stringOrNull(json['last_location_at']),
        ageSeconds: _iNull(json['age_seconds']),
      );
}

/// Lieu de collecte ou de livraison renvoyé avec la sélection.
class DriverSelectionPlace {
  const DriverSelectionPlace({
    this.latitude,
    this.longitude,
    this.address,
    this.landmark,
    this.city,
  });

  final double? latitude;
  final double? longitude;
  final String? address;
  final String? landmark;
  final String? city;

  GeoPoint? get point => latitude != null && longitude != null
      ? GeoPoint(latitude!, longitude!)
      : null;

  String get display {
    final parts = [
      address,
      if (landmark != null && landmark!.trim().isNotEmpty)
        'près de ${landmark!.trim()}',
      city,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Adresse non précisée' : parts.join(' · ');
  }

  factory DriverSelectionPlace.fromJson(Map<String, dynamic> json) =>
      DriverSelectionPlace(
        latitude: _dNull(json['latitude']),
        longitude: _dNull(json['longitude']),
        address: _stringOrNull(json['address']),
        landmark: _stringOrNull(json['landmark']),
        city: _stringOrNull(json['city']),
      );
}

/// Demande explicite adressée à un livreur proche.
class DriverRequestInfo {
  const DriverRequestInfo({
    required this.id,
    required this.status,
    this.driver,
    this.offeredAt,
    this.expiresAt,
    this.secondsRemaining,
    this.respondedAt,
    this.refusalReason,
    this.createdAt,
  });

  final String id;

  /// `pending`, `accepted`, `refused`, `expired` ou `cancelled`.
  final String status;
  final DriverRequestDriver? driver;
  final String? offeredAt;
  final String? expiresAt;
  final int? secondsRemaining;
  final String? respondedAt;
  final String? refusalReason;
  final String? createdAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRefused => status == 'refused';
  bool get isExpired => status == 'expired';
  bool get isCancelled => status == 'cancelled';

  /// Demande enregistrée avant que la commande soit prête : le délai de
  /// réponse ne démarrera qu'à l'ouverture de l'offre.
  bool get waitsForReady => isPending && offeredAt == null;

  factory DriverRequestInfo.fromJson(Map<String, dynamic> json) =>
      DriverRequestInfo(
        id: _s(json['id']),
        status: _s(json['status']),
        driver: json['driver'] is Map<String, dynamic>
            ? DriverRequestDriver.fromJson(
                json['driver'] as Map<String, dynamic>,
              )
            : null,
        offeredAt: _stringOrNull(json['offered_at']),
        expiresAt: _stringOrNull(json['expires_at']),
        secondsRemaining: _iNull(json['seconds_remaining']),
        respondedAt: _stringOrNull(json['responded_at']),
        refusalReason: _stringOrNull(json['refusal_reason']),
        createdAt: _stringOrNull(json['created_at']),
      );
}

/// Identité minimale du livreur sollicité (aucun numéro avant affectation).
class DriverRequestDriver {
  const DriverRequestDriver({
    required this.id,
    this.name,
    this.avatarUrl,
    this.vehicle,
    this.rating,
  });

  final String id;
  final String? name;
  final String? avatarUrl;
  final String? vehicle;
  final double? rating;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : 'Livreur';

  factory DriverRequestDriver.fromJson(Map<String, dynamic> json) =>
      DriverRequestDriver(
        id: _s(json['id']),
        name: _stringOrNull(json['name']),
        avatarUrl: _stringOrNull(json['avatar_url']),
        vehicle: _stringOrNull(json['vehicle']),
        rating: _dNull(json['rating']),
      );
}

/// Réponse complète de `GET /orders/{id}/nearby-drivers` (ou colis).
class DriverSelectionPage {
  const DriverSelectionPage({
    this.pickup,
    this.dropoff,
    this.radiusKm = 0,
    this.requestedRadiusKm = 0,
    this.maxRadiusKm = 0,
    this.expanded = false,
    this.drivers = const [],
    this.request,
  });

  final DriverSelectionPlace? pickup;
  final DriverSelectionPlace? dropoff;
  final double radiusKm;
  final double requestedRadiusKm;
  final double maxRadiusKm;

  /// `true` si le rayon a été élargi faute de livreur dans le rayon initial.
  final bool expanded;
  final List<NearbyDriver> drivers;
  final DriverRequestInfo? request;

  factory DriverSelectionPage.fromJson(Map<String, dynamic> json) {
    final rawDrivers = json['drivers'];
    return DriverSelectionPage(
      pickup: json['pickup'] is Map<String, dynamic>
          ? DriverSelectionPlace.fromJson(
              json['pickup'] as Map<String, dynamic>,
            )
          : null,
      dropoff: json['dropoff'] is Map<String, dynamic>
          ? DriverSelectionPlace.fromJson(
              json['dropoff'] as Map<String, dynamic>,
            )
          : null,
      radiusKm: _d(json['radius_km']),
      requestedRadiusKm: _d(json['requested_radius_km']),
      maxRadiusKm: _d(json['max_radius_km']),
      expanded: json['expanded'] == true,
      drivers: rawDrivers is List
          ? rawDrivers
                .whereType<Map<String, dynamic>>()
                .map(NearbyDriver.fromJson)
                .toList()
          : const [],
      request: json['request'] is Map<String, dynamic>
          ? DriverRequestInfo.fromJson(json['request'] as Map<String, dynamic>)
          : null,
    );
  }
}

String _s(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;

String? _stringOrNull(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

double _d(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _dNull(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

int _i(dynamic value) => _iNull(value) ?? 0;

int? _iNull(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}
