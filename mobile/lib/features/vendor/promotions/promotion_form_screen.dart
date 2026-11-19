import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/product_promotion.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';

enum _PromotionMode { percent, price }

enum _PromotionScope { single, selected, all }

/// Création / édition d'une promotion vendeur.
///
/// Le vendeur peut saisir directement un pourcentage et l'appliquer à un plat,
/// à une sélection de plats ou à toute sa boutique. Le prix promo en FCFA est
/// calculé puis envoyé à l'API, qui le recalcule et le valide côté serveur.
class PromotionFormScreen extends StatefulWidget {
  const PromotionFormScreen({
    super.key,
    required this.marketplace,
    required this.products,
    this.promotion,
  });

  final MarketplaceApi marketplace;
  final List<Product> products;
  final ProductPromotion? promotion;

  @override
  State<PromotionFormScreen> createState() => _PromotionFormScreenState();
}

class _PromotionFormScreenState extends State<PromotionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _promoPrice = TextEditingController();
  final _discountPercent = TextEditingController();
  final _title = TextEditingController();

  late String? _productId;
  late Set<String> _selectedProductIds;
  late _PromotionMode _mode;
  late _PromotionScope _scope;
  late DateTime _startsAt;
  late DateTime _endsAt;
  late bool _isActive;
  bool _saving = false;

  bool get _isEditing => widget.promotion != null;

  Product? get _selectedProduct {
    for (final product in widget.products) {
      if (product.id == _productId) {
        return product;
      }
    }
    return null;
  }

  List<Product> get _targetProducts {
    if (_mode == _PromotionMode.percent && _scope == _PromotionScope.all) {
      return widget.products;
    }
    if (_mode == _PromotionMode.percent && _scope == _PromotionScope.selected) {
      return widget.products
          .where((product) => _selectedProductIds.contains(product.id))
          .toList();
    }
    final product = _selectedProduct;
    return product == null ? const [] : [product];
  }

  int? get _promoPriceValue {
    final text = _promoPrice.text.trim().replaceAll(' ', '').replaceAll(',', '.');
    return int.tryParse(text);
  }

  int? get _percentValue =>
      int.tryParse(_discountPercent.text.trim().replaceAll(',', '.'));

  int promoPriceFor(Product product) {
    if (_mode == _PromotionMode.price) {
      return _promoPriceValue ?? product.price;
    }
    final percent = _percentValue ?? 0;
    return ((product.price * (100 - percent)) / 100).round();
  }

  int get _displayedPercent {
    if (_mode == _PromotionMode.percent) {
      return _percentValue ?? 0;
    }
    final product = _selectedProduct;
    final price = _promoPriceValue;
    if (product == null || price == null || product.price <= 0 || price <= 0) {
      return 0;
    }
    if (price >= product.price) {
      return 0;
    }
    return (((product.price - price) / product.price) * 100).round();
  }

  @override
  void initState() {
    super.initState();
    final promotion = widget.promotion;
    final now = DateTime.now().copyWith(second: 0, microsecond: 0);

    if (promotion != null) {
      _productId = promotion.productId.isNotEmpty
          ? promotion.productId
          : promotion.product?.id;
      _selectedProductIds = <String>{?_productId};
      _promoPrice.text = promotion.promoPrice.toString();
      _discountPercent.text = promotion.displayedDiscountPercent.toString();
      _title.text = promotion.title ?? '';
      _startsAt = promotion.startsAt ?? now;
      _endsAt = promotion.endsAt ?? now.add(const Duration(days: 7));
      _isActive = promotion.isActive;
    } else {
      _productId = widget.products.isEmpty ? null : widget.products.first.id;
      _selectedProductIds = <String>{?_productId};
      _startsAt = now;
      _endsAt = now.add(const Duration(days: 7));
      _isActive = true;
    }

    _mode = _PromotionMode.percent;
    _scope = _PromotionScope.single;

    _discountPercent.addListener(_refreshPreview);
    _promoPrice.addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _discountPercent.removeListener(_refreshPreview);
    _promoPrice.removeListener(_refreshPreview);
    _promoPrice.dispose();
    _discountPercent.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool starts}) async {
    final now = DateTime.now();
    final current = starts ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current.isBefore(now) && starts ? now : current,
      firstDate: starts
          ? DateTime(now.year, now.month, now.day)
          : DateTime(
              _startsAt.year,
              _startsAt.month,
              _startsAt.day,
            ),
      lastDate: now.add(const Duration(days: 365)),
      helpText: starts ? 'Date de début de l’offre' : 'Date de fin de l’offre',
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: starts ? 'Heure de début' : 'Heure de fin',
    );
    if (time == null || !mounted) {
      return;
    }

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (starts) {
        _startsAt = picked;
        if (!_endsAt.isAfter(_startsAt)) {
          _endsAt = _startsAt.add(const Duration(days: 1));
        }
      } else if (picked.isAfter(_startsAt)) {
        _endsAt = picked;
      } else {
        _endsAt = _startsAt.add(const Duration(days: 1));
        showToast(
          context,
          'La fin doit être postérieure au début. Une journée a été ajoutée.',
          isError: true,
        );
      }
    });
  }

  bool _validateTargets() {
    final targets = _targetProducts;
    if (targets.isEmpty) {
      showToast(context, 'Sélectionnez au moins un plat.', isError: true);
      return false;
    }
    if (_mode == _PromotionMode.percent) {
      final percent = _percentValue;
      if (percent == null || percent < 1 || percent > 99) {
        showToast(
          context,
          'Le pourcentage doit être compris entre 1 et 99.',
          isError: true,
        );
        return false;
      }
      for (final product in targets) {
        final price = promoPriceFor(product);
        if (price < 1 || price >= product.price) {
          showToast(
            context,
            'La remise est trop élevée pour « ${product.name} ».',
            isError: true,
          );
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_validateTargets()) {
      return;
    }

    final title = _title.text.trim();
    setState(() => _saving = true);

    try {
      final promotion = widget.promotion;
      if (promotion != null) {
        final percent = _mode == _PromotionMode.percent ? _percentValue : null;
        await widget.marketplace.updatePromotion(
          promotion.id,
          promoPrice: _mode == _PromotionMode.price ? _promoPriceValue : null,
          discountPercent: percent,
          startsAt: _startsAt,
          endsAt: _endsAt,
          title: title,
          isActive: _isActive,
        );
      } else if (_mode == _PromotionMode.percent) {
        final batch = await widget.marketplace.createPromotionsFromPercent(
          discountPercent: _percentValue!,
          productIds: _scope == _PromotionScope.selected
              ? _selectedProductIds.toList()
              : (_scope == _PromotionScope.single
                  ? [_productId!]
                  : null),
          allProducts: _scope == _PromotionScope.all,
          startsAt: _startsAt,
          endsAt: _endsAt,
          title: title,
          isActive: _isActive,
        );
        if (!mounted) {
          return;
        }
        if (!batch.hasCreated) {
          showToast(
            context,
            batch.skipped.isNotEmpty
                ? 'Aucune offre créée. ${batch.skipped.first.message}'
                : 'Aucun plat concerné par cette offre.',
            isError: true,
          );
          return;
        }
        final skipped = batch.skippedCount;
        showToast(
          context,
          skipped == 0
              ? '${batch.createdCount} offre${batch.createdCount > 1 ? 's' : ''} créée${batch.createdCount > 1 ? 's' : ''}.'
              : '${batch.createdCount} offre${batch.createdCount > 1 ? 's' : ''} créée${batch.createdCount > 1 ? 's' : ''}, $skipped ignorée${skipped > 1 ? 's' : ''}.',
        );
        Navigator.of(context).pop(true);
        return;
      } else {
        await widget.marketplace.createPromotion(
          productId: _productId!,
          promoPrice: _promoPriceValue!,
          startsAt: _startsAt,
          endsAt: _endsAt,
          title: title,
          isActive: _isActive,
        );
      }

      if (!mounted) {
        return;
      }
      showToast(
        context,
        promotion == null ? 'Promotion créée.' : 'Promotion mise à jour.',
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        showToast(context, error.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BeninfoodPageScaffold(
      title: _isEditing ? 'Modifier la promotion' : 'Créer une promotion',
      api: widget.marketplace,
      audience: NotificationAudience.vendor,
      body: widget.products.isEmpty && !_isEditing
          ? const EmptyState(
              icon: Icons.restaurant_menu,
              title: 'Aucun plat disponible',
              subtitle: 'Ajoutez d’abord un produit avant de créer une offre.',
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding,
                  4,
                  AppDimens.pagePadding,
                  32,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 18),
                      _buildModeSelector(),
                      if (!_isEditing && _mode == _PromotionMode.percent) ...[
                        const SizedBox(height: 18),
                        _buildScopeSelector(),
                      ],
                      const SizedBox(height: 18),
                      _buildTargetField(),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _title,
                        label: 'Titre de l’offre (facultatif)',
                        hint: 'Ex. Offre du jour, Happy hour…',
                        icon: Icons.label_outlined,
                        validator: (value) {
                          if (value != null && value.trim().length > 120) {
                            return '120 caractères maximum.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _mode == _PromotionMode.percent
                          ? _buildPercentField()
                          : _buildPriceField(),
                      const SizedBox(height: 16),
                      _buildDateTimeTile(
                        label: 'Début de l’offre',
                        value: _startsAt,
                        icon: Icons.play_circle_outline,
                        onTap: () => _pickDateTime(starts: true),
                      ),
                      const SizedBox(height: 10),
                      _buildDateTimeTile(
                        label: 'Fin de l’offre',
                        value: _endsAt,
                        icon: Icons.event_available_outlined,
                        onTap: () => _pickDateTime(starts: false),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile.adaptive(
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                        activeThumbColor: AppColors.orange,
                        activeTrackColor: AppColors.orangeLight,
                        title: const Text(
                          'Activer immédiatement',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: const Text(
                          'Désactivez pour préparer une offre sans la diffuser.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildPreviewCard(),
                      const SizedBox(height: 24),
                      AppButton(
                        label: _isEditing
                            ? 'Enregistrer les modifications'
                            : (_mode == _PromotionMode.percent &&
                                    _scope != _PromotionScope.single
                                ? 'Créer ${_targetProducts.length} offre${_targetProducts.length > 1 ? 's' : ''}'
                                : 'Créer la promotion'),
                        icon: Icons.local_offer_outlined,
                        loading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.goldLight, AppColors.orangeLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Une offre en 3 étapes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choisissez un pourcentage, les plats concernés puis la '
                  'période. Le prix promo est calculé automatiquement.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Comment fixer la remise ?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        SegmentedButton<_PromotionMode>(
          segments: const [
            ButtonSegment<_PromotionMode>(
              value: _PromotionMode.percent,
              icon: Icon(Icons.percent),
              label: Text('Pourcentage'),
            ),
            ButtonSegment<_PromotionMode>(
              value: _PromotionMode.price,
              icon: Icon(Icons.sell_outlined),
              label: Text('Prix fixe'),
            ),
          ],
          selected: <_PromotionMode>{_mode},
          onSelectionChanged: (selection) {
            setState(() {
              _mode = selection.first;
              if (_mode == _PromotionMode.price) {
                _scope = _PromotionScope.single;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildScopeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Appliquer la remise à…',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('1 plat'),
              avatar: const Icon(Icons.fastfood_outlined, size: 16),
              selected: _scope == _PromotionScope.single,
              selectedColor: AppColors.orangeLight,
              onSelected: (_) =>
                  setState(() => _scope = _PromotionScope.single),
            ),
            ChoiceChip(
              label: const Text('Plusieurs plats'),
              avatar: const Icon(Icons.checklist_outlined, size: 16),
              selected: _scope == _PromotionScope.selected,
              selectedColor: AppColors.orangeLight,
              onSelected: (_) =>
                  setState(() => _scope = _PromotionScope.selected),
            ),
            ChoiceChip(
              label: const Text('Tous les plats'),
              avatar: const Icon(Icons.storefront_outlined, size: 16),
              selected: _scope == _PromotionScope.all,
              selectedColor: AppColors.orangeLight,
              onSelected: (_) => setState(() => _scope = _PromotionScope.all),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTargetField() {
    if (_mode == _PromotionMode.percent &&
        _scope == _PromotionScope.selected) {
      return _buildProductChecklist();
    }
    if (_mode == _PromotionMode.percent && _scope == _PromotionScope.all) {
      return _buildAllProductsCard();
    }
    return _buildProductDropdown();
  }

  Widget _buildProductDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _productId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Plat concerné',
            prefixIcon: Icon(Icons.fastfood_outlined),
            border: OutlineInputBorder(),
          ),
          items: widget.products
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item.id,
                  child: Text(
                    '${item.name} — ${formatAmount(item.price)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _isEditing
              ? null
              : (value) => setState(() {
                    _productId = value;
                    if (value != null) {
                      _selectedProductIds = <String>{value};
                    }
                  }),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Choisissez un plat.';
            }
            return null;
          },
        ),
        if (_isEditing)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Le plat ne peut pas être modifié pour une offre existante.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductChecklist() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${_selectedProductIds.length} plat(s) sélectionné(s)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedProductIds = widget.products
                          .map((product) => product.id)
                          .toSet();
                    }),
                    child: const Text('Tout cocher'),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _selectedProductIds = <String>{}),
                    child: const Text('Tout décocher'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 190,
              child: ListView.builder(
                itemCount: widget.products.length,
                itemBuilder: (context, index) {
                  final product = widget.products[index];
                  return Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                    value: _selectedProductIds.contains(product.id),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selectedProductIds.add(product.id);
                      } else {
                        _selectedProductIds.remove(product.id);
                      }
                    }),
                    title: Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    subtitle: Text(
                      formatAmount(product.price),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    activeColor: AppColors.orange,
                    dense: true,
                  ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllProductsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.greenMist,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, color: AppColors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Toute la boutique',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.products.length} plat(s) commandable(s) recevront '
                  'la même remise. Les plats déjà en promotion sur la période '
                  'seront ignorés.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentField() {
    return AppTextField(
      controller: _discountPercent,
      label: 'Pourcentage de réduction (%)',
      hint: 'Ex. 20',
      icon: Icons.percent,
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Saisissez le pourcentage de réduction.';
        }
        final parsed = int.tryParse(value.trim().replaceAll(',', '.'));
        if (parsed == null || parsed < 1 || parsed > 99) {
          return 'Choisissez un pourcentage entre 1 et 99.';
        }
        return null;
      },
    );
  }

  Widget _buildPriceField() {
    return AppTextField(
      controller: _promoPrice,
      label: 'Prix promo (FCFA)',
      hint: _selectedProduct == null
          ? 'Ex. 7000'
          : 'Ex. ${(_selectedProduct!.price * 0.8).round()}',
      icon: Icons.sell_outlined,
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Saisissez le prix promo.';
        }
        final parsed = int.tryParse(
          value.trim().replaceAll(' ', '').replaceAll(',', '.'),
        );
        if (parsed == null || parsed < 1) {
          return 'Le prix doit être un montant entier positif.';
        }
        final product = _selectedProduct;
        if (product != null && parsed >= product.price) {
          return 'Le prix promo doit être inférieur à ${formatAmount(product.price)}.';
        }
        return null;
      },
    );
  }

  Widget _buildDateTimeTile({
    required String label,
    required DateTime value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.expand_more),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          _formatDateTime(value),
          style: const TextStyle(fontSize: 14, color: AppColors.text),
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final targets = _targetProducts;
    final product = targets.isEmpty ? null : targets.first;
    final price = product == null ? null : promoPriceFor(product);
    final valid = product != null &&
        price != null &&
        price > 0 &&
        price < product.price &&
        _displayedPercent > 0;
    final percent = _displayedPercent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: valid ? AppColors.greenMist : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: valid
              ? AppColors.green.withValues(alpha: 0.25)
              : AppColors.border,
        ),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                valid ? Icons.auto_awesome : Icons.visibility_outlined,
                size: 18,
                color: valid ? AppColors.green : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Aperçu client',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: valid ? AppColors.green : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (valid) ...[
            Text(
              targets.length > 1
                  ? '${product.name} · +${targets.length - 1} autre(s) plat(s)'
                  : product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppDimens.radiusPill),
                    ),
                  ),
                  child: Text(
                    '−$percent %',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  formatAmount(product.price),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textFaint,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  formatAmount(price),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Le client économise ${formatAmount(product.price - price)}.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ] else
            Text(
              _mode == _PromotionMode.percent
                  ? 'Saisissez un pourcentage et sélectionnez les plats pour voir l’aperçu de l’offre.'
                  : 'Renseignez un prix promo inférieur au prix normal pour voir l’aperçu de l’offre.',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year} · '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
