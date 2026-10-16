import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Création / édition d'un produit vendeur (J155).
///
/// Le prix est saisi et transmis directement en FCFA (XOF, sans décimales).
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
  bool _pickingImages = false;
  bool _pickingVideo = false;
  bool _removingExistingImage = false;

  /// Nouvelles photos sélectionnées (hors modifications de produits existants).
  final List<Uint8List> _newImages = [];
  final List<String> _newImageNames = [];

  /// Photos déjà rattachées au produit (mode édition).
  final List<ProductImage> _existingImages = [];
  Product? _createdProduct;
  String? _existingVideoUrl;

  /// Petite vidéo sélectionnée (nulle si inchangée/absente).
  Uint8List? _videoBytes;
  String? _videoName;
  bool _videoRemoved = false;

  Product? get _editingProduct => widget.product ?? _createdProduct;
  bool get _isEditing => _editingProduct != null;

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
      _existingImages.addAll(product.images);
      _existingVideoUrl = product.videoUrl;
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

  Future<void> _pickImages() async {
    setState(() => _pickingImages = true);
    try {
      final files = await ImagePicker().pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (files.isEmpty || !mounted) {
        return;
      }
      final bytes = <Uint8List>[];
      final names = <String>[];
      for (final file in files) {
        final data = await file.readAsBytes();
        bytes.add(data);
        names.add(file.name);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _newImages.addAll(bytes);
        _newImageNames.addAll(names);
      });
    } catch (_) {
      if (mounted) {
        showToast(context, 'Impossible de charger les photos.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _pickingImages = false);
      }
    }
  }

  Future<void> _pickVideo() async {
    setState(() => _pickingVideo = true);
    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      if (file == null || !mounted) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _videoBytes = bytes;
        _videoName = file.name;
        _videoRemoved = false;
      });
    } catch (_) {
      if (mounted) {
        showToast(context, 'Impossible de charger la vidéo.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _pickingVideo = false);
      }
    }
  }

  Future<void> _removeExistingImage(ProductImage image) async {
    if (_removingExistingImage || !_isEditing) {
      return;
    }
    setState(() => _removingExistingImage = true);
    try {
      await widget.marketplace.removeProductImage(_editingProduct!.id, image.id);
      if (!mounted) {
        return;
      }
      setState(() => _existingImages.removeWhere((i) => i.id == image.id));
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _removingExistingImage = false);
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
    if (_existingImages.isEmpty && _newImages.isEmpty) {
      showToast(context, 'Ajoutez au moins une photo du produit.', isError: true);
      return;
    }
    final priceXof = _parsePrice().round();
    final description = _description.text.trim().isEmpty
        ? null
        : _description.text.trim();
    final unit = _unit.text.trim().isEmpty ? null : _unit.text.trim();
    final stockQty = _stockValue();

    setState(() => _saving = true);
    try {
      final editingProduct = _editingProduct;
      Product saved;
      if (editingProduct != null) {
        saved = await widget.marketplace.updateProduct(
          editingProduct.id,
          name: _name.text.trim(),
          price: priceXof,
          categoryId: category.id,
          description: description,
          unit: unit,
          stockQty: stockQty,
          isAvailable: _isAvailable,
        );
      } else {
        saved = await widget.marketplace.createProduct(
          name: _name.text.trim(),
          price: priceXof,
          categoryId: category.id,
          description: description,
          unit: unit,
          stockQty: stockQty,
          isAvailable: _isAvailable,
        );
        setState(() => _createdProduct = saved);
      }
      await _uploadMediaIfAny(saved.id);
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
    } catch (e) {
      if (mounted) {
        showToast(context, 'Impossible d’enregistrer le produit : $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _uploadMediaIfAny(String productId) async {
    while (_newImages.isNotEmpty) {
      final image = await widget.marketplace.uploadProductImage(
        productId,
        _newImages.first,
        fileName: _newImageNames.first,
        isMain: _existingImages.isEmpty,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _existingImages.add(image);
        _newImages.removeAt(0);
        _newImageNames.removeAt(0);
      });
    }

    final video = _videoBytes;
    if (video != null) {
      final videoUrl = await widget.marketplace.uploadProductVideo(
        productId,
        video,
        fileName: _videoName,
      );
      if (mounted) {
        setState(() {
          _existingVideoUrl = videoUrl;
          _videoBytes = null;
          _videoName = null;
        });
      }
    } else if (_videoRemoved && _isEditing) {
      await widget.marketplace.removeProductVideo(productId);
      if (mounted) {
        setState(() {
          _existingVideoUrl = null;
          _videoRemoved = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer le produit',
      message: 'Voulez-vous vraiment supprimer « ${_editingProduct!.name} » ?',
      confirmLabel: 'Supprimer',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await widget.marketplace.deleteProduct(_editingProduct!.id);
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
    return BeninfoodPageScaffold(
      title: _isEditing ? 'Modifier le produit' : 'Nouveau produit',
      api: widget.marketplace,
      audience: NotificationAudience.vendor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMediaPicker(),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _name,
                  label: 'Nom du produit',
                  icon: Icons.shopping_bag_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _price,
                        label: 'Prix (FCFA)',
                        icon: Icons.payments_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final value = double.tryParse(
                            (v ?? '').replaceAll(' ', '').replaceAll(',', '.'),
                          );
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
                      .map(
                        (c) => DropdownMenuItem<Category>(
                          value: c,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: _loadingCategories
                      ? null
                      : (value) => setState(() => _category = value),
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
                    subtitle: const Text(
                      'Visible et commandable par les clients',
                    ),
                    value: _isAvailable,
                    onChanged: (v) => setState(() => _isAvailable = v),
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: _isEditing
                      ? 'Enregistrer les modifications'
                      : 'Créer le produit',
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

  Widget _buildMediaPicker() {
    final theme = Theme.of(context);

    final totalImages = _existingImages.length + _newImages.length;
    const canAddMore = true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photos du produit', style: theme.textTheme.titleSmall),
            Text(
              'Plusieurs photos possibles · $totalImages sélectionnée${totalImages == 1 ? '' : 's'} · 1 minimum',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            _buildImageThumbnails(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: _pickingImages
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _newImages.isEmpty && _existingImages.isEmpty
                          ? 'Ajouter des photos'
                          : 'Ajouter des photos',
                    ),
                    onPressed: _pickingImages || !canAddMore
                        ? null
                        : _pickImages,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Petite vidéo', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildVideoTile(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnails() {
    if (_existingImages.isEmpty && _newImages.isEmpty) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: 40,
            color: AppColors.textFaint,
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final image in _existingImages)
            _photoThumb(
              child: AppNetworkImage(url: image.url, fit: BoxFit.cover),
              onRemove: _isEditing ? () => _removeExistingImage(image) : null,
            ),
          for (var i = 0; i < _newImages.length; i++)
            _photoThumb(
              child: Image.memory(_newImages[i], fit: BoxFit.cover),
              onRemove: () => setState(() {
                _newImages.removeAt(i);
                _newImageNames.removeAt(i);
              }),
            ),
        ],
      ),
    );
  }

  Widget _photoThumb({required Widget child, VoidCallback? onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 100,
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (onRemove != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: _removingExistingImage ? null : onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoTile() {
    final theme = Theme.of(context);
    final hasExisting =
        _existingVideoUrl != null && !_videoRemoved;
    final hasNew = _videoBytes != null;

    if (hasExisting || hasNew) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_outline, color: AppColors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasNew
                    ? 'Vidéo ajoutée (${_videoName ?? 'clip'})'
                    : 'Vidéo actuelle',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Retirer la vidéo',
              icon: const Icon(Icons.delete_outline),
              onPressed: _pickingVideo
                  ? null
                  : () => setState(() {
                      _videoBytes = null;
                      _videoName = null;
                      _videoRemoved = true;
                    }),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      icon: _pickingVideo
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.videocam_outlined),
      label: const Text('Ajouter une petite vidéo'),
      onPressed: _pickingVideo ? null : _pickVideo,
    );
  }
}

String _priceToString(int price) {
  return price.toString();
}
