import '../../shared/models/geo_point.dart';
import '../../shared/models/route_plan.dart';
import '../data/marketplace_api.dart';

/// Cache mémoire des itinéraires routiers calculés par le serveur.
///
/// Les coordonnées sont arrondies (~110 m) pour réutiliser un tracé tant que le
/// livreur ne s'est pas déplacé de façon significative : on évite ainsi un appel
/// réseau à chaque tick GPS. Les appels concurrents pour un même trajet sont
/// dédupliqués.
class RoutePlanner {
  RoutePlanner(this._marketplace);

  final MarketplaceApi _marketplace;
  final Map<String, RoutePlan> _cache = {};
  final Set<String> _inFlight = {};

  static const int _maxEntries = 60;

  /// Retourne l'itinéraire passant par [points] (2 minimum), ou `null` si le
  /// calcul échoue (réseau coupé) — l'appelant retombe alors sur la ligne droite.
  Future<RoutePlan?> plan(List<GeoPoint> points, {String profile = 'moto'}) async {
    if (points.length < 2) {
      return null;
    }

    final key = _key(points, profile);
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }
    if (_inFlight.contains(key)) {
      return null;
    }

    _inFlight.add(key);
    try {
      final plan = await _marketplace.routePlan(points, profile: profile);
      _cache[key] = plan;
      if (_cache.length > _maxEntries) {
        _cache.remove(_cache.keys.first);
      }

      return plan;
    } catch (_) {
      return null;
    } finally {
      _inFlight.remove(key);
    }
  }

  String _key(List<GeoPoint> points, String profile) {
    final buffer = StringBuffer(profile);
    for (final point in points) {
      buffer.write('|${point.latitude.toStringAsFixed(3)},${point.longitude.toStringAsFixed(3)}');
    }

    return buffer.toString();
  }
}
