import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/address.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback_widgets.dart';
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
      showToast(context, 'Adresse enregistrée');
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: address.isDefault ? AppColors.green.withValues(alpha: 0.5) : Colors.transparent, width: 1.2),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.selectMode
                  ? () => Navigator.of(context).pop(address)
                  : _openAdd,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: address.isDefault ? AppColors.greenLight : const Color(0xFFF0F2F4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_on_outlined,
                        color: address.isDefault ? AppColors.green : AppColors.textSecondary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  address.label ?? 'Adresse',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                ),
                              ),
                              if (address.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2E7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Par défaut',
                                    style: TextStyle(fontSize: 10.5, color: AppColors.orange, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _summary(address),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      widget.selectMode ? Icons.check_circle_outline : Icons.chevron_right,
                      color: widget.selectMode ? AppColors.green : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
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
  final _area = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  bool _saving = false;
  bool _locating = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _label.dispose();
    _city.dispose();
    _area.dispose();
    _address.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _useMyPosition() async {
    setState(() => _locating = true);
    final result = await LocationService.locate();
    if (!mounted) {
      return;
    }
    final geo = result.geo;
    setState(() {
      _locating = false;
      if (geo != null) {
        _latitude = geo.latitude;
        _longitude = geo.longitude;
        if (geo.city != null && _city.text.trim().isEmpty) {
          _city.text = geo.city!;
        }
        if (geo.area != null) {
          if (_address.text.trim().isEmpty) {
            _address.text = geo.area!;
          } else if (_area.text.trim().isEmpty) {
            _area.text = geo.area!;
          }
        }
      }
    });
    if (geo == null) {
      showToast(context, _locationFailureMessage(result.failure), isError: true);
    }
  }

  static String _locationFailureMessage(LocationFailure? failure) => switch (failure) {
        LocationFailure.serviceDisabled => 'Localisation indisponible : activez le GPS de votre appareil.',
        LocationFailure.permissionDenied => 'Localisation refusée : autorisez l\'accès à votre position dans les réglages.',
        _ => 'Position introuvable pour le moment. Vérifiez le GPS puis réessayez.',
      };

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
        area: _area.text.trim(),
        landmark: _landmark.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      );
      if (mounted) {
        Navigator.of(context).pop(address);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nouvelle adresse', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: _locating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                    label: const Text('Utiliser ma position'),
                    onPressed: _locating ? null : _useMyPosition,
                  ),
                  if (_latitude != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Position capturée (${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)})',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Votre position est utilisée uniquement pour pré-remplir cette adresse.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
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
                    required: true,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
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
                          controller: _area,
                          label: 'Quartier',
                          hint: 'Akpakpa…',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _landmark,
                    label: 'Point de repère',
                    hint: 'Près de…',
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
        ),
      ),
    );
  }
}