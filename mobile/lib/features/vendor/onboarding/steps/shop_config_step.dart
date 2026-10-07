import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/category.dart';
import '../widgets/custom_text_field.dart';

/// Étape 3/4 — Configuration de la boutique : identité visuelle (nom,
/// description, catégorie) et médias (logo, image de couverture).
class ShopConfigStep extends StatefulWidget {
  const ShopConfigStep({
    super.key,
    required this.formKey,
    required this.shopName,
    required this.description,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.logoBytes,
    required this.logoUrl,
    required this.onPickLogo,
    required this.coverBytes,
    required this.coverUrl,
    required this.onPickCover,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController shopName;
  final TextEditingController description;
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final Uint8List? logoBytes;
  final String? logoUrl;
  final VoidCallback onPickLogo;
  final Uint8List? coverBytes;
  final String? coverUrl;
  final VoidCallback onPickCover;

  @override
  State<ShopConfigStep> createState() => _ShopConfigStepState();
}

class _ShopConfigStepState extends State<ShopConfigStep> {
  @override
  void initState() {
    super.initState();
    // Le nom alimente le placeholder du logo : on rebuild sur chaque frappe.
    widget.shopName.addListener(_onShopNameChanged);
  }

  @override
  void dispose() {
    widget.shopName.removeListener(_onShopNameChanged);
    super.dispose();
  }

  void _onShopNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            label: 'Nom de la boutique',
            required: true,
            controller: widget.shopName,
            hint: 'Le Délice Fast-Food',
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Indiquez le nom de la boutique' : null,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Description',
            required: true,
            controller: widget.description,
            hint: 'Spécialités, plats signature, horaires…',
            maxLines: 4,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ajoutez une description' : null,
          ),
          const SizedBox(height: 16),
          _Label(text: 'Catégorie', required: true),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            // Recrée le champ quand la pré-sélection ou la liste arrive,
            // pour que `initialValue` reprenne la valeur du dossier.
            key: ValueKey(
              '${widget.categories.length}:${widget.selectedCategoryId ?? ''}',
            ),
            initialValue:
                widget.categories.any((c) => c.id == widget.selectedCategoryId)
                    ? widget.selectedCategoryId
                    : null,
            isExpanded: true,
            hint: const Text('Fast-food'),
            style: const TextStyle(fontSize: 15, color: AppColors.text),
            decoration: _inputDecoration(),
            items: [
              for (final category in widget.categories)
                if (category.isActive)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name, overflow: TextOverflow.ellipsis),
                  ),
            ],
            onChanged: widget.onCategoryChanged,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Choisissez une catégorie' : null,
          ),
          const SizedBox(height: 20),
          _Label(text: 'Logo', required: true),
          const SizedBox(height: 10),
          Center(
            child: Tooltip(
              message: 'Ajouter le logo',
              child: InkWell(
                onTap: widget.onPickLogo,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 116,
                  height: 116,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: ClipOval(child: _logoContent()),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: _CameraBadge(icon: widget.logoBytes != null || widget.logoUrl != null ? Icons.edit : Icons.camera_alt_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Label(text: 'Image de couverture', required: true),
          const SizedBox(height: 10),
          Tooltip(
            message: 'Ajouter la couverture',
            child: InkWell(
              onTap: widget.onPickCover,
              borderRadius: BorderRadius.circular(14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 132,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _coverContent(),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _CameraBadge(
                          icon: widget.coverBytes != null || widget.coverUrl != null
                              ? Icons.edit
                              : Icons.camera_alt_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoContent() {
    final bytes = widget.logoBytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, width: 116, height: 116);
    }
    final url = widget.logoUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: 116,
        height: 116,
        errorBuilder: (_, _, _) => _logoPlaceholder(),
      );
    }
    return _logoPlaceholder();
  }

  Widget _logoPlaceholder() {
    final name = widget.shopName.text.trim().toUpperCase();
    return Container(
      color: AppColors.surfaceVariant,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront_outlined, size: 26, color: AppColors.textSecondary),
          const SizedBox(height: 6),
          Text(
            name.isEmpty ? 'Ajouter un logo' : name,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverContent() {
    final bytes = widget.coverBytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover);
    }
    final url = widget.coverUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _coverPlaceholder(),
      );
    }
    return _coverPlaceholder();
  }

  Widget _coverPlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 32, color: AppColors.textFaint),
          SizedBox(height: 6),
          Text(
            'Ajouter une image de la boutique',
            style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}

/// Label au-dessus d'un champ non textuel (dropdown, média).
class _Label extends StatelessWidget {
  const _Label({required this.text, required this.required});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        children: [
          if (required)
            const TextSpan(text: ' *', style: TextStyle(color: AppColors.orange)),
        ],
      ),
    );
  }
}

/// Pastille ronde blanche à liseré orange avec icône caméra.
class _CameraBadge extends StatelessWidget {
  const _CameraBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.orange, width: 1.5),
      ),
      child: Icon(icon, size: 17, color: AppColors.orange),
    );
  }
}

InputDecoration _inputDecoration() {
  const outline = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: AppColors.borderStrong),
  );
  return const InputDecoration(
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: outline,
    enabledBorder: outline,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.orange, width: 1.6),
    ),
  );
}
