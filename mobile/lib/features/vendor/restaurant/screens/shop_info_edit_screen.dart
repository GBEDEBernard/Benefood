import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../shared/models/vendor.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../onboarding/widgets/custom_text_field.dart';
import '../restaurant_palette.dart';
import 'shop_edit_shell.dart';

/// Métadonnée d'un média (logo / couverture) sélectionné par le vendeur.
class _PickedMedia {
  const _PickedMedia(this.bytes, this.name);

  final Uint8List bytes;
  final String name;
}

/// Édition des informations de la boutique : nom, description, téléphone,
/// e-mail, logo et photo de couverture.
class ShopInfoEditScreen extends StatefulWidget {
  const ShopInfoEditScreen({super.key, required this.vendor, this.marketplace});

  final Vendor vendor;
  final MarketplaceApi? marketplace;

  @override
  State<ShopInfoEditScreen> createState() => _ShopInfoEditScreenState();
}

class _ShopInfoEditScreenState extends State<ShopInfoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _phone;
  late final TextEditingController _email;

  _PickedMedia? _logo;
  _PickedMedia? _cover;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.vendor.businessName);
    _description = TextEditingController(text: widget.vendor.description ?? '');
    _phone = TextEditingController(text: widget.vendor.phone ?? '');
    _email = TextEditingController(text: widget.vendor.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickMedia({required bool isLogo}) async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        final media = _PickedMedia(bytes, file.name);
        if (isLogo) {
          _logo = media;
        } else {
          _cover = media;
        }
      });
    } catch (_) {
      if (mounted) {
        showToast(context, 'Impossible de charger l\'image.', isError: true);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final api = widget.marketplace;
      if (api != null) {
        await api.updateVendorShop(
          businessName: _name.text,
          description: _description.text,
          phone: _phone.text,
          email: _email.text,
        );
        if (_logo != null || _cover != null) {
          await api.updateVendorMedia(logo: _logo?.bytes, cover: _cover?.bytes);
        }
      } else {
        showToast(context, 'Aperçu démo — lancez le serveur pour enregistrer.');
      }
      if (mounted) {
        showToast(context, 'Boutique mise à jour.');
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
            ShopEditorAppBar(title: 'Informations', onSave: _save, saving: _saving),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildMediaCards(context),
                    const SizedBox(height: 24),
                    const ShopEditLabel('À propos de la boutique'),
                    const SizedBox(height: 10),
                    CustomTextField(
                      label: 'Nom de la boutique',
                      controller: _name,
                      required: true,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est requis.' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'Description',
                      controller: _description,
                      hint: 'Cuisine, spécialités, délais…',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),
                    const ShopEditLabel('Coordonnées'),
                    const SizedBox(height: 10),
                    CustomTextField(
                      label: 'Téléphone',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      hint: '+229 01 02 03 04 05',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'E-mail',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      hint: 'contact@ma-boutique.com',
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCards(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShopEditLabel(
          'Visuels',
          helper: 'Logo et photo de couverture affichés sur votre fiche boutique.',
        ),
        const SizedBox(height: 10),
        _MediaEditor(
          label: 'Photo de couverture',
          height: 140,
          preview: _cover?.bytes != null
              ? Image.memory(_cover!.bytes, fit: BoxFit.cover)
              : (widget.vendor.coverUrl == null
                  ? null
                  : Image.network(widget.vendor.coverUrl!, fit: BoxFit.cover)),
          fallbackGradient: true,
          onPick: () => _pickMedia(isLogo: false),
        ),
        const SizedBox(height: 12),
        _MediaEditor(
          label: 'Logo',
          height: 84,
          preview: _logo?.bytes != null
              ? Image.memory(_logo!.bytes, fit: BoxFit.cover)
              : (widget.vendor.logoUrl == null
                  ? null
                  : Image.network(widget.vendor.logoUrl!, fit: BoxFit.cover)),
          onPick: () => _pickMedia(isLogo: true),
        ),
      ],
    );
  }
}

class _MediaEditor extends StatelessWidget {
  const _MediaEditor({
    required this.label,
    required this.height,
    required this.preview,
    required this.onPick,
    this.fallbackGradient = false,
  });

  final String label;
  final double height;
  final Widget? preview;
  final VoidCallback onPick;
  final bool fallbackGradient;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: RestaurantPalette.darkText, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: height,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(RestaurantPalette.radius),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: preview ??
                  (fallbackGradient
                      ? const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [RestaurantPalette.forest, Color(0xFF134E2E)],
                            ),
                          ),
                        )
                      : Container(
                          color: RestaurantPalette.forest,
                          child: Center(
                            child: Icon(
                              Icons.storefront,
                              size: height >= 100 ? 56 : 36,
                              color: Colors.white,
                            ),
                          ),
                        )),
            ),
            Positioned(
              right: 12,
              bottom: -14,
              child: SizedBox(
                height: 36,
                child: FilledButton.icon(
                  onPressed: onPick,
                  style: FilledButton.styleFrom(
                    backgroundColor: RestaurantPalette.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Changer', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}