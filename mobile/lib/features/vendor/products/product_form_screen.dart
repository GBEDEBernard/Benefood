import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Création / édition d'un produit vendeur (J155).
///
/// Le prix est saisi en FCFA puis converti en centimes pour l'API.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, required this.marketplace, this.product});

  final MarketplaceApi marketplace;
  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _unit = TextEditingController();
  final _stock = TextEditingController();

  List<Category> _categories = [];
  Category? _category;
  bool _isAvailable = true;
  bool _loadingCategories = true;
  bool _saving = false;
  bool _deleting = false;
  bool _pickingImage = false;

  Uint8List? _imageBytes;
  String? _imageName;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product != null) {
      _name.text = product.name;
      _price.text = _priceToString(product.price);
      _description.text = product.description ?? '';
      _unit.text = product.unit;
      _stock.text = product.stockQty?.toString() ?? '';
      _isAvailable = product.isAvailable;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _unit.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final categories = await widget.marketplace.categories();
      if (!mounted) {
        return;
      }
      Category? selected;
      final product = widget.product;
      if (product != null) {
        for (final c in categories) {
          if (c.id == product.categoryId) {
            selected = c;
            break;
          }
        }
      }
      setState(() {
        _categories = categories;
        _category = selected;
        _loadingCategories = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
        setState(() => _loadingCategories = false);
      }
    }
  }

  double _parsePrice() {
    final text = _price.text.trim().replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(text) ?? 0;
  }

  int? _stockValue() {
    final text = _stock.text.trim();
    if (text.isEmpty) {
      return null;
    }
    return int.tryParse(text);
  }

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
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
        _imageBytes = bytes;
        _imageName = file.name;
      });
    } catch (_) {
      if (mounted) {
        showToast(context, 'Impossible de charger l\'image.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _pickingImage = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final category = _category;
    if (category == null) {
      showToast(context, 'Choisissez une catégorie', isError: true);
      return;
    }
    final priceCents = (_parsePrice() * 100).round();
    final description = _description.text.trim().isEmpty ? null : _description.text.trim();
    final unit = _unit.text.trim().isEmpty ? null : _unit.text.trim();
    final stockQty = _stockValue();

    setState(() => _saving = true);
    try {
      Product saved;
      if (_isEditing) {
        saved = await widget.marketplace.updateProduct(
          widget.product!.id,
          name: _name.text.trim(),
          price: priceCents,
          categoryId: category.id,
          description: description,
          unit: unit,
          stockQty: stockQty,
          isAvailable: _isAvailable,
        );
      } else {
        saved = await widget.marketplace.createProduct(
          name: _name.text.trim(),
          price: priceCents,
          categoryId: category.id,
          description: description,
          unit: unit,
          stockQty: stockQty,
          isAvailable: _isAvailable,
        );
      }
      await _uploadImageIfAny(saved.id);
      if (mounted) {
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

  Future<void> _uploadImageIfAny(String productId) async {
    final bytes = _imageBytes;
    if (bytes == null) {
      return;
    }
    await widget.marketplace.uploadProductImage(
      productId,
      bytes,
      fileName: _imageName,
      isMain: true,
    );
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer le produit',
      message: 'Voulez-vous vraiment supprimer « ${widget.product!.name} » ?',
      confirmLabel: 'Supprimer',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await widget.marketplace.deleteProduct(widget.product!.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Modifier le produit' : 'Nouveau produit')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImagePicker(),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _name,
                  label: 'Nom du produit',
                  icon: Icons.shopping_bag_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _price,
                        label: 'Prix (FCFA)',
                        icon: Icons.payments_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final value = double.tryParse((v ?? '').replaceAll(' ', '').replaceAll(',', '.'));
                          if (value == null || value <= 0) {
                            return 'Prix invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _stock,
                        label: 'Stock',
                        icon: Icons.inventory_2_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<Category>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Catégorie *'),
                  items: _categories
                      .map((c) => DropdownMenuItem<Category>(value: c, child: Text(c.name)))
                      .toList(),
                  onChanged: _loadingCategories ? null : (value) => setState(() => _category = value),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _unit,
                  label: 'Unité',
                  icon: Icons.straighten_outlined,
                  hint: 'pce, kg, sachet…',
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _description,
                  label: 'Description',
                  icon: Icons.notes_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                Card(
                  child: SwitchListTile(
                    title: const Text('Produit disponible'),
                    subtitle: const Text('Visible et commandable par les clients'),
                    value: _isAvailable,
                    onChanged: (v) => setState(() => _isAvailable = v),
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: _isEditing ? 'Enregistrer les modifications' : 'Créer le produit',
                  icon: Icons.save_outlined,
                  onPressed: _saving ? null : _save,
                  loading: _saving,
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Supprimer le produit',
                    icon: Icons.delete_outline,
                    variant: AppButtonVariant.danger,
                    onPressed: _deleting ? null : _delete,
                    loading: _deleting,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
Widget _buildImagePicker() {
    final theme = Theme.of(context);
    final current = _imageBytes != null
        ? Image.memory(_imageBytes!, fit: BoxFit.cover)
        : AppNetworkImage(url: widget.product?.imageUrl, icon: Icons.add_photo_alternate_outlined);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photo du produit', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: current,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: _pickingImage
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_library_outlined),
                    label: Text(_imageBytes != null ? 'Changer l\'image' : 'Choisir une image'),
                    onPressed: _pickingImage ? null : _pickImage,
                  ),
                ),
                if (_imageBytes != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Retirer l\'image',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                      _imageBytes = null;
                      _imageName = null;
                    }),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _priceToString(int cents) {
  if (cents % 100 == 0) {
    return (cents ~/ 100).toString();
  }
  return (cents / 100).toStringAsFixed(2);
}