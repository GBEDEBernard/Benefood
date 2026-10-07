import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Moyens de paiement du client : liste, ajout, défaut, suppression (J153).
///
/// Seules des métadonnées sont saisies (type, établissement, libellé,
/// 4 derniers chiffres) — aucun numéro de carte n'est transmis.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.marketplace.myPaymentMethods();
  }

  void _reload() {
    final next = widget.marketplace.myPaymentMethods();
    setState(() {
      _future = next;
    });
  }

  static IconData _iconFor(String type) => switch (type) {
    'card' => Icons.credit_card,
    'mobile_money' => Icons.smartphone,
    _ => Icons.payments_outlined,
  };

  static String _labelFor(String type) => switch (type) {
    'card' => 'Carte bancaire',
    'mobile_money' => 'Mobile money',
    _ => 'Espèces à la livraison',
  };

  Future<void> _openAddSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      builder: (_) => _AddPaymentMethodSheet(marketplace: widget.marketplace),
    );
    if (added == true) {
      _reload();
      if (mounted) {
        showToast(context, 'Moyen de paiement ajouté');
      }
    }
  }

  Future<void> _makeDefault(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id is! String) {
      return;
    }
    try {
      await widget.marketplace.setDefaultPaymentMethod(id);
      _reload();
      if (mounted) {
        showToast(context, 'Moyen de paiement par défaut mis à jour');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id is! String) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce moyen ?'),
        content: const Text(
          'Ce moyen de paiement sera retiré de votre compte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.marketplace.deletePaymentMethod(id);
      _reload();
      if (mounted) {
        showToast(context, 'Moyen de paiement supprimé');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Méthodes de paiement')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Impossible de charger vos moyens de paiement.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _reload,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.greenLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.credit_card,
                        size: 36,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucun moyen de paiement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ajoutez une carte ou un compte mobile money '
                      'pour payer plus vite.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.pagePadding,
              AppDimens.pagePadding,
              96,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final type = item['type'] is String ? item['type'] as String : '';
              final provider = item['provider'] is String
                  ? item['provider'] as String
                  : '';
              final label = item['label'] is String
                  ? item['label'] as String
                  : '';
              final last4 = item['last4'] is String
                  ? item['last4'] as String
                  : '';
              final isDefault = item['is_default'] == true;

              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  boxShadow: AppTheme.softShadow(),
                ),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      side: isDefault
                          ? const BorderSide(color: AppColors.green, width: 1.5)
                          : BorderSide.none,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDefault
                            ? AppColors.greenLight
                            : AppColors.orangeLight,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusSm + 2,
                        ),
                      ),
                      child: Icon(
                        _iconFor(type),
                        size: 20,
                        color: isDefault ? AppColors.green : AppColors.orange,
                      ),
                    ),
                    title: Text(
                      label.isEmpty ? _labelFor(type) : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      last4.isEmpty ? provider : '$provider •••• $last4',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (action) {
                        if (action == 'default') {
                          _makeDefault(item);
                        } else if (action == 'delete') {
                          _delete(item);
                        }
                      },
                      itemBuilder: (_) => [
                        if (!isDefault)
                          const PopupMenuItem(
                            value: 'default',
                            child: ListTile(
                              leading: Icon(Icons.star_outline),
                              title: Text('Définir par défaut'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(
                              Icons.delete_outline,
                              color: AppColors.red,
                            ),
                            title: Text('Supprimer'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Feuille d'ajout : type, établissement/opérateur, libellé, 4 derniers chiffres.
class _AddPaymentMethodSheet extends StatefulWidget {
  const _AddPaymentMethodSheet({required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<_AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<_AddPaymentMethodSheet> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'mobile_money';
  final _providerController = TextEditingController();
  final _labelController = TextEditingController();
  final _last4Controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _providerController.dispose();
    _labelController.dispose();
    _last4Controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.marketplace.addPaymentMethod(
        type: _type,
        provider: _providerController.text.trim(),
        label: _labelController.text.trim(),
        last4: _type == 'card' ? _last4Controller.text.trim() : null,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimens.pagePadding,
          right: AppDimens.pagePadding,
          top: AppDimens.pagePadding,
          bottom:
              MediaQuery.of(context).viewInsets.bottom + AppDimens.pagePadding,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ajouter un moyen de paiement',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppDimens.lg),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'mobile_money',
                    child: Text('Mobile money'),
                  ),
                  DropdownMenuItem(
                    value: 'card',
                    child: Text('Carte bancaire'),
                  ),
                  DropdownMenuItem(
                    value: 'cash',
                    child: Text('Espèces à la livraison'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _type = value ?? 'mobile_money');
                },
              ),
              const SizedBox(height: AppDimens.lg),
              TextFormField(
                controller: _providerController,
                decoration: InputDecoration(
                  labelText: _type == 'card'
                      ? 'Établissement (ex. Visa)'
                      : 'Opérateur (ex. Moov Money)',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Ce champ est requis.'
                    : null,
              ),
              const SizedBox(height: AppDimens.lg),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Libellé (ex. Ma carte perso)',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Ce champ est requis.'
                    : null,
              ),
              if (_type == 'card') ...[
                const SizedBox(height: AppDimens.lg),
                TextFormField(
                  controller: _last4Controller,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: '4 derniers chiffres',
                    counterText: '',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty || !RegExp(r'^\d{4}$').hasMatch(text)) {
                      return 'Saisissez exactement 4 chiffres.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: AppDimens.sm),
              const Text(
                'Aucun numéro complet n’est stocké : uniquement les '
                '4 derniers chiffres.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimens.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
