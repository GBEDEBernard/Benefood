import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/vendor.dart';
import '../../../../shared/widgets/city_area_picker.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/map_picker.dart';
import '../../onboarding/widgets/custom_text_field.dart';
import '../restaurant_palette.dart';
import 'shop_edit_shell.dart';

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
      if (geo != null) {
        if (pickup) {
          _pickupLatitude = geo.latitude;
          _pickupLongitude = geo.longitude;
        } else {
          _latitude = geo.latitude;
          _longitude = geo.longitude;
          if (_pickupLatitude == null || _pickupLongitude == null) {
            _pickupLatitude = geo.latitude;
            _pickupLongitude = geo.longitude;
          }
        }
      }
    });
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
              title: 'Mes adresses',
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
                    )
                  else
                    CustomTextField(
                      label: 'Ville',
                      controller: _city,
                      hint: 'Cotonou',
                      textInputAction: TextInputAction.next,
                    ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Adresse exacte',
                    required: true,
                    controller: _address,
                    hint: 'Cadjèhoun, carrefour des 3 collèges',
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
                    instruction: 'Touchez la carte pour placer la boutique',
                    onLocate: () => _locate(pickup: false),
                    locating: _locatingShop,
                    onChanged: (point) {
                      setState(() {
                        _latitude = point.latitude;
                        _longitude = point.longitude;
                        if (_pickupLatitude == null || _pickupLongitude == null) {
                          _pickupLatitude = point.latitude;
                          _pickupLongitude = point.longitude;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 26),
                  const _SectionTitle(
                    icon: Icons.local_shipping_outlined,
                    title: 'Adresse de retrait (livreurs)',
                    color: AppColors.orange,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Point de repère',
                    controller: _pickupLandmark,
                    hint: 'Ex : face au marché de nuit',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Adresse de retrait',
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
                    instruction: 'Touchez la carte pour placer le point de retrait',
                    onLocate: () => _locate(pickup: true),
                    locating: _locatingPickup,
                    onChanged: (point) {
                      setState(() {
                        _pickupLatitude = point.latitude;
                        _pickupLongitude = point.longitude;
                      });
                    },
                  ),
                  const SizedBox(height: 26),
                  const _SectionTitle(
                    icon: Icons.notes_outlined,
                    title: 'Informations supplémentaires',
                    color: AppColors.orange,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Instructions pour le livreur',
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
