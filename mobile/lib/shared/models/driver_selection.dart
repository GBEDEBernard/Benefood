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
    this.approachFee,
    this.approachDistanceKm,
    this.approachBillableKm,
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

  /// Frais d'approche estimés pour rejoindre le point de collecte.
  final int? approachFee;
  final double? approachDistanceKm;
  final double? approachBillableKm;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : 'Livreur';

  /// Âge de la dernière position GPS connue (secondes).
  int? get positionAgeSeconds => position?.ageSeconds;

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
    approachFee: _iNull(json['approach_fee']),
    approachDistanceKm: _dNull(json['approach_distance_km']),
    approachBillableKm: _dNull(json['approach_billable_km']),
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
    this.name,
    this.latitude,
    this.longitude,
    this.address,
    this.landmark,
    this.city,
  });

  /// Nom du commerce (collecte) ou libellé de l'adresse (livraison).
  final String? name;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? landmark;
  final String? city;

  GeoPoint? get point => latitude != null && longitude != null
      ? GeoPoint(latitude!, longitude!)
      : null;

  /// Titre mis en avant : nom du commerce / libellé de l'adresse.
  String get title {
    for (final candidate in [name, address, city]) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return 'Adresse non précisée';
  }

  /// Ligne secondaire : adresse complète, point de repère et ville.
  String get subtitle {
    final parts = [
      if (address != null && address != name) address,
      if (landmark != null && landmark!.trim().isNotEmpty)
        'près de ${landmark!.trim()}',
      city,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? ' ' : parts.join(' · ');
  }

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
        name: _stringOrNull(json['name']),
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

/// Compteurs de disponibilité renvoyés par la recherche : ils permettent de
/// distinguer « aucun livreur », « GPS absent » et « GPS périmé ».
class DriverSelectionDiagnostics {
  const DriverSelectionDiagnostics({
    this.onlineDrivers = 0,
    this.withPosition = 0,
    this.freshPosition = 0,
    this.stalePosition = 0,
    this.withoutPosition = 0,
    this.withinMaxRadius = 0,
    this.maxRadiusKm = 0,
    this.locationMaxAgeSeconds = 0,
  });

  static const empty = DriverSelectionDiagnostics();

  final int onlineDrivers;
  final int withPosition;
  final int freshPosition;
  final int stalePosition;
  final int withoutPosition;
  final int withinMaxRadius;
  final double maxRadiusKm;
  final int locationMaxAgeSeconds;

  bool get hasOnlineDrivers => onlineDrivers > 0;

  /// Des livreurs sont en ligne mais aucun ne possède de position exploitable.
  bool get hasPositionIssue =>
      hasOnlineDrivers &&
      freshPosition == 0 &&
      (stalePosition > 0 || withoutPosition > 0);

  factory DriverSelectionDiagnostics.fromJson(Map<String, dynamic> json) =>
      DriverSelectionDiagnostics(
        onlineDrivers: _i(json['online_drivers']),
        withPosition: _i(json['with_position']),
        freshPosition: _i(json['fresh_position']),
        stalePosition: _i(json['stale_position']),
        withoutPosition: _i(json['without_position']),
        withinMaxRadius: _i(json['within_max_radius']),
        maxRadiusKm: _d(json['max_radius_km']),
        locationMaxAgeSeconds: _i(json['location_max_age_s']),
      );
}

/// Réponse complète de `GET /orders/{id}/nearby-drivers` (ou colis).
class DriverSelectionPage {
  const DriverSelectionPage({
    this.pickup,
    this.dropoff,
    this.tripDistanceKm,
    this.tripDurationSeconds,
    this.radiusKm = 0,
    this.requestedRadiusKm = 0,
    this.maxRadiusKm = 0,
    this.expanded = false,
    this.drivers = const [],
    this.diagnostics = DriverSelectionDiagnostics.empty,
    this.request,
  });

  final DriverSelectionPlace? pickup;
  final DriverSelectionPlace? dropoff;

  /// Distance routière collecte → adresse du client.
  final double? tripDistanceKm;
  final int? tripDurationSeconds;
  final double radiusKm;
  final double requestedRadiusKm;
  final double maxRadiusKm;

  /// `true` si le rayon a été élargi faute de livreur dans le rayon initial.
  final bool expanded;
  final List<NearbyDriver> drivers;
  final DriverSelectionDiagnostics diagnostics;
  final DriverRequestInfo? request;

  factory DriverSelectionPage.fromJson(Map<String, dynamic> json) {
    final rawDrivers = json['drivers'];
    final rawTrip = json['trip'];
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
      tripDistanceKm: rawTrip is Map<String, dynamic>
          ? _dNull(rawTrip['distance_km'])
          : null,
      tripDurationSeconds: rawTrip is Map<String, dynamic>
          ? _iNull(rawTrip['duration_s'])
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
      diagnostics: json['diagnostics'] is Map<String, dynamic>
          ? DriverSelectionDiagnostics.fromJson(
              json['diagnostics'] as Map<String, dynamic>,
            )
          : DriverSelectionDiagnostics.empty,
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
