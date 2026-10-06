import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/geo.dart';
import '../models/geo_point.dart';

/// Carte de localisation réutilisable (J162 / J177).
///
/// Affiche la position courante (`origin`, le livreur), la destination active
/// (`target`) et un point secondaire (`secondary`, ex. point de collecte).
/// Le tracé `origin` → `target` matérialise le trajet à effectuer.
class AppMap extends StatefulWidget {
  const AppMap({
    super.key,
    this.origin,
    this.target,
    this.secondary,
    this.originLabel = 'Vous',
    this.targetLabel,
    this.secondaryLabel,
    this.height = 260,
    this.followOrigin = true,
    this.initialZoom = 14,
    this.showRoute = true,
  });

  /// Position de l'utilisateur (livreur) : `null` si inconnue.
  final GeoPoint? origin;

  /// Destination affichée en surbrillance (marqueur tomate).
  final GeoPoint? target;

  /// Point secondaire (marqueur carotte) : collecte, adresse finale, etc.
  final GeoPoint? secondary;

  final String originLabel;
  final String? targetLabel;
  final String? secondaryLabel;

  final double height;

  /// Recentre automatiquement la carte quand [origin] bouge.
  final bool followOrigin;

  final double initialZoom;

  /// Trace le segment [origin] -> [target].
  final bool showRoute;

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  final MapController _controller = MapController();
  GeoPoint? _lastCenteredOrigin;
  bool _movedByUser = false;

  @override
  void didUpdateWidget(AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final origin = widget.origin;
    if (origin == null || !widget.followOrigin || _movedByUser) {
      return;
    }
    if (_lastCenteredOrigin != origin) {
      _lastCenteredOrigin = origin;
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerOn(origin.latLng));
    }
  }

  void _centerOn(LatLng point) {
    if (!mounted) {
      return;
    }
    try {
      _controller.move(point, _controller.camera.zoom);
    } catch (_) {
      // La carte n'est pas encore montée : le prochain build la cadrera.
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      if (widget.origin != null) widget.origin!.latLng,
      if (widget.target != null) widget.target!.latLng,
      if (widget.secondary != null) widget.secondary!.latLng,
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: points.isEmpty
            ? const _MapPlaceholder()
            : Stack(
                children: [
                  FlutterMap(
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: points.first,
                      initialZoom: widget.initialZoom,
                      minZoom: 3,
                      maxZoom: 18,
                      backgroundColor: AppColors.surfaceVariant,
                      onPositionChanged: (camera, hasGesture) {
                        if (hasGesture && !_movedByUser) {
                          _movedByUser = true;
                        }
                      },
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                        fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.beninfood.beninfood',
                        tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 150)),
                      ),
                      if (widget.showRoute &&
                          widget.origin != null &&
                          widget.target != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [widget.origin!.latLng, widget.target!.latLng],
                              strokeWidth: 4,
                              color: AppColors.orange.withValues(alpha: 0.85),
                              borderStrokeWidth: 1,
                              borderColor: Colors.white,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (widget.secondary != null)
                            Marker(
                              point: widget.secondary!.latLng,
                              width: 34,
                              height: 34,
                              child: _DotMarker(
                                color: AppColors.gold,
                                icon: Icons.storefront_outlined,
                              ),
                            ),
                          if (widget.target != null)
                            Marker(
                              point: widget.target!.latLng,
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              child: _PinMarker(color: AppColors.orange, icon: Icons.place),
                            ),
                          if (widget.origin != null)
                            Marker(
                              point: widget.origin!.latLng,
                              width: 28,
                              height: 28,
                              child: const _DriverMarker(),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (widget.origin != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _MapButton(
                        icon: Icons.my_location,
                        tooltip: 'Recentrer sur ma position',
                        onPressed: () {
                          setState(() => _movedByUser = false);
                          _centerOn(widget.origin!.latLng);
                        },
                      ),
                    ),
                  const Positioned(
                    left: 4,
                    bottom: 4,
                    child: _Attribution(),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Marqueur du livreur (point bleu avec halo).
class _DriverMarker extends StatelessWidget {
  const _DriverMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D6FE0).withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF1D6FE0),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}

/// Marqueur cible (pointe de carte colorée).
class _PinMarker extends StatelessWidget {
  const _PinMarker({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)],
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}

/// Petit point coloré (point secondaire).
class _DotMarker extends StatelessWidget {
  const _DotMarker({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, size: 15, color: Colors.white),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 3,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          '© OpenStreetMap · CARTO',
          style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Affiché quand aucune coordonnée n'est disponible.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.location_off_outlined, color: AppColors.textSecondary),
            SizedBox(height: 6),
            Text(
              'Coordonnées indisponibles',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rappel local : `AppDimens` vit dans core/theme, on évite un import croisé
/// d'ordre constant en dupliquant la seule valeur utile ici.
class AppDimensRadius {
  const AppDimensRadius._();

  static const double md = 12;
}
/// Bandeau de guidage affiché au-dessus de la carte.
///
/// Affiche la direction à suivre (flèche orientée vers la destination), la
/// distance à vol d'oiseau, l'estimation de temps et l'adresse cible.
class MapGuidanceBar extends StatelessWidget {
  const MapGuidanceBar({
    super.key,
    required this.title,
    required this.distanceKm,
    required this.bearing,
    this.address,
    this.etaMinutes,
    this.accent = AppColors.orange,
    this.waitingForPosition = false,
  });

  final String title;

  /// Distance à la cible ; `null` si la cible ou la position est inconnue.
  final double? distanceKm;

  /// Cap vers la cible en degrés ; `null` si inconnu.
  final double? bearing;

  final String? address;
  final int? etaMinutes;
  final Color accent;

  /// La position du livreur n'est pas encore connue : on affiche « GPS… ».
  final bool waitingForPosition;

  @override
  Widget build(BuildContext context) {
    final hasGuidance = distanceKm != null && bearing != null;

    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          _CompassArrow(bearing: bearing, accent: accent, active: hasGuidance),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  waitingForPosition
                      ? 'Localisation en cours…'
                      : hasGuidance
                          ? '${formatGeoDistance(distanceKm)} · ${compassLabel(bearing!)}'
                          : 'Distance indisponible',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasGuidance ? accent : AppColors.textSecondary,
                  ),
                ),
                if (address != null && address!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      address!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          if (hasGuidance && etaMinutes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
              child: Text(
                formatEta(etaMinutes),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Flèche de cap (rotation appliquée au pictogramme « navigation »).
class _CompassArrow extends StatelessWidget {
  const _CompassArrow({required this.bearing, required this.accent, required this.active});

  final double? bearing;
  final Color accent;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : AppColors.textSecondary;
    return SizedBox(
      width: 44,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Transform.rotate(
            angle: (bearing ?? 0) * 3.1415926535 / 180,
            child: Icon(
              Icons.navigation,
              size: 24,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
