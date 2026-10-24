import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/geo.dart';
import '../models/geo_point.dart';
import 'app_network_image.dart';

/// Carte de localisation réutilisable (J162 / J177).
///
/// Affiche la position courante (`origin`, le livreur ou l'utilisateur), la
/// destination active (`target`) et un point secondaire (`secondary`, ex. point
/// de collecte). Le tracé peut suivre les routes réelles via [route] (polyligne
/// renvoyée par le backend) ; à défaut, un segment direct `origin` → `target`
/// est dessiné. La portion déjà parcourue ([travelled]) s'affiche en gris.
class AppMap extends StatefulWidget {
  const AppMap({
    super.key,
    this.origin,
    this.target,
    this.secondary,
    this.originLabel = 'Vous',
    this.targetLabel,
    this.secondaryLabel,
    this.originImageUrl,
    this.targetImageUrl,
    this.secondaryImageUrl,
    this.height = 260,
    this.followOrigin = true,
    this.initialZoom = 14,
    this.showRoute = true,
    this.route,
    this.routeColor,
    this.highlightRoute,
    this.extraRoute,
    this.travelled,
    this.originIsDriver = true,
    this.originHeading,
    this.openInMaps = false,
    this.expandable = true,
    this.fullscreen = false,
    this.targetIcon = Icons.place,
    this.targetColor,
    this.secondaryIcon = Icons.storefront_outlined,
    this.secondaryColor,
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

  /// Photos affichées dans les marqueurs (avatar ou logo). `null` = icône.
  final String? originImageUrl;
  final String? targetImageUrl;
  final String? secondaryImageUrl;

  final double height;

  /// Recentre automatiquement la carte quand [origin] bouge.
  final bool followOrigin;

  final double initialZoom;

  /// Trace un segment direct [origin] -> [target] si [route] est absent.
  final bool showRoute;

  /// Itinéraire routier réel (polyligne) à tracer à la place du segment direct.
  final List<LatLng>? route;

  /// Couleur du tracé actif ([route]). Par défaut : orange.
  final Color? routeColor;

  /// Segment de la prochaine manœuvre, mis en évidence par-dessus [route].
  final List<LatLng>? highlightRoute;

  /// Second itinéraire (ex. tronçon complémentaire) tracé en bleu atténué.
  final List<LatLng>? extraRoute;

  /// Portion déjà parcourue de l'itinéraire (tracée en gris atténué).
  final List<LatLng>? travelled;

  /// `true` : marqueur moto pour [origin] (livreur) ; `false` : point bleu « moi ».
  final bool originIsDriver;

  /// Cap du véhicule en degrés (0 = Nord) pour orienter le marqueur moto.
  final double? originHeading;

  /// Affiche un bouton « Ouvrir dans Google Maps » (navigation guidée).
  final bool openInMaps;

  /// Affiche un bouton pour agrandir la carte plein écran (dans l'application).
  final bool expandable;

  /// Rendu plein écran : la carte remplit l'écran et affiche un bouton fermer.
  final bool fullscreen;

  /// Icône et couleur du marqueur cible (destination principale).
  final IconData targetIcon;
  final Color? targetColor;

  /// Icône et couleur du marqueur secondaire (boutique, adresse…).
  final IconData secondaryIcon;
  final Color? secondaryColor;

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  final MapController _controller = MapController();
  GeoPoint? _lastCenteredOrigin;
  bool _movedByUser = false;

  /// Bump à chaque mise à jour du widget parent pour rafraîchir la carte
  /// plein écran (qui vit dans une autre route et ne se reconstruit pas seule).
  final ValueNotifier<int> _rev = ValueNotifier<int>(0);

  @override
  void didUpdateWidget(AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Différé : notifier un autre arbre (la route plein écran) pendant la phase
    // de build déclencherait un setState-during-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rev.value++;
      }
    });
    final origin = widget.origin;
    if (origin == null || !widget.followOrigin || _movedByUser) {
      return;
    }
    if (_lastCenteredOrigin != origin) {
      _lastCenteredOrigin = origin;
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerOn(origin.latLng));
    }
  }

  @override
  void dispose() {
    _rev.dispose();
    _controller.dispose();
    super.dispose();
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

  /// Points à tracer : l'itinéraire routier fourni, sinon le segment direct
  /// `origin` → `target` (repli « ligne droite »).
  List<LatLng> get _routePoints {
    final route = widget.route;
    if (route != null && route.length >= 2) {
      return route;
    }
    if (widget.showRoute && widget.origin != null && widget.target != null) {
      return [widget.origin!.latLng, widget.target!.latLng];
    }
    return const [];
  }

  /// Applique les mêmes données à une carte plein écran (dans l'application).
  Widget _fullscreenMap() {
    return AppMap(
      origin: widget.origin,
      target: widget.target,
      secondary: widget.secondary,
      originLabel: widget.originLabel,
      targetLabel: widget.targetLabel,
      secondaryLabel: widget.secondaryLabel,
      originImageUrl: widget.originImageUrl,
      targetImageUrl: widget.targetImageUrl,
      secondaryImageUrl: widget.secondaryImageUrl,
      followOrigin: widget.followOrigin,
      initialZoom: widget.initialZoom,
      showRoute: widget.showRoute,
      route: widget.route,
      routeColor: widget.routeColor,
      highlightRoute: widget.highlightRoute,
      extraRoute: widget.extraRoute,
      travelled: widget.travelled,
      originIsDriver: widget.originIsDriver,
      originHeading: widget.originHeading,
      openInMaps: widget.openInMaps,
      fullscreen: true,
      expandable: false,
      targetIcon: widget.targetIcon,
      targetColor: widget.targetColor,
      secondaryIcon: widget.secondaryIcon,
      secondaryColor: widget.secondaryColor,
    );
  }

  /// Ouvre la carte en plein écran, sans quitter l'application.
  ///
  /// La carte plein écran est reconstruite à chaque mise à jour du suivi
  /// (position, tracé, cap) via [_rev], pour rester réellement en direct.
  void _openFullscreen() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenMapPage(
          rev: _rev,
          builder: _fullscreenMap,
        ),
      ),
    );
  }

  Future<void> _openInGoogleMaps() async {
    final origin = widget.origin;
    final target = widget.target;
    if (origin == null || target == null) {
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${origin.latitude},${origin.longitude}'
      '&destination=${target.latitude},${target.longitude}'
      '&travelmode=two-wheeler',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Aucune application de navigation : on ignore silencieusement.
    }
  }

  /// Construit un marqueur avec, si fourni, un libellé lisible sous l'icône.
  Marker _marker({
    required GeoPoint point,
    required Widget child,
    String? label,
    double size = 40,
  }) {
    final hasLabel = label != null && label.trim().isNotEmpty;

    return Marker(
      point: point.latLng,
      width: hasLabel ? 140 : size,
      height: hasLabel ? size + 26 : size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: size, height: size, child: child),
          if (hasLabel) _MarkerLabel(label.trim()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      if (widget.origin != null) widget.origin!.latLng,
      if (widget.target != null) widget.target!.latLng,
      if (widget.secondary != null) widget.secondary!.latLng,
    ];
    final originMarkerSize = widget.originImageUrl == null
        ? (widget.originIsDriver ? 44.0 : 28.0)
        : (widget.originIsDriver ? 44.0 : 36.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.fullscreen ? 0 : AppDimens.radiusMd),
      child: SizedBox(
        height: widget.fullscreen ? double.infinity : widget.height,
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
                        urlTemplate: AppConfig.mapTileUrl,
                        userAgentPackageName: 'com.beninfood.beninfood',
                        maxNativeZoom: 19,
                        tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 150)),
                      ),
                      if (_routePoints.length >= 2 ||
                          (widget.extraRoute?.length ?? 0) >= 2 ||
                          (widget.highlightRoute?.length ?? 0) >= 2)
                        PolylineLayer(
                          polylines: [
                            // Tronçon complémentaire (ex. boutique → client) : bleu atténué.
                            if (widget.extraRoute != null && widget.extraRoute!.length >= 2)
                              Polyline(
                                points: widget.extraRoute!,
                                strokeWidth: 4,
                                color: AppColors.blue.withValues(alpha: 0.45),
                                borderStrokeWidth: 1,
                                borderColor: Colors.white,
                              ),
                            if (widget.travelled != null && widget.travelled!.length >= 2)
                              Polyline(
                                points: widget.travelled!,
                                strokeWidth: 6,
                                color: AppColors.textSecondary.withValues(alpha: 0.55),
                                borderStrokeWidth: 1,
                                borderColor: Colors.white,
                              ),
                            if (_routePoints.length >= 2)
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 5,
                                color: (widget.routeColor ?? AppColors.orange).withValues(alpha: 0.9),
                                borderStrokeWidth: 1,
                                borderColor: Colors.white,
                              ),
                            // Prochain segment de manœuvre, mis en évidence.
                            if (widget.highlightRoute != null && widget.highlightRoute!.length >= 2)
                              Polyline(
                                points: widget.highlightRoute!,
                                strokeWidth: 7,
                                color: AppColors.blue,
                                borderStrokeWidth: 1.5,
                                borderColor: Colors.white,
                              ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (widget.secondary != null)
                            _marker(
                              point: widget.secondary!,
                              size: 36,
                              label: widget.secondaryLabel,
                              child: widget.secondaryImageUrl == null
                                  ? _DotMarker(
                                      color:
                                          widget.secondaryColor ??
                                          AppColors.gold,
                                      icon: widget.secondaryIcon,
                                    )
                                  : _PhotoMarker(
                                      imageUrl: widget.secondaryImageUrl!,
                                      size: 36,
                                      fallback: _DotMarker(
                                        color:
                                            widget.secondaryColor ??
                                            AppColors.gold,
                                        icon: widget.secondaryIcon,
                                      ),
                                      badgeIcon: widget.secondaryIcon,
                                      badgeColor:
                                          widget.secondaryColor ??
                                          AppColors.gold,
                                      rounded: _isShopIcon(
                                        widget.secondaryIcon,
                                      ),
                                    ),
                            ),
                          if (widget.target != null)
                            _marker(
                              point: widget.target!,
                              size: 42,
                              label: widget.targetLabel,
                              child: widget.targetImageUrl == null
                                  ? _PinMarker(
                                      color:
                                          widget.targetColor ??
                                          AppColors.orange,
                                      icon: widget.targetIcon,
                                    )
                                  : _PhotoMarker(
                                      imageUrl: widget.targetImageUrl!,
                                      size: 42,
                                      fallback: _PinMarker(
                                        color:
                                            widget.targetColor ??
                                            AppColors.orange,
                                        icon: widget.targetIcon,
                                      ),
                                      badgeIcon: widget.targetIcon,
                                      badgeColor:
                                          widget.targetColor ??
                                          AppColors.orange,
                                      rounded: _isShopIcon(widget.targetIcon),
                                    ),
                            ),
                          if (widget.origin != null)
                            _marker(
                              point: widget.origin!,
                              size: originMarkerSize,
                              label: widget.originLabel,
                              child: widget.originImageUrl == null
                                  ? (widget.originIsDriver
                                        ? _MotoMarker(
                                            heading: widget.originHeading,
                                          )
                                        : const _DriverMarker())
                                  : _PhotoMarker(
                                      imageUrl: widget.originImageUrl!,
                                      size: originMarkerSize,
                                      fallback: widget.originIsDriver
                                          ? _MotoMarker(
                                              heading: widget.originHeading,
                                            )
                                          : const _DriverMarker(),
                                      badgeIcon: widget.originIsDriver
                                          ? (widget.originHeading != null
                                                ? Icons.navigation
                                                : Icons.two_wheeler)
                                          : Icons.person,
                                      badgeColor: widget.originIsDriver
                                          ? AppColors.orange
                                          : const Color(0xFF1D6FE0),
                                      heading: widget.originHeading,
                                    ),
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
                  if (widget.openInMaps && widget.origin != null && widget.target != null)
                    Positioned(
                      right: 8,
                      bottom: 52,
                      child: _MapButton(
                        icon: Icons.directions_outlined,
                        tooltip: 'Ouvrir dans Google Maps',
                        onPressed: _openInGoogleMaps,
                      ),
                    ),
                  if (widget.expandable && !widget.fullscreen)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _MapButton(
                        icon: Icons.fullscreen,
                        tooltip: 'Agrandir la carte',
                        onPressed: _openFullscreen,
                      ),
                    ),
                  if (widget.fullscreen)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _MapButton(
                        icon: Icons.close,
                        tooltip: 'Fermer',
                        onPressed: () => Navigator.of(context).maybePop(),
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

/// Petit libellé blanc affiché sous un marqueur (livreur, boutique, client…).
class _MarkerLabel extends StatelessWidget {
  const _MarkerLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
    );
  }
}

bool _isShopIcon(IconData icon) =>
    icon == Icons.storefront_outlined || icon == Icons.storefront;

/// Marqueur photo : avatar client/livreur ou logo boutique, avec pastille
/// de rôle. Repli automatique sur le marqueur icône si l'image échoue.
class _PhotoMarker extends StatelessWidget {
  const _PhotoMarker({
    required this.imageUrl,
    required this.size,
    required this.fallback,
    required this.badgeIcon,
    required this.badgeColor,
    this.rounded = false,
    this.heading,
  });

  final String imageUrl;
  final double size;
  final Widget fallback;
  final IconData badgeIcon;
  final Color badgeColor;

  /// Logo boutique : cadre arrondi ; sinon avatar circulaire.
  final bool rounded;

  /// Cap du véhicule pour orienter la pastille du livreur.
  final double? heading;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);
    final badgeSize = size * 0.45;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: rounded ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: rounded ? radius : null,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: AppNetworkImage(
              url: imageUrl,
              fit: BoxFit.cover,
              fallback: fallback,
              borderRadius: rounded ? radius : null,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Transform.rotate(
                  angle: (heading ?? 0) * 3.1415926535 / 180,
                  child: Icon(
                    badgeIcon,
                    size: badgeSize * 0.55,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marqueur du livreur en déplacement (icône moto).
class _MotoMarker extends StatelessWidget {
  const _MotoMarker({this.heading});

  /// Cap du véhicule en degrés (0 = Nord). `null` = pas de rotation.
  final double? heading;

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.orange,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.45), blurRadius: 8)],
      ),
      // Flèche orientée quand un cap est connu, moto sinon.
      child: Icon(heading != null ? Icons.navigation : Icons.two_wheeler, size: 16, color: Colors.white),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: heading != null
            ? Transform.rotate(
                angle: heading! * 3.1415926535 / 180,
                child: icon,
              )
            : icon,
      ),
    );
  }
}

/// Marqueur de la position de l'utilisateur (point bleu avec halo).
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
          AppConfig.mapAttribution,
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
/// Écran plein écran hébergeant la carte, sans quitter l'application.
class _FullscreenMapPage extends StatelessWidget {
  const _FullscreenMapPage({required this.rev, required this.builder});

  /// Notifié à chaque mise à jour du suivi pour rafraîchir la carte en direct.
  final ValueListenable<int> rev;

  /// Construit la carte plein écran à partir des données courantes.
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: rev,
          builder: (_, _, _) => builder(),
        ),
      ),
    );
  }
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
    this.maneuverInstruction,
    this.maneuverIcon,
    this.maneuverDistanceMeters,
    this.offRoute = false,
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

  /// Instruction de la prochaine manœuvre (guidage tour-par-tour). Quand elle
  /// est fournie, le bandeau affiche la manœuvre au lieu du cap à vol d'oiseau.
  final String? maneuverInstruction;

  /// Icône directionnelle de la manœuvre.
  final IconData? maneuverIcon;

  /// Distance avant la prochaine manœuvre (mètres).
  final int? maneuverDistanceMeters;

  /// Le livreur s'est écarté de l'itinéraire : recalcul en cours.
  final bool offRoute;

  bool get _hasManeuver => maneuverInstruction != null && maneuverInstruction!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_hasManeuver) {
      return _buildManeuver(context);
    }

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

  /// Bandeau « prochaine manœuvre » : flèche directionnelle + instruction +
  /// distance avant la manœuvre, et ETA restante.
  Widget _buildManeuver(BuildContext context) {
    final color = offRoute ? AppColors.gold : accent;

    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Icon(
                maneuverIcon ?? Icons.straight,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (maneuverDistanceMeters != null)
                  Text(
                    formatGeoDistance(maneuverDistanceMeters! / 1000),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                Text(
                  offRoute ? 'Recalcul de l\'itinéraire…' : maneuverInstruction!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    fontSize: 15,
                  ),
                ),
                if (address != null && address!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          if (!offRoute && etaMinutes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color,
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
