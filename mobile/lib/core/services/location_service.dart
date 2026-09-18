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
  });

  final double latitude;
  final double longitude;
  final String? city;
  final String? area;
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

    return LocateResult.success(
      GeoResult(
        latitude: position.latitude,
        longitude: position.longitude,
        city: city,
        area: area,
      ),
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