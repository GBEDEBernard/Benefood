import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Résultat de la localisation : coordonnées + adresse approximative.
class GeoResult {
  const GeoResult({
    required this.latitude,
    required this.longitude,
    this.city,
    this.area,
    this.accuracyM,
    this.speedMps,
    this.heading,
    this.source = 'gps',
    this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final String? city;
  final String? area;

  /// Précision horizontale en mètres (fournie par le système GPS).
  final double? accuracyM;

  /// Vitesse instantanée en mètres/seconde.
  final double? speedMps;

  /// Cap en degrés (0 = nord).
  final double? heading;

  /// Origine du relevé : `gps`, `network` ou `manual`.
  final String source;
  final DateTime? recordedAt;

  /// Une position trop imprécise ne doit pas être transmise comme suivi direct.
  bool get isPrecise => accuracyM == null || accuracyM! <= 100;

  /// Métadonnées acceptées par `PATCH /driver/me/availability/location`.
  Map<String, dynamic> get trackingFields => {
        if (accuracyM != null && isPrecise) 'accuracy_m': accuracyM,
        if (speedMps != null) 'speed_mps': speedMps,
        if (heading != null) 'heading': heading,
        'location_source': source,
        if (recordedAt != null) 'location_recorded_at': recordedAt!.toIso8601String(),
      };

  GeoResult copyWithMetadata({
    String? city,
    String? area,
    String? source,
  }) =>
      GeoResult(
        latitude: latitude,
        longitude: longitude,
        city: city ?? this.city,
        area: area ?? this.area,
        accuracyM: accuracyM,
        speedMps: speedMps,
        heading: heading,
        source: source ?? this.source,
        recordedAt: recordedAt,
      );
}

/// Cause d'échec d'une localisation (J179 — absence GPS / autorisations).
enum LocationFailure {
  /// Le GPS de l'appareil est désactivé.
  serviceDisabled,

  /// L'utilisateur a refusé l'accès à la localisation.
  permissionDenied,

  /// Aucune position exploitable obtenue (timing out, zone sans signal…).
  unavailable,
}

/// Issue d'une demande de position : succès (`geo`) ou `failure` détaillé.
class LocateResult {
  const LocateResult.success(this.geo)
      : assert(geo != null),
        failure = null;

  const LocateResult.failure(this.failure)
      : assert(failure != null),
        geo = null;

  const LocateResult._({this.geo, this.failure});

  static const none = LocateResult._(geo: null, failure: null);

  final GeoResult? geo;
  final LocationFailure? failure;

  bool get isSuccess => geo != null;
}

/// Localisation avec consentement et géocodage inverse (J174, J179).
///
/// - Demande l'autorisation système si nécessaire.
/// - Distingue les échecs : GPS désactivé, autorisation refusée,
///   position indisponible.
class LocationService {
  /// Vérifie l'état du GPS et de l'autorisation avant toute demande.
  static Future<LocationFailure?> accessIssue() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationFailure.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return LocationFailure.permissionDenied;
    }

    return null;
  }

  /// Récupère la position courante de l'appareil.
  ///
  /// Retourne une [LocateResult] : succès ou échec détaillé
  /// (GPS désactivé, autorisation refusée, position indisponible).
  static Future<LocateResult> locate() async {
    final issue = await accessIssue();
    if (issue != null) {
      return LocateResult.failure(issue);
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) {
          return const LocateResult.failure(LocationFailure.unavailable);
        }
        position = last;
      }
    }

    String? city;
    String? area;

    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        locale: const Locale('fr', 'FR'),
      );
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        city = _firstNonEmpty([pm.locality, pm.administrativeArea]);
        area = _firstNonEmpty([pm.subLocality, pm.thoroughfare]);
      }
    } catch (_) {
      // Géocodage optionnel : on garde les coordonnées brutes
    }

    return LocateResult.success(_fromPosition(position, city: city, area: area));
  }

  /// Position brute, sans géocodage inverse (battement de présence livreur).
  ///
  /// Contrairement à [locate], aucun appel réseau de géocodage n'est fait :
  /// cette méthode peut être appelée périodiquement sans surcoût.
  static Future<LocateResult> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.medium,
    Duration timeLimit = const Duration(seconds: 12),
  }) async {
    final issue = await accessIssue();
    if (issue != null) {
      return LocateResult.failure(issue);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );

      return LocateResult.success(_fromPosition(position));
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) {
        return const LocateResult.failure(LocationFailure.unavailable);
      }

      return LocateResult.success(_fromPosition(last));
    }
  }

  /// Suit la position en continu (carte de mission, guidage GPS).
  ///
  /// Émet un [GeoResult] à chaque déplacement significatif ([distanceFilter]
  /// mètres). Contrairement à [locate], aucun géocodage inverse n'est fait :
  /// le flux est rafraîchi plusieurs fois par seconde côté UI.
  static Stream<GeoResult> watch({int distanceFilter = 5}) {
    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map((position) => _fromPosition(position));
  }

  /// Convertit une position système en résultat enrichi (précision, cap, date).
  static GeoResult _fromPosition(
    Position position, {
    String? city,
    String? area,
  }) {
    final speed = position.speed;
    final heading = position.heading;
    return GeoResult(
      latitude: position.latitude,
      longitude: position.longitude,
      city: city,
      area: area,
      accuracyM: position.accuracy.isFinite ? position.accuracy : null,
      speedMps: speed.isFinite ? speed : null,
      heading: heading.isFinite ? heading : null,
      source: 'gps',
      recordedAt: position.timestamp,
    );
  }

  /// Quartier / zone approximative via géocodage inverse (optionnel).
  static String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      final trimmed = v?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
}