import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Sélecteur de point sur une carte : l'utilisateur déplace la carte puis
/// touche le lieu exact pour poser le repère orange.
///
/// Le widget ne fait aucune requête réseau de géocodage : l'adresse textuelle
/// reste saisie séparément. Il sert aux adresses client, au point de retrait
/// vendeur et aux étapes colis.
class MapPicker extends StatefulWidget {
  const MapPicker({
    super.key,
    required this.point,
    required this.onChanged,
    this.initialCenter,
    this.height = 220,
    this.onLocate,
    this.locating = false,
    this.instruction = 'Touchez la carte pour placer le repère exact',
  });

  /// Point sélectionné ; `null` tant que l'utilisateur n'a rien choisi.
  final LatLng? point;

  final ValueChanged<LatLng> onChanged;

  /// Centre initial quand aucun point n'est encore sélectionné.
  final LatLng? initialCenter;

  final double height;

  /// Action « utiliser ma position » (facultative).
  final VoidCallback? onLocate;

  final bool locating;

  final String instruction;

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  final MapController _controller = MapController();
  LatLng? _lastPoint;

  static const LatLng _cotonou = LatLng(6.3702932, 2.3912362);

  LatLng get _center => widget.point ?? widget.initialCenter ?? _cotonou;

  @override
  void didUpdateWidget(MapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final point = widget.point;
    if (point != null && point != _lastPoint) {
      _lastPoint = point;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        try {
          _controller.move(point, _controller.camera.zoom);
        } catch (_) {
          // Carte pas encore montée : le build suivant la cadrera.
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: widget.point == null ? 13 : 16,
                minZoom: 3,
                maxZoom: 18,
                backgroundColor: AppColors.surfaceVariant,
                onTap: (_, point) {
                  _lastPoint = point;
                  widget.onChanged(point);
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
                  tileDisplay: const TileDisplay.fadeIn(
                    duration: Duration(milliseconds: 150),
                  ),
                ),
                if (widget.point != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.point!,
                        width: 46,
                        height: 46,
                        child: const _PickerPin(),
                      ),
                    ],
                  ),
                const RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution(
                      AppConfig.mapAttribution,
                      prependCopyright: false,
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 8,
              top: 8,
              right: widget.onLocate == null ? 8 : 64,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    widget.point == null
                        ? widget.instruction
                        : 'Repère posé — touchez pour ajuster',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.onLocate != null)
              Positioned(
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: widget.locating ? null : widget.onLocate,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: widget.locating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.my_location,
                              size: 20,
                              color: AppColors.orange,
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PickerPin extends StatelessWidget {
  const _PickerPin();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.orange,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 19),
        ),
      ],
    );
  }
}
