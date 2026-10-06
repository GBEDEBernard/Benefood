import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/utils/formatters.dart';

/// Utilitaires géographiques : distance, cap, estimation de temps de trajet.
///
/// La distance est une distance à vol d'oiseau (haversine) : elle sert au
/// guidage « tout droit » affiché au livreur, pas à un calcul d'itinéraire
/// routier (le backend n'expose pas de service de routing).
const double _earthRadiusKm = 6371.0088;

/// Distance en kilomètres entre deux coordonnées.
double distanceKm(LatLng from, LatLng to) {
  final dLat = _rad(to.latitude - from.latitude);
  final dLng = _rad(to.longitude - from.longitude);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(from.latitude)) * math.cos(_rad(to.latitude)) * math.pow(math.sin(dLng / 2), 2);
  return _earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Cap de [from] vers [to], en degrés (0 = Nord, 90 = Est).
double bearingDegrees(LatLng from, LatLng to) {
  final dLng = _rad(to.longitude - from.longitude);
  final y = math.sin(dLng) * math.cos(_rad(to.latitude));
  final x = math.cos(_rad(from.latitude)) * math.sin(_rad(to.latitude)) -
      math.sin(_rad(from.latitude)) * math.cos(_rad(to.latitude)) * math.cos(dLng);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Rose des vents en 8 points (« Nord », « Nord-Est », …).
String compassLabel(double bearing) {
  const points = ['Nord', 'Nord-Est', 'Est', 'Sud-Est', 'Sud', 'Sud-Ouest', 'Ouest', 'Nord-Ouest'];
  final index = ((bearing + 22.5) % 360 / 45).floor() % 8;
  return points[index];
}

/// Durée estimée en minutes pour [km] kilomètres (vitesse moyenne moto en ville).
int? estimateMinutes(double km, {double averageSpeedKmh = 22}) {
  if (!km.isFinite || km <= 0) {
    return null;
  }
  return (km / averageSpeedKmh * 60).round().clamp(1, 999);
}

/// Durée+lisible : « 12 min », « 1 h 05 », « < 1 min ».
String formatEta(int? minutes) {
  if (minutes == null) {
    return '—';
  }
  if (minutes < 60) {
    return '$minutes min';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return '${hours}h${rest.toString().padLeft(2, '0')}';
}

/// Distance lisible (« 350 m », « 1,2 km »).
String formatGeoDistance(double? km) => formatDistance(km);

double _rad(double degrees) => degrees * math.pi / 180;

double _deg(double radians) => radians * 180 / math.pi;