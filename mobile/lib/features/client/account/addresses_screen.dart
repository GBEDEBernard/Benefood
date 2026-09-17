import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/models/address.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Mes adresses (J153) : liste, ajout et sélection au checkout.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key, required this.marketplace, this.selectMode = false});

  final MarketplaceApi marketplace;
  final bool selectMode;

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<Address> _addresses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final addresses = await widget.marketplace.addresses();
      if (mounted) {
        setState(() {
          _addresses = addresses;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openAdd() async {
    final created = await showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _AddAddressSheet(marketplace: widget.marketplace),
    );
    if (created != null && mounted) {
      setState(() => _addresses = [created, ..._addresses]);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse enregistrée'), behavior: SnackBarBehavior.floating),
      );
      if (widget.selectMode) {
        Navigator.of(context).pop(created);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.selectMode ? 'Choisir une adresse' : 'Mes adresses')),
      body: _buildBody(),
      floatingActionButton: widget.selectMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAdd,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Ajouter'),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_addresses.isEmpty) {
      return EmptyState(
        icon: Icons.location_on_outlined,
        title: 'Aucune adresse',
        subtitle: 'Ajoutez une adresse pour vos livraisons.',
        actionLabel: 'Ajouter une adresse',
        onAction: _openAdd,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _addresses.length,
        itemBuilder: (context, index) {
          final address = _addresses[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(address.label ?? 'Adresse'),
              subtitle: Text(_summary(address)),
              trailing: widget.selectMode
                  ? const Icon(Icons.check_circle_outline)
                  : const Icon(Icons.chevron_right),
              onTap: widget.selectMode ? () => Navigator.of(context).pop(address) : _openAdd,
            ),
          );
        },
      ),
    );
  }

  String _summary(Address address) {
    final parts = [
      address.fullAddress,
      address.city,
      if (address.landmark != null) 'près de ${address.landmark}',
    ].whereType<String>().where((p) => p.isNotEmpty).toList();
    return parts.join(' · ');
  }
}

class _AddAddressSheet extends StatefulWidget {
  const _AddAddressSheet({required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    _city.dispose();
    _address.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final address = await widget.marketplace.createAddress(
        label: _label.text.trim(),
        fullAddress: _address.text.trim(),
        city: _city.text.trim(),
        landmark: _landmark.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(address);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nouvelle adresse', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              AppTextField(
                controller: _label,
                label: 'Libellé',
                required: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _address,
                label: 'Adresse complète',
                hint: 'Rue, quartier, repères…',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _city,
                      label: 'Ville',
                      hint: 'Cotonou…',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _landmark,
                      label: 'Point de repère',
                      hint: 'Près de…',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Enregistrer',
                onPressed: _saving ? null : _save,
                loading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}