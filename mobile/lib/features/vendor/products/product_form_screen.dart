import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/app_button.dart';
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
      if (_isEditing) {
        await widget.marketplace.updateProduct(
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
        await widget.marketplace.createProduct(
          name: _name.text.trim(),
          price: priceCents,
          categoryId: category.id,
          description: description,
          unit: unit,
          stockQty: stockQty,
          isAvailable: _isAvailable,
        );
      }
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
}

String _priceToString(int cents) {
  if (cents % 100 == 0) {
    return (cents ~/ 100).toString();
  }
  return (cents / 100).toStringAsFixed(2);
}