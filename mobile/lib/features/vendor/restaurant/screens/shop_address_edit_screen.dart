import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/geo_reference.dart';
import '../../../../shared/models/neighborhood.dart';
import '../../../../shared/models/vendor.dart';
import '../../../../shared/widgets/city_area_picker.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/map_picker.dart';
import '../../onboarding/widgets/custom_text_field.dart';
import '../restaurant_palette.dart';
import 'shop_edit_shell.dart';
import '../../../../core/i18n/app_localizations.dart';

/// Gestion des adresses de la boutique : adresse publique, point de retrait
/// utilisé par les livreurs et informations complémentaires.
class ShopAddressEditScreen extends StatefulWidget {
  const ShopAddressEditScreen({super.key, required this.vendor, this.marketplace});

  final Vendor vendor;
  final MarketplaceApi? marketplace;

  @override
  State<ShopAddressEditScreen> createState() => _ShopAddressEditScreenState();
}

class _ShopAddressEditScreenState extends State<ShopAddressEditScreen> {
  late final TextEditingController _city;
  late final TextEditingController _area;
  late final TextEditingController _address;
  late final TextEditingController _pickupLandmark;
  late final TextEditingController _pickupAddress;
  late final TextEditingController _deliveryInstructions;
  bool _saving = false;
  bool _locatingShop = false;
  bool _locatingPickup = false;
  double? _latitude;
  double? _longitude;
  double? _pickupLatitude;
  double? _pickupLongitude;
  GeoReferenceSelection? _geo;
  GeoReferenceSelection? _pickupGeo;

  /// Quartiers du référentiel, chargés pour centrer les cartes sur le
  /// quartier choisi et poser un repère de départ.
  List<LocationCity> _cities = const [];
  LatLng? _shopCenter;
  LatLng? _pickupCenter;

  /// Vrai quand le vendeur a lui-même touché la carte ou utilisé son GPS :
  /// on ne remplace alors jamais son repère par le centre du quartier.
  bool _shopPinPlaced = false;
  bool _pickupPinPlaced = false;

  /// Vrai quand le repère affiché est seulement le centre du quartier.
  bool _shopAutoPlaced = false;
  bool _pickupAutoPlaced = false;

  @override
  void initState() {
    super.initState();
    _city = TextEditingController(text: widget.vendor.city ?? '');
    _area = TextEditingController(text: widget.vendor.area ?? '');
    _address = TextEditingController(text: widget.vendor.address ?? '');
    _pickupLandmark = TextEditingController(text: widget.vendor.pickupLandmark ?? '');
    _pickupAddress = TextEditingController(text: widget.vendor.pickupAddress ?? '');
    _deliveryInstructions = TextEditingController(text: widget.vendor.deliveryInstructions ?? '');
    _latitude = widget.vendor.latitude;
    _longitude = widget.vendor.longitude;
    _pickupLatitude = widget.vendor.pickupLatitude ?? widget.vendor.latitude;
    _pickupLongitude = widget.vendor.pickupLongitude ?? widget.vendor.longitude;
    _geo = widget.vendor.geo;
    _pickupGeo = widget.vendor.pickupGeo;
    _shopPinPlaced = widget.vendor.latitude != null && widget.vendor.longitude != null;
    _pickupPinPlaced = _pickupLatitude != null && _pickupLongitude != null;
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final api = widget.marketplace;
    if (api == null) {
      return;
    }
    try {
      final cities = await api.locations();
      if (!mounted) {
        return;
      }
      setState(() {
        _cities = cities;
        final center = _centerFor(_city.text.trim(), _area.text.trim());
        if (center != null) {
          _applyCenter(center);
        }
      });
    } catch (_) {
      // Référentiel indisponible : la carte garde son centre par défaut.
    }
  }

  /// Centre du quartier choisi, sinon barycentre des quartiers connus de la
  /// ville, sinon `null`.
  LatLng? _centerFor(String city, String area) {
    if (city.isEmpty) {
      return null;
    }
    double? lat;
    double? lng;
    var count = 0;
    for (final entry in _cities) {
      if (entry.city != city) {
        continue;
      }
      final neighborhood = entry.neighborhoodNamed(area);
      if (area.isNotEmpty &&
          neighborhood?.latitude != null &&
          neighborhood?.longitude != null) {
        return LatLng(neighborhood!.latitude!, neighborhood.longitude!);
      }
      for (final item in entry.neighborhoods) {
        if (item.latitude == null || item.longitude == null) {
          continue;
        }
        lat = (lat ?? 0) + item.latitude!;
        lng = (lng ?? 0) + item.longitude!;
        count++;
      }
    }
    if (count == 0) {
      return null;
    }
    return LatLng(lat! / count, lng! / count);
  }

  /// Recadre les deux cartes et pré-pose un repère au centre du quartier
  /// quand le vendeur n'a pas encore choisi de point.
  void _applyCenter(LatLng center) {
    _shopCenter = center;
    _pickupCenter = center;
    if (!_shopPinPlaced) {
      _latitude = center.latitude;
      _longitude = center.longitude;
      _shopAutoPlaced = true;
    }
    if (!_pickupPinPlaced) {
      _pickupLatitude = center.latitude;
      _pickupLongitude = center.longitude;
      _pickupAutoPlaced = true;
    }
  }

  void _onAreaSelected(CityAreaSelection selection) {
    setState(() {
      _geo = selection.geo;
      _pickupGeo ??= selection.geo;
    });
    final center = selection.latitude != null && selection.longitude != null
        ? LatLng(selection.latitude!, selection.longitude!)
        : _centerFor(selection.city ?? '', selection.area ?? '');
    if (center == null) {
      return;
    }
    setState(() => _applyCenter(center));
  }

  /// Met à jour le repère et tente de le rattacher au référentiel officiel.
  Future<void> _applyPoint(double latitude, double longitude, {required bool pickup}) async {
    setState(() {
      if (pickup) {
        _pickupLatitude = latitude;
        _pickupLongitude = longitude;
        _pickupPinPlaced = true;
        _pickupAutoPlaced = false;
      } else {
        _latitude = latitude;
        _longitude = longitude;
        _shopPinPlaced = true;
        _shopAutoPlaced = false;
      }
    });
    final api = widget.marketplace;
    if (api == null) {
      return;
    }
    try {
      final place = await api.geoReverse(latitude, longitude);
      if (!mounted || place == null) {
        return;
      }
      setState(() {
        final reference = place.toSelection(null, source: 'gps');
        if (pickup) {
          _pickupGeo = reference;
        } else {
          _geo = reference;
        }
      });
    } catch (_) {
      // Coordonnées conservées même sans correspondance administrative.
    }
  }

  @override
  void dispose() {
    _city.dispose();
    _area.dispose();
    _address.dispose();
    _pickupLandmark.dispose();
    _pickupAddress.dispose();
    _deliveryInstructions.dispose();
    super.dispose();
  }

  Future<void> _locate({required bool pickup}) async {
    setState(() {
      if (pickup) {
        _locatingPickup = true;
      } else {
        _locatingShop = true;
      }
    });
    final result = await LocationService.locate();
    if (!mounted) {
      return;
    }
    final geo = result.geo;
    setState(() {
      if (pickup) {
        _locatingPickup = false;
      } else {
        _locatingShop = false;
      }
    });
    if (geo != null) {
      await _applyPoint(geo.latitude, geo.longitude, pickup: pickup);
      if (!pickup && (_pickupLatitude == null || _pickupLongitude == null)) {
        await _applyPoint(geo.latitude, geo.longitude, pickup: true);
      }
    }
    if (!mounted) {
      return;
    }
    if (geo == null) {
      showToast(
        context,
        'Position introuvable. Touchez la carte pour placer le repère.',
        isError: true,
      );
    }
  }

  Future<void> _save() async {
    if (_latitude == null || _longitude == null) {
      showToast(
        context,
        'Placez le repère de la boutique sur la carte.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final api = widget.marketplace;
      if (api != null) {
        await api.updateVendorShop(
          city: _city.text,
          area: _area.text,
          address: _address.text,
          latitude: _latitude,
          longitude: _longitude,
          pickupAddress: _pickupAddress.text,
          pickupLandmark: _pickupLandmark.text,
          pickupLatitude: _pickupLatitude,
          pickupLongitude: _pickupLongitude,
          deliveryInstructions: _deliveryInstructions.text,
          geo: _geo,
          pickupGeo: _pickupGeo,
        );
      } else {
        showToast(context, 'Aperçu démo — lancez le serveur pour enregistrer.');
      }
      if (mounted) {
        showToast(context, 'Adresses mises à jour.');
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.fieldErrors.isNotEmpty) {
          showToast(context, e.fieldErrors.values.first.first, isError: true);
        } else {
          showToast(context, e.message, isError: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RestaurantPalette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ShopEditorAppBar(
              title: context.tr('Mes adresses'),
              onSave: _save,
              saving: _saving,
              api: widget.marketplace,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _SectionTitle(
                    icon: Icons.storefront_outlined,
                    title: 'Adresse de la boutique',
                    color: AppColors.orange,
                  ),
                  const SizedBox(height: 12),
                  if (widget.marketplace != null)
                    CityAreaPickerField(
                      marketplace: widget.marketplace!,
                      cityController: _city,
                      areaController: _area,
                      onChanged: _onAreaSelected,
                    )
                  else
                    CustomTextField(
                      label: context.tr('Ville'),
                      controller: _city,
                      hint: 'Cotonou',
                      textInputAction: TextInputAction.next,
                    ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: context.tr('Adresse exacte'),
                    required: true,
                    controller: _address,
                    hint: 'Numéro, rue, repère connu',
                    maxLines: 3,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Repère de la boutique',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: RestaurantPalette.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MapPicker(
                    point: _latitude != null && _longitude != null
                        ? LatLng(_latitude!, _longitude!)
                        : null,
                    initialCenter: _shopCenter,
                    instruction: 'Touchez la carte pour placer la boutique',
                    onLocate: () => _locate(pickup: false),
                    locating: _locatingShop,
                    onChanged: (point) async {
                      await _applyPoint(
                        point.latitude,
                        point.longitude,
                        pickup: false,
                      );
                      if (_pickupLatitude == null || _pickupLongitude == null) {
                        await _applyPoint(
                          point.latitude,
                          point.longitude,
                          pickup: true,
                        );
                      }
                    },
                  ),
                  if (_shopAutoPlaced)
                    const _AutoPinHint(
                      'Position approximative : centre du quartier. Touchez la carte pour la préciser.',
                    ),
                  const SizedBox(height: 26),
                  const _SectionTitle(
                    icon: Icons.local_shipping_outlined,
                    title: 'Adresse de retrait (livreurs)',
                    color: AppColors.orange,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: context.tr('Point de repère'),
                    controller: _pickupLandmark,
                    hint: 'Ex : face au marché de nuit',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: context.tr('Adresse de retrait'),
                    required: true,
                    controller: _pickupAddress,
                    hint: 'Entrepôt, porte bleue…',
                    maxLines: 3,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Repère du point de retrait',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: RestaurantPalette.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MapPicker(
                    point: _pickupLatitude != null && _pickupLongitude != null
                        ? LatLng(_pickupLatitude!, _pickupLongitude!)
                        : null,
                    initialCenter: _pickupCenter,
                    instruction: 'Touchez la carte pour placer le point de retrait',
                    onLocate: () => _locate(pickup: true),
                    locating: _locatingPickup,
                    onChanged: (point) => _applyPoint(
                      point.latitude,
                      point.longitude,
                      pickup: true,
                    ),
                  ),
                  if (_pickupAutoPlaced)
                    const _AutoPinHint(
                      'Position approximative : centre du quartier. Touchez la carte pour la préciser.',
                    ),
                  const SizedBox(height: 26),
                  const _SectionTitle(
                    icon: Icons.notes_outlined,
                    title: 'Informations supplémentaires',
                    color: AppColors.orange,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: context.tr('Instructions pour le livreur'),
                    controller: _deliveryInstructions,
                    hint: 'Ex : sonner à l’entrée, appeler en arrivant…',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: RestaurantPalette.darkText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rappelle que le repère affiché n'est que le centre du quartier choisi.
class _AutoPinHint extends StatelessWidget {
  const _AutoPinHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: RestaurantPalette.grayText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
