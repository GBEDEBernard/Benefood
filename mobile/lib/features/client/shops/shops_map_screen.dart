import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/models/vendor.dart';
import '../../../shared/widgets/app_network_image.dart';

/// Carte des boutiques en ligne : marqueurs GPS, filtre de rayon et fiche
/// rapide de la boutique sélectionnée.
class ShopsMapScreen extends StatefulWidget {
  const ShopsMapScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<ShopsMapScreen> createState() => _ShopsMapScreenState();
}

class _ShopsMapScreenState extends State<ShopsMapScreen> {
  static const LatLng _cotonou = LatLng(6.3702932, 2.3912362);

  final MapController _mapController = MapController();

  LatLng? _position;
  List<Vendor> _vendors = const [];
  Vendor? _selected;
  double? _radiusKm;
  bool _loading = true;
  String? _error;

  static const List<double?> _radiusOptions = [null, 2, 5, 10];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng get _center =>
      _position ??
      _vendors
          .where((v) => v.latitude != null && v.longitude != null)
          .map((v) => LatLng(v.latitude!, v.longitude!))
          .firstOrNull ??
      _cotonou;

  Future<void> _boot() async {
    final located = await LocationService.locate();
    if (located.isSuccess) {
      final geo = located.geo!;
      _position = LatLng(geo.latitude, geo.longitude);
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final vendors = await widget.marketplace.nearbyShops(
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        radiusKm: _radiusKm,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _vendors = vendors;
        _loading = false;
        if (_selected != null &&
            !vendors.any((vendor) => vendor.id == _selected!.id)) {
          _selected = null;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Impossible de charger les boutiques.';
        _loading = false;
      });
    }
  }

  void _selectRadius(double? radius) {
    if (_radiusKm == radius) {
      return;
    }
    setState(() {
      _radiusKm = radius;
      _selected = null;
    });
    _load();
  }

  void _recenter() {
    try {
      _mapController.move(_center, 14);
    } catch (_) {
      // Carte pas encore montée.
    }
  }

  void _openVendor(Vendor vendor) {
    setState(() => _selected = vendor);
    if (vendor.latitude != null && vendor.longitude != null) {
      try {
        _mapController.move(
          LatLng(vendor.latitude!, vendor.longitude!),
          15.5,
        );
      } catch (_) {
        // Carte pas encore montée.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        title: const Text(
          'Boutiques à proximité',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _RadiusBar(
            selected: _radiusKm,
            options: _radiusOptions,
            onSelected: _selectRadius,
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.orange),
                  )
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _center,
                              initialZoom: 13,
                              minZoom: 3,
                              maxZoom: 18,
                              backgroundColor: AppColors.surfaceVariant,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: AppConfig.mapTileUrl,
                                userAgentPackageName: 'com.beninfood.beninfood',
                                maxNativeZoom: 19,
                              ),
                              MarkerLayer(
                                markers: [
                                  if (_position != null)
                                    Marker(
                                      point: _position!,
                                      width: 24,
                                      height: 24,
                                      child: const _UserDot(),
                                    ),
                                  for (final vendor in _vendors)
                                    if (vendor.latitude != null &&
                                        vendor.longitude != null)
                                      Marker(
                                        point: LatLng(
                                          vendor.latitude!,
                                          vendor.longitude!,
                                        ),
                                        width: 46,
                                        height: 46,
                                        child: _ShopPin(
                                          vendor: vendor,
                                          selected: _selected?.id == vendor.id,
                                          onTap: () => _openVendor(vendor),
                                        ),
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
                            right: 12,
                            bottom: _selected == null ? 16 : 176,
                            child: FloatingActionButton.small(
                              heroTag: 'shops-map-recenter',
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.orange,
                              onPressed: _recenter,
                              child: const Icon(Icons.my_location),
                            ),
                          ),
                          if (_selected != null)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: _VendorSheet(
                                vendor: _selected!,
                                onClose: () =>
                                    setState(() => _selected = null),
                                onOpen: () => context.push(
                                  '/client/shop/${_selected!.id}',
                                ),
                              ),
                            ),
                          if (_vendors.isEmpty)
                            const Positioned(
                              left: 16,
                              right: 16,
                              top: 16,
                              child: _EmptyBanner(),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _RadiusBar extends StatelessWidget {
  const _RadiusBar({
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final double? selected;
  final List<double?> options;
  final ValueChanged<double?> onSelected;

  String _label(double? radius) =>
      radius == null ? 'Tout' : '${radius.toStringAsFixed(0)} km';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        4,
        AppDimens.pagePadding,
        10,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final option in options) ...[
              ChoiceChip(
                label: Text(_label(option)),
                selected: selected == option,
                onSelected: (_) => onSelected(option),
                selectedColor: AppColors.orangeLight,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected == option
                      ? AppColors.orangeDark
                      : AppColors.textSecondary,
                ),
                side: BorderSide(
                  color: selected == option
                      ? AppColors.orange
                      : AppColors.border,
                ),
                showCheckmark: false,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShopPin extends StatelessWidget {
  const _ShopPin({
    required this.vendor,
    required this.selected,
    required this.onTap,
  });

  final Vendor vendor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: selected ? 44 : 38,
            height: selected ? 44 : 38,
            decoration: BoxDecoration(
              color: selected ? AppColors.orange : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : AppColors.orange,
                width: 2.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: vendor.logoUrl == null
                ? Icon(
                    Icons.storefront,
                    size: selected ? 22 : 19,
                    color: selected ? Colors.white : AppColors.orange,
                  )
                : AppNetworkImage(
                    url: vendor.logoUrl!,
                    fit: BoxFit.cover,
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: AppColors.blue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.white, blurRadius: 2, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}

class _VendorSheet extends StatelessWidget {
  const _VendorSheet({
    required this.vendor,
    required this.onClose,
    required this.onOpen,
  });

  final Vendor vendor;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final distance = vendor.distanceLabel;
    final open = vendor.isOpenResolved;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 54,
                height: 54,
                child: vendor.coverUrl != null || vendor.logoUrl != null
                    ? AppNetworkImage(
                        url: vendor.coverUrl ?? vendor.logoUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: AppColors.orangeLight,
                        child: const Icon(
                          Icons.storefront,
                          color: AppColors.orange,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vendor.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (vendor.type != null) vendor.type!.label,
                      if (distance != null) distance,
                      open ? 'Ouvert' : 'Fermé',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: open ? AppColors.green : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 19),
              color: AppColors.textFaint,
            ),
            FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Voir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBanner extends StatelessWidget {
  const _EmptyBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.location_off_outlined, color: AppColors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Aucune boutique géolocalisée dans ce rayon.',
                style: TextStyle(fontSize: 12.5, color: AppColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.map_outlined,
              size: 48,
              color: AppColors.textFaint,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
