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

  final TextEditingController _searchController = TextEditingController();

  LatLng? _position;
  List<Vendor> _vendors = const [];
  Vendor? _selected;
  double? _radiusKm;
  VendorType? _type;
  String? _area;
  String _query = '';
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
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Boutiques après recherche par nom/quartier et filtres type/quartier.
  List<Vendor> get _visible {
    final query = _query.trim().toLowerCase();
    return _vendors.where((vendor) {
      if (_type != null && vendor.type != _type) {
        return false;
      }
      if (_area != null &&
          vendor.area != _area &&
          vendor.city != _area) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = [
        vendor.businessName,
        vendor.area,
        vendor.city,
        vendor.address,
        vendor.description,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  /// Quartiers (ou villes à défaut) disponibles parmi les boutiques chargées.
  List<String> get _areas {
    final areas = _vendors
        .map((vendor) {
          final area = vendor.area?.trim();
          if (area != null && area.isNotEmpty) {
            return area;
          }
          final city = vendor.city?.trim();
          return city != null && city.isNotEmpty ? city : null;
        })
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return areas;
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
      // Toutes les boutiques ouvertes : celles sans position GPS restent
      // visibles dans la liste de résultats, seules les géolocalisées ont un
      // marqueur sur la carte.
      final vendors = await widget.marketplace.vendors(
        onlyOpen: true,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        radiusKm: _radiusKm,
        sort: _position != null ? 'distance' : null,
        perPage: 100,
      );
      vendors.sort((a, b) {
        final da = a.distanceKm;
        final db = b.distanceKm;
        if (da == null && db == null) {
          return a.businessName.compareTo(b.businessName);
        }
        if (da == null) {
          return 1;
        }
        if (db == null) {
          return -1;
        }
        return da.compareTo(db);
      });
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

  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      if (_selected != null && !_visible.any((v) => v.id == _selected!.id)) {
        _selected = null;
      }
    });
  }

  void _selectType(VendorType? type) {
    setState(() {
      _type = type;
      _selected = null;
    });
  }

  Future<void> _pickArea() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Filtrer par quartier',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              title: const Text('Tous les quartiers'),
              trailing: _area == null
                  ? const Icon(Icons.check, color: AppColors.orange)
                  : null,
              onTap: () => Navigator.of(context).pop(''),
            ),
            for (final area in _areas)
              ListTile(
                title: Text(area),
                trailing: _area == area
                    ? const Icon(Icons.check, color: AppColors.orange)
                    : null,
                onTap: () => Navigator.of(context).pop(area),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) {
      return;
    }
    setState(() {
      _area = choice.isEmpty ? null : choice;
      _selected = null;
    });
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              8,
              AppDimens.pagePadding,
              0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Restaurant, maquis, quartier...',
                prefixIcon: const Icon(Icons.search, size: 21),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 19),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          _RadiusBar(
            selected: _radiusKm,
            options: _radiusOptions,
            enabled: _position != null,
            onSelected: _selectRadius,
          ),
          _TypeAreaBar(
            selectedType: _type,
            area: _area,
            onType: _selectType,
            onArea: _pickArea,
            onClearArea: () => setState(() {
              _area = null;
              _selected = null;
            }),
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
                                  for (final vendor in _visible)
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
                            bottom: _selected == null ? 132 : 176,
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
                            )
                          else if (_visible.isNotEmpty)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: _ResultsStrip(
                                vendors: _visible,
                                onTap: _openVendor,
                              ),
                            ),
                          if (_visible.isEmpty)
                            Positioned(
                              left: 16,
                              right: 16,
                              top: 16,
                              child: _EmptyBanner(
                                message: _vendors.isEmpty
                                    ? 'Aucune boutique géolocalisée dans ce rayon.'
                                    : 'Aucune boutique ne correspond à votre recherche.',
                              ),
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
    required this.enabled,
    required this.onSelected,
  });

  final double? selected;
  final List<double?> options;
  final bool enabled;
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
                onSelected: enabled ? (_) => onSelected(option) : null,
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

class _TypeAreaBar extends StatelessWidget {
  const _TypeAreaBar({
    required this.selectedType,
    required this.area,
    required this.onType,
    required this.onArea,
    required this.onClearArea,
  });

  final VendorType? selectedType;
  final String? area;
  final ValueChanged<VendorType?> onType;
  final VoidCallback onArea;
  final VoidCallback onClearArea;

  @override
  Widget build(BuildContext context) {
    final types = <VendorType?>[null, ...VendorType.values];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
        child: Row(
          children: [
            for (final type in types) ...[
              ChoiceChip(
                label: Text(type?.label ?? 'Tout'),
                selected: selectedType == type,
                onSelected: (_) => onType(type),
                selectedColor: AppColors.orangeLight,
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selectedType == type
                      ? AppColors.orangeDark
                      : AppColors.textSecondary,
                ),
                side: BorderSide(
                  color: selectedType == type
                      ? AppColors.orange
                      : AppColors.border,
                ),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
            ],
            const SizedBox(width: 4),
            InputChip(
              avatar: const Icon(
                Icons.place_outlined,
                size: 17,
                color: AppColors.orange,
              ),
              label: Text(
                area ?? 'Quartier',
                style: const TextStyle(fontSize: 12.5),
              ),
              onPressed: onArea,
              onDeleted: area == null ? null : onClearArea,
              deleteIcon: const Icon(Icons.close, size: 16),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste horizontale des boutiques correspondant à la recherche : elle
/// affiche aussi celles qui n'ont pas encore publié leur position GPS.
class _ResultsStrip extends StatelessWidget {
  const _ResultsStrip({required this.vendors, required this.onTap});

  final List<Vendor> vendors;
  final ValueChanged<Vendor> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Text(
              vendors.length == 1
                  ? '1 boutique ouverte'
                  : '${vendors.length} boutiques ouvertes',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              itemCount: vendors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final vendor = vendors[index];
                return _ResultCard(
                  vendor: vendor,
                  onTap: () => onTap(vendor),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.vendor, required this.onTap});

  final Vendor vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final located = vendor.latitude != null && vendor.longitude != null;
    final subtitle = [
      if (vendor.type != null) vendor.type!.label,
      if (vendor.area != null && vendor.area!.isNotEmpty)
        vendor.area!
      else if (vendor.city != null && vendor.city!.isNotEmpty)
        vendor.city!,
      vendor.distanceLabel ?? (located ? null : 'Position non partagée'),
    ].whereType<String>().join(' · ');

    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 168,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: vendor.logoUrl != null
                        ? AppNetworkImage(url: vendor.logoUrl!, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.orangeLight,
                            child: const Icon(
                              Icons.storefront,
                              size: 20,
                              color: AppColors.orange,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        vendor.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
  const _EmptyBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined, color: AppColors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12.5, color: AppColors.text),
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
