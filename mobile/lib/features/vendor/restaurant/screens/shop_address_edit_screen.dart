import 'package:flutter/material.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../shared/models/vendor.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../onboarding/widgets/custom_text_field.dart';
import '../restaurant_palette.dart';
import 'shop_edit_shell.dart';

/// Édition de l'adresse et de la ville de la boutique.
class ShopAddressEditScreen extends StatefulWidget {
  const ShopAddressEditScreen({super.key, required this.vendor, this.marketplace});

  final Vendor vendor;
  final MarketplaceApi? marketplace;

  @override
  State<ShopAddressEditScreen> createState() => _ShopAddressEditScreenState();
}

class _ShopAddressEditScreenState extends State<ShopAddressEditScreen> {
  late final TextEditingController _city;
  late final TextEditingController _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _city = TextEditingController(text: widget.vendor.city ?? '');
    _address = TextEditingController(text: widget.vendor.address ?? '');
  }

  @override
  void dispose() {
    _city.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = widget.marketplace;
      if (api != null) {
        await api.updateVendorShop(city: _city.text, address: _address.text);
      } else {
        showToast(context, 'Aperçu démo — lancez le serveur pour enregistrer.');
      }
      if (mounted) {
        showToast(context, 'Adresse mise à jour.');
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
            ShopEditorAppBar(title: 'Adresse', onSave: _save, saving: _saving),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: RestaurantPalette.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(RestaurantPalette.radius),
                      border: Border.all(color: RestaurantPalette.orange.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.place_outlined, color: RestaurantPalette.orange, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cette adresse est affichée aux clients sur votre fiche boutique et sert au calcul de la livraison.',
                            style: TextStyle(color: RestaurantPalette.grayText, fontSize: 13, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    label: 'Ville',
                    controller: _city,
                    hint: 'Cotonou',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Adresse',
                    controller: _address,
                    hint: 'Cadjèhoun, carrefour des 3 collèges',
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}