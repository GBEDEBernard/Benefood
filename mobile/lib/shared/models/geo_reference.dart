/// Référentiel géographique officiel partagé (API `/geo/*`).
///
/// Les identifiants sont ceux du référentiel serveur : ils restent stables
/// même lorsqu'une localité change de nom. Aucune localité n'est créée côté
/// client.
class GeoCountry {
  const GeoCountry({
    required this.id,
    required this.code,
    required this.name,
    this.officialName,
    this.hierarchy = const [],
    this.localityLabel,
    this.source,
    this.sourceUrl,
    this.dataUpdatedAt,
  });

  final String id;
  final String code;
  final String name;
  final String? officialName;
  final List<GeoLevel> hierarchy;
  final String? localityLabel;
  final String? source;
  final String? sourceUrl;
  final String? dataUpdatedAt;

  factory GeoCountry.fromJson(Map<String, dynamic> json) => GeoCountry(
        id: _s(json['id']),
        code: _s(json['code']).toUpperCase(),
        name: _s(json['name']),
        officialName: _sOrNull(json['official_name']),
        hierarchy: (json['hierarchy'] is List)
            ? (json['hierarchy'] as List)
                .whereType<Map<String, dynamic>>()
                .map(GeoLevel.fromJson)
                .toList(growable: false)
            : const [],
        localityLabel: _sOrNull(json['locality_label']),
        source: _sOrNull(json['source']),
        sourceUrl: _sOrNull(json['source_url']),
        dataUpdatedAt: _sOrNull(json['data_updated_at']),
      );
}

/// Niveau administratif configurable d'un pays (`department`, `commune`…).
class GeoLevel {
  const GeoLevel({required this.slug, required this.label, this.plural});

  final String slug;
  final String label;
  final String? plural;

  factory GeoLevel.fromJson(Map<String, dynamic> json) => GeoLevel(
        slug: _s(json['slug']),
        label: _s(json['label']),
        plural: _sOrNull(json['plural']),
      );
}

/// Subdivision administrative (département, commune, arrondissement…).
class GeoDivision {
  const GeoDivision({
    required this.id,
    required this.countryId,
    this.parentId,
    required this.level,
    required this.code,
    required this.name,
    this.path = const [],
    this.label,
    this.latitude,
    this.longitude,
    this.source,
    this.sourceUrl,
    this.dataUpdatedAt,
  });

  final String id;
  final String countryId;
  final String? parentId;
  final String level;
  final String code;
  final String name;
  final List<String> path;
  final String? label;
  final double? latitude;
  final double? longitude;
  final String? source;
  final String? sourceUrl;
  final String? dataUpdatedAt;

  String get display => label ?? path.join(' › ');

  factory GeoDivision.fromJson(Map<String, dynamic> json) => GeoDivision(
        id: _s(json['id']),
        countryId: _s(json['country_id']),
        parentId: _sOrNull(json['parent_id']),
        level: _s(json['level']),
        code: _s(json['code']),
        name: _s(json['name']),
        path: (json['path'] is List)
            ? (json['path'] as List).map((e) => e.toString()).toList(growable: false)
            : const [],
        label: _sOrNull(json['label']),
        latitude: _d(json['center'] is Map ? json['center']['latitude'] : json['latitude']),
        longitude: _d(json['center'] is Map ? json['center']['longitude'] : json['longitude']),
        source: _sOrNull(json['source']),
        sourceUrl: _sOrNull(json['source_url']),
        dataUpdatedAt: _sOrNull(json['data_updated_at']),
      );
}

/// Localité officielle : village, quartier, hameau ou ville.
class GeoLocality {
  const GeoLocality({
    required this.id,
    required this.countryId,
    required this.divisionId,
    required this.code,
    required this.name,
    this.kind,
    this.administrativeStatus,
    this.label,
    this.latitude,
    this.longitude,
    this.source,
    this.sourceUrl,
    this.dataUpdatedAt,
  });

  final String id;
  final String countryId;
  final String divisionId;
  final String code;
  final String name;
  final String? kind;
  final String? administrativeStatus;
  final String? label;
  final double? latitude;
  final double? longitude;
  final String? source;
  final String? sourceUrl;
  final String? dataUpdatedAt;

  String get display => label ?? name;

  factory GeoLocality.fromJson(Map<String, dynamic> json) => GeoLocality(
        id: _s(json['id']),
        countryId: _s(json['country_id']),
        divisionId: _s(json['division_id']),
        code: _s(json['code']),
        name: _s(json['name']),
        kind: _sOrNull(json['kind']),
        administrativeStatus: _sOrNull(json['administrative_status']),
        label: _sOrNull(json['label']),
        latitude: _d(json['latitude']),
        longitude: _d(json['longitude']),
        source: _sOrNull(json['source']),
        sourceUrl: _sOrNull(json['source_url']),
        dataUpdatedAt: _sOrNull(json['data_updated_at']),
      );
}

/// Résultat de recherche ou de géocodage (localité ou subdivision).
class GeoPlace {
  const GeoPlace({
    required this.kind,
    required this.id,
    required this.name,
    this.label,
    this.level,
    this.localityKind,
    this.code,
    this.path = const [],
    this.latitude,
    this.longitude,
    this.components = const {},
    this.provider,
    this.source,
    this.sourceUrl,
    this.dataUpdatedAt,
  });

  final String kind;
  final String id;
  final String name;
  final String? label;
  final String? level;
  final String? localityKind;
  final String? code;
  final List<String> path;
  final double? latitude;
  final double? longitude;
  final Map<String, String?> components;
  final String? provider;
  final String? source;
  final String? sourceUrl;
  final String? dataUpdatedAt;

  String get display => label ?? path.join(' › ');

  bool get isLocality => kind == 'locality';

  factory GeoPlace.fromJson(Map<String, dynamic> json) => GeoPlace(
        kind: _s(json['kind']),
        id: _s(json['id']),
        name: _s(json['name']),
        label: _sOrNull(json['label']),
        level: _sOrNull(json['level']),
        localityKind: _sOrNull(json['locality_kind']),
        code: _sOrNull(json['code']),
        path: (json['path'] is List)
            ? (json['path'] as List).map((e) => e.toString()).toList(growable: false)
            : const [],
        latitude: _d(json['latitude']),
        longitude: _d(json['longitude']),
        components: (json['components'] is Map)
            ? (json['components'] as Map).map(
                (key, value) => MapEntry(key.toString(), value?.toString()),
              )
            : const {},
        provider: _sOrNull(json['provider']),
        source: _sOrNull(json['source']),
        sourceUrl: _sOrNull(json['source_url']),
        dataUpdatedAt: _sOrNull(json['data_updated_at']),
      );

  /// Référence à transmettre au backend lors d'une création/modification.
  GeoReferenceSelection? toSelection(
    String? countryCode, {
    String source = 'geocoded',
  }) {
    if (id.isEmpty) {
      return null;
    }
    return GeoReferenceSelection(
      countryCode: countryCode,
      divisionId: isLocality ? null : id,
      localityId: isLocality ? id : null,
      latitude: latitude,
      longitude: longitude,
      source: source,
    );
  }
}

/// Réponse de `/geo/geocode` : fournisseur utilisé + candidats.
class GeoGeocodeResult {
  const GeoGeocodeResult({required this.provider, required this.results});

  final String provider;
  final List<GeoPlace> results;

  factory GeoGeocodeResult.fromJson(Map<String, dynamic> json) => GeoGeocodeResult(
        provider: _s(json['provider']),
        results: (json['results'] is List)
            ? (json['results'] as List)
                .whereType<Map<String, dynamic>>()
                .map(GeoPlace.fromJson)
                .toList(growable: false)
            : const [],
      );
}

/// Page de résultats avec métadonnées de pagination.
class GeoPage<T> {
  const GeoPage({required this.items, required this.meta});

  final List<T> items;
  final GeoPageMeta meta;

  bool get hasMore => meta.currentPage < meta.lastPage;
}

class GeoPageMeta {
  const GeoPageMeta({
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 15,
    this.total = 0,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory GeoPageMeta.fromJson(Map<String, dynamic>? json) {
    final meta = json ?? const <String, dynamic>{};
    return GeoPageMeta(
      currentPage: _i(meta['current_page']) ?? 1,
      lastPage: _i(meta['last_page']) ?? 1,
      perPage: _i(meta['per_page']) ?? 15,
      total: _i(meta['total']) ?? 0,
    );
  }
}

/// Sélection hiérarchique envoyée aux endpoints métier.
class GeoReferenceSelection {
  const GeoReferenceSelection({
    this.countryCode,
    this.divisionId,
    this.localityId,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.source,
    this.recordedAt,
    this.pickupDivisionId,
    this.pickupLocalityId,
    this.pickupAccuracyM,
  });

  final String? countryCode;
  final String? divisionId;
  final String? localityId;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final String? source;
  final DateTime? recordedAt;
  final String? pickupDivisionId;
  final String? pickupLocalityId;
  final double? pickupAccuracyM;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasReference =>
      countryCode != null || divisionId != null || localityId != null;

  /// Reconstitue une référence depuis les ressources API (`geo`, `pickup_geo`)
  /// ou depuis leurs alias plats (`country_code`, `division_id`…).
  factory GeoReferenceSelection.fromApiPayload(
    Map<String, dynamic> json, {
    String prefix = '',
  }) {
    final nestedKey = prefix.isEmpty ? 'geo' : '${prefix}geo';
    final nested = json[nestedKey] is Map
        ? Map<String, dynamic>.from(json[nestedKey] as Map)
        : const <String, dynamic>{};
    final country = nested['country'] is Map
        ? Map<String, dynamic>.from(nested['country'] as Map)
        : const <String, dynamic>{};
    final division = nested['division'] is Map
        ? Map<String, dynamic>.from(nested['division'] as Map)
        : const <String, dynamic>{};
    final locality = nested['locality'] is Map
        ? Map<String, dynamic>.from(nested['locality'] as Map)
        : const <String, dynamic>{};

    return GeoReferenceSelection(
      countryCode: _sOrNull(country['code']) ??
          _sOrNull(json['${prefix}country_code']),
      divisionId: _stringId(division['id']) ??
          _stringId(json['${prefix}division_id']),
      localityId: _stringId(locality['id']) ??
          _stringId(json['${prefix}locality_id']),
      accuracyM: _d(nested['gps_accuracy_m'] ??
          json['${prefix}gps_accuracy_m']),
      source: _sOrNull(nested['location_source'] ??
          json['location_source']),
      recordedAt: _dateTime(nested['location_recorded_at'] ??
          json['${prefix}location_recorded_at']),
    );
  }

  /// Champs principaux (`country_code`, `division_id`, `locality_id`…).
  Map<String, dynamic> toJson() => {
        if (countryCode != null && countryCode!.isNotEmpty) 'country_code': countryCode,
        if (divisionId != null && divisionId!.isNotEmpty) 'division_id': divisionId,
        if (localityId != null && localityId!.isNotEmpty) 'locality_id': localityId,
        if (accuracyM != null) 'gps_accuracy_m': accuracyM,
        if (source != null && source!.isNotEmpty) 'location_source': source,
        if (recordedAt != null) 'location_recorded_at': recordedAt!.toIso8601String(),
      };

  /// Champs du point de retrait d'une boutique.
  Map<String, dynamic> toPickupJson() => {
        if (pickupDivisionId != null && pickupDivisionId!.isNotEmpty)
          'pickup_division_id': pickupDivisionId,
        if (pickupLocalityId != null && pickupLocalityId!.isNotEmpty)
          'pickup_locality_id': pickupLocalityId,
        if (pickupAccuracyM != null) 'pickup_gps_accuracy_m': pickupAccuracyM,
        if (source != null && source!.isNotEmpty) 'location_source': source,
        if (recordedAt != null) 'location_recorded_at': recordedAt!.toIso8601String(),
      };
}

String _s(dynamic value) => value is String ? value : '';

String? _sOrNull(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

double? _d(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int? _i(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

String? _stringId(dynamic value) {
  if (value is num) {
    return value.toInt().toString();
  }
  return _sOrNull(value);
}

DateTime? _dateTime(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
