import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/parcel.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/city_area_picker.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/favorite_driver_picker.dart';
import '../../../shared/widgets/fedapay_checkout_screen.dart';
import '../../../shared/widgets/map_picker.dart';
import '../../../shared/widgets/payment_method_screen.dart';

/// Envoi d'un colis (client ou boutique vendeuse) en trois étapes :
/// adresses → détails du colis → confirmation et paiement.
class ParcelCreateScreen extends StatefulWidget {
  const ParcelCreateScreen({
    super.key,
    required this.marketplace,
    this.audience = NotificationAudience.client,
  });

  final MarketplaceApi marketplace;

  /// Espace d'envoi : client ou boutique vendeuse.
  final NotificationAudience audience;

  @override
  State<ParcelCreateScreen> createState() => _ParcelCreateScreenState();
}

class _ParcelCreateScreenState extends State<ParcelCreateScreen> {
  static const _parcelTypes = <String>[
    'Documents',
    'Produits alimentaires',
    'Vêtements',
    'Accessoires',
    'Colis fragile',
    'Autre',
  ];

  final _description = TextEditingController();
  final _instructions = TextEditingController();
  final _weight = TextEditingController();
  final _pickupLabel = TextEditingController();
  final _pickupAddress = TextEditingController();
  final _pickupArea = TextEditingController();
  final _pickupCity = TextEditingController();
  final _pickupLandmark = TextEditingController();
  final _pickupContactName = TextEditingController();
  final _pickupContactPhone = TextEditingController();
  final _dropoffLabel = TextEditingController();
  final _dropoffAddress = TextEditingController();
  final _dropoffArea = TextEditingController();
  final _dropoffCity = TextEditingController();
  final _dropoffLandmark = TextEditingController();
  final _dropoffContactName = TextEditingController();
  final _dropoffContactPhone = TextEditingController();

  int _step = 0;
  bool _sameAsPickup = false;
  String? _parcelType;

  double? _pickupLatitude;
  double? _pickupLongitude;
  double? _dropoffLatitude;
  double? _dropoffLongitude;
  bool _pickupLocating = false;
  bool _dropoffLocating = false;

  Map<String, dynamic>? _quote;
  bool _quoting = false;
  String? _quoteError;

  bool _creating = false;

  String? _favoriteDriverId;
  String? _favoriteDriverName;

  @override
  void dispose() {
    _description.dispose();
    _instructions.dispose();
    _weight.dispose();
    _pickupLabel.dispose();
    _pickupAddress.dispose();
    _pickupArea.dispose();
    _pickupCity.dispose();
    _pickupLandmark.dispose();
    _pickupContactName.dispose();
    _pickupContactPhone.dispose();
    _dropoffLabel.dispose();
    _dropoffAddress.dispose();
    _dropoffArea.dispose();
    _dropoffCity.dispose();
    _dropoffLandmark.dispose();
    _dropoffContactName.dispose();
    _dropoffContactPhone.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _pickup => {
    if (_pickupLabel.text.trim().isNotEmpty) 'label': _pickupLabel.text.trim(),
    if (_pickupAddress.text.trim().isNotEmpty)
      'address_text': _pickupAddress.text.trim(),
    if (_pickupLandmark.text.trim().isNotEmpty)
      'landmark': _pickupLandmark.text.trim(),
    if (_pickupArea.text.trim().isNotEmpty) 'area': _pickupArea.text.trim(),
    if (_pickupCity.text.trim().isNotEmpty) 'city': _pickupCity.text.trim(),
    if (_pickupLatitude != null) 'latitude': _pickupLatitude,
    if (_pickupLongitude != null) 'longitude': _pickupLongitude,
    if (_pickupContactName.text.trim().isNotEmpty)
      'contact_name': _pickupContactName.text.trim(),
    if (_pickupContactPhone.text.trim().isNotEmpty)
      'contact_phone': _pickupContactPhone.text.trim(),
  };

  Map<String, dynamic> get _dropoff {
    if (_sameAsPickup) {
      return _pickup;
    }
    return {
      if (_dropoffLabel.text.trim().isNotEmpty)
        'label': _dropoffLabel.text.trim(),
      if (_dropoffAddress.text.trim().isNotEmpty)
        'address_text': _dropoffAddress.text.trim(),
      if (_dropoffLandmark.text.trim().isNotEmpty)
        'landmark': _dropoffLandmark.text.trim(),
      if (_dropoffArea.text.trim().isNotEmpty) 'area': _dropoffArea.text.trim(),
      if (_dropoffCity.text.trim().isNotEmpty) 'city': _dropoffCity.text.trim(),
      if (_dropoffLatitude != null) 'latitude': _dropoffLatitude,
      if (_dropoffLongitude != null) 'longitude': _dropoffLongitude,
      if (_dropoffContactName.text.trim().isNotEmpty)
        'contact_name': _dropoffContactName.text.trim(),
      if (_dropoffContactPhone.text.trim().isNotEmpty)
        'contact_phone': _dropoffContactPhone.text.trim(),
    };
  }

  /// Description transmise à l'API : description libre enrichie du type, du
  /// poids et des consignes (aucun champ backend supplémentaire n'existe).
  String get _composedDescription {
    final parts = <String>[];
    final description = _description.text.trim();
    if (description.isNotEmpty) {
      parts.add(description);
    }
    if (_parcelType != null) {
      parts.add('Type : $_parcelType');
    }
    final weight = _weight.text.trim();
    if (weight.isNotEmpty) {
      parts.add('Poids estimé : $weight kg');
    }
    final instructions = _instructions.text.trim();
    if (instructions.isNotEmpty) {
      parts.add('Instructions : $instructions');
    }
    return parts.join('\n');
  }

  bool get _pickupAddressOk => _pickupAddress.text.trim().isNotEmpty;

  bool get _dropoffAddressOk =>
      _sameAsPickup || _dropoffAddress.text.trim().isNotEmpty;

  bool get _addressesFilled => _pickupAddressOk && _dropoffAddressOk;

  Future<void> _locate({required bool pickup}) async {
    setState(() {
      if (pickup) {
        _pickupLocating = true;
      } else {
        _dropoffLocating = true;
      }
    });
    final result = await LocationService.locate();
    if (!mounted) {
      return;
    }
    final geo = result.geo;
    setState(() {
      if (pickup) {
        _pickupLocating = false;
      } else {
        _dropoffLocating = false;
      }
      if (geo != null) {
        final address = pickup ? _pickupAddress : _dropoffAddress;
        final area = pickup ? _pickupArea : _dropoffArea;
        final city = pickup ? _pickupCity : _dropoffCity;
        if (pickup) {
          _pickupLatitude = geo.latitude;
          _pickupLongitude = geo.longitude;
        } else {
          _dropoffLatitude = geo.latitude;
          _dropoffLongitude = geo.longitude;
        }
        if (city.text.trim().isEmpty && geo.city != null) {
          city.text = geo.city!;
        }
        if (geo.area != null) {
          if (address.text.trim().isEmpty) {
            address.text = geo.area!;
          } else if (address == _dropoffAddress && _sameAsPickup) {
            _sameAsPickup = false;
          }
          if (area.text.trim().isEmpty) {
            area.text = geo.area!;
          }
        }
      }
    });
    if (geo == null) {
      if (mounted) {
        showToast(
          context,
          _locationFailureMessage(result.failure),
          isError: true,
        );
      }
      return;
    }
    showToast(context, 'Position GPS enregistrée.');
  }

  void _clearLocation({required bool pickup}) {
    setState(() {
      if (pickup) {
        _pickupLatitude = null;
        _pickupLongitude = null;
      } else {
        _dropoffLatitude = null;
        _dropoffLongitude = null;
      }
    });
  }

  static String _locationFailureMessage(
    LocationFailure? failure,
  ) => switch (failure) {
    LocationFailure.serviceDisabled =>
      'Localisation indisponible : activez le GPS de votre appareil.',
    LocationFailure.permissionDenied =>
      'Localisation refusée : autorisez l\'accès à votre position dans les réglages.',
    _ => 'Position introuvable pour le moment. Vérifiez le GPS puis réessayez.',
  };

  void _goNext() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_step == 0) {
      if (!_pickupAddressOk) {
        showToast(
          context,
          'Renseignez l\'adresse de ramassage.',
          isError: true,
        );
        return;
      }
      if (!_dropoffAddressOk) {
        showToast(
          context,
          'Renseignez l\'adresse de livraison ou cochez « Identique au ramassage ».',
          isError: true,
        );
        return;
      }
      if (_pickupLatitude == null || _pickupLongitude == null) {
        showToast(
          context,
          'Placez le repère de ramassage sur la carte.',
          isError: true,
        );
        return;
      }
      if (!_sameAsPickup &&
          (_dropoffLatitude == null || _dropoffLongitude == null)) {
        showToast(
          context,
          'Placez le repère de livraison sur la carte.',
          isError: true,
        );
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      setState(() => _step = 2);
      _estimate();
      return;
    }
    _create();
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step -= 1);
    }
  }

  void _jumpTo(int step) {
    if (step < _step) {
      setState(() => _step = step);
    }
  }

  Future<void> _estimate() async {
    if (!_addressesFilled) {
      setState(
        () => _quoteError =
            'Renseignez les adresses de ramassage et de livraison.',
      );
      return;
    }
    setState(() {
      _quoting = true;
      _quoteError = null;
    });
    try {
      final quote = await widget.marketplace.parcelQuote(
        pickup: _pickup,
        dropoff: _dropoff,
      );
      if (mounted) {
        setState(() {
          _quote = quote;
          _quoting = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _quoteError = e.message;
          _quoting = false;
        });
      }
    }
  }

  Future<void> _create() async {
    final quote = _quote;
    final fee =
        (quote?['total_amount'] as num?)?.toInt() ??
        ((quote?['delivery_fee'] as num?)?.toInt() ?? 0) +
            ((quote?['creation_fee'] as num?)?.toInt() ?? 0);
    final method = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ParcelPaymentMethodScreen(
          marketplace: widget.marketplace,
          amount: fee,
          audience: widget.audience,
        ),
      ),
    );
    if (method == null || !mounted) {
      return;
    }
    await _submit(method);
  }

  Future<void> _submit(String paymentMethod) async {
    setState(() => _creating = true);
    try {
      final parcel = await widget.marketplace.createParcel(
        pickup: _pickup,
        dropoff: _dropoff,
        description: _composedDescription,
        favoriteDriverId: _favoriteDriverId,
        paymentMethod: paymentMethod,
      );
      if (!mounted) {
        return;
      }
      setState(() => _creating = false);
      if (paymentMethod == 'cash') {
        showToast(context, 'Colis créé — paiement en espèces à la livraison');
        _goToDetail(parcel);
      } else {
        await _startPayment(parcel);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _pickFavoriteDriver() async {
    final choice = await showFavoriteDriverPicker(
      context,
      widget.marketplace,
      title: 'Livreur favori (optionnel)',
      selectedId: _favoriteDriverId,
    );
    if (choice == null || !mounted) {
      return;
    }
    setState(() {
      _favoriteDriverId = choice.driverId;
      _favoriteDriverName = choice.isNone ? null : choice.label;
    });
  }

  Future<void> _startPayment(Parcel parcel) async {
    if (parcel.isDelivered || parcel.isCancelled) {
      _goToDetail(parcel);
      return;
    }

    setState(() => _creating = true);
    try {
      final payload = await widget.marketplace.createParcelPayment(parcel.id);
      if (!mounted) {
        return;
      }
      setState(() => _creating = false);

      final checkoutUrl = payload['checkout_url'];
      if (checkoutUrl is String && checkoutUrl.isNotEmpty) {
        await startFedaPayCheckout(
          context,
          marketplace: widget.marketplace,
          checkoutUrl: checkoutUrl,
          transactionId: payload['transaction_id']?.toString(),
        );
      } else {
        final message = payload['message']?.toString();
        if (message != null && message.isNotEmpty && mounted) {
          showToast(context, message, isError: false);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        showToast(context, e.message, isError: true);
      }
    }

    if (!mounted) {
      return;
    }
    _goToDetail(await _refreshParcel(parcel));
  }

  Future<Parcel> _refreshParcel(Parcel parcel) async {
    try {
      return await widget.marketplace.parcel(parcel.id);
    } on ApiException {
      return parcel;
    }
  }

  String get _basePath => widget.audience == NotificationAudience.vendor
      ? '/vendor/parcels'
      : '/client/parcels';

  void _goToDetail(Parcel parcel) {
    context.pushReplacement('$_basePath/${parcel.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BeninfoodAppBar(
            onMenu: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(_basePath);
              }
            },
            api: widget.marketplace,
            audience: widget.audience,
          ),
          Expanded(child: _buildBody()),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.md,
        AppDimens.pagePadding,
        AppDimens.xl,
      ),
      children: [
        const Text(
          'Créer un colis',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Renseignez les adresses et les détails du colis.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppDimens.lg),
        _StepIndicator(current: _step, onStepTap: _jumpTo),
        const SizedBox(height: AppDimens.xl),
        ...switch (_step) {
          0 => _addressStep(),
          1 => _detailsStep(),
          _ => _confirmationStep(),
        },
      ],
    );
  }

  List<Widget> _addressStep() {
    return [
      _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.trip_origin,
              title: 'Adresse de ramassage',
              color: AppColors.orange,
              background: AppColors.orangeLight,
              trailing: _LocateChip(
                loading: _pickupLocating,
                onPressed: () => _locate(pickup: true),
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            AppTextField(
              controller: _pickupLabel,
              label: 'Libellé',
              hint: 'Ex : Boutique, domicile…',
              icon: Icons.label_outline,
            ),
            const SizedBox(height: AppDimens.md),
            AppTextField(
              controller: _pickupAddress,
              label: 'Adresse',
              hint: 'Rue, quartier, repère…',
              icon: Icons.place_outlined,
              required: true,
            ),
            const SizedBox(height: AppDimens.md),
            CityAreaPickerField(
              marketplace: widget.marketplace,
              cityController: _pickupCity,
              areaController: _pickupArea,
            ),
            const SizedBox(height: AppDimens.md),
            AppTextField(
              controller: _pickupContactName,
              label: 'Contact sur place',
              hint: 'Nom de la personne à joindre',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: AppDimens.md),
            AppTextField(
              controller: _pickupContactPhone,
              label: 'Téléphone du contact',
              hint: '+229…',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppDimens.md),
            AppTextField(
              controller: _pickupLandmark,
              label: 'Point de repère',
              hint: 'Ex : en face de la pharmacie…',
              icon: Icons.push_pin_outlined,
            ),
            const SizedBox(height: AppDimens.md),
            MapPicker(
              point: _pickupLatitude != null && _pickupLongitude != null
                  ? LatLng(_pickupLatitude!, _pickupLongitude!)
                  : null,
              height: 190,
              instruction: 'Touchez la carte pour placer le ramassage',
              onChanged: (point) {
                setState(() {
                  _pickupLatitude = point.latitude;
                  _pickupLongitude = point.longitude;
                });
              },
            ),
            _gpsStrip(
              latitude: _pickupLatitude,
              longitude: _pickupLongitude,
              onClear: () => _clearLocation(pickup: true),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppDimens.lg),
      _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.place,
              title: 'Adresse de livraison',
              color: AppColors.orange,
              background: AppColors.orangeLight,
              trailing: _sameAsPickup
                  ? null
                  : _LocateChip(
                      loading: _dropoffLocating,
                      onPressed: () => _locate(pickup: false),
                    ),
            ),
            const SizedBox(height: AppDimens.sm),
            _SameAddressToggle(
              value: _sameAsPickup,
              onChanged: (value) => setState(() => _sameAsPickup = value),
            ),
            const SizedBox(height: AppDimens.sm),
            if (_sameAsPickup)
              _SameAddressStrip()
            else ...[
              AppTextField(
                controller: _dropoffLabel,
                label: 'Libellé',
                hint: 'Ex : Bureau, domicile du destinataire…',
                icon: Icons.label_outline,
              ),
              const SizedBox(height: AppDimens.md),
              AppTextField(
                controller: _dropoffAddress,
                label: 'Adresse',
                hint: 'Rue, quartier, repère…',
                icon: Icons.place_outlined,
                required: true,
              ),
              const SizedBox(height: AppDimens.md),
              CityAreaPickerField(
                marketplace: widget.marketplace,
                cityController: _dropoffCity,
                areaController: _dropoffArea,
              ),
              const SizedBox(height: AppDimens.md),
              AppTextField(
                controller: _dropoffContactName,
                label: 'Nom du destinataire',
                hint: 'Personne à contacter à l\'arrivée',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: AppDimens.md),
              AppTextField(
                controller: _dropoffContactPhone,
                label: 'Téléphone du destinataire',
                hint: '+229…',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppDimens.md),
              AppTextField(
                controller: _dropoffLandmark,
                label: 'Point de repère',
                hint: 'Ex : derrière le marché…',
                icon: Icons.push_pin_outlined,
              ),
              const SizedBox(height: AppDimens.md),
              MapPicker(
                point: _dropoffLatitude != null && _dropoffLongitude != null
                    ? LatLng(_dropoffLatitude!, _dropoffLongitude!)
                    : null,
                height: 190,
                instruction: 'Touchez la carte pour placer la livraison',
                onChanged: (point) {
                  setState(() {
                    _dropoffLatitude = point.latitude;
                    _dropoffLongitude = point.longitude;
                  });
                },
              ),
              _gpsStrip(
                latitude: _dropoffLatitude,
                longitude: _dropoffLongitude,
                onClear: () => _clearLocation(pickup: false),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _detailsStep() {
    return [
      _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.inventory_2_outlined,
              title: 'Détails du colis',
              color: AppColors.orange,
              background: AppColors.orangeLight,
            ),
            const SizedBox(height: AppDimens.lg),
            AppTextField(
              controller: _description,
              label: 'Description du colis',
              hint: 'Ex : sac de vêtements, documents…',
              icon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: AppDimens.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _parcelType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Type de colis',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    hint: const Text('Sélectionner'),
                    items: _parcelTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _parcelType = value),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    controller: _weight,
                    label: 'Poids (kg)',
                    hint: 'Ex : 2',
                    icon: Icons.monitor_weight_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            AppTextField(
              controller: _instructions,
              label: 'Instructions au livreur',
              hint: 'Ex : appeler à l\'arrivée, remettre au gardien…',
              icon: Icons.chat_bubble_outline,
              maxLines: 2,
            ),
            const SizedBox(height: AppDimens.lg),
            const _InfoBanner(),
          ],
        ),
      ),
      const SizedBox(height: AppDimens.lg),
      _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.delivery_dining_outlined,
              title: 'Livreur favori',
              color: AppColors.green,
              background: AppColors.greenLight,
            ),
            const SizedBox(height: AppDimens.md),
            InkWell(
              onTap: _pickFavoriteDriver,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _favoriteDriverName == null
                            ? AppColors.surfaceVariant
                            : AppColors.greenLight,
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      child: Icon(
                        _favoriteDriverName == null
                            ? Icons.public
                            : Icons.delivery_dining,
                        size: 20,
                        color: _favoriteDriverName == null
                            ? AppColors.textSecondary
                            : AppColors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _favoriteDriverName ?? 'Aucun livreur (optionnel)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _favoriteDriverName == null
                                ? 'L\'offre sera visible par tous les livreurs disponibles'
                                : 'Ce livreur recevra l\'offre en priorité',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _confirmationStep() {
    return [
      _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.receipt_long_outlined,
              title: 'Votre colis',
              color: AppColors.green,
              background: AppColors.greenLight,
            ),
            const SizedBox(height: AppDimens.lg),
            _SummaryRow(
              icon: Icons.trip_origin,
              color: AppColors.green,
              label: 'Ramassage',
              value: _formatAddress(_pickup),
            ),
            const Divider(height: AppDimens.xl),
            _SummaryRow(
              icon: Icons.place,
              color: AppColors.orange,
              label: 'Livraison',
              value: _formatAddress(_dropoff),
            ),
            if (_composedDescription.trim().isNotEmpty) ...[
              const Divider(height: AppDimens.xl),
              _SummaryRow(
                icon: Icons.inventory_2_outlined,
                color: AppColors.orange,
                label: 'Détails',
                value: _composedDescription.trim(),
              ),
            ],
            if (_favoriteDriverName != null) ...[
              const Divider(height: AppDimens.xl),
              _SummaryRow(
                icon: Icons.delivery_dining_outlined,
                color: AppColors.green,
                label: 'Livreur favori',
                value: _favoriteDriverName!,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppDimens.lg),
      if (_quoteError != null)
        _QuoteErrorCard(
          message: _quoteError!,
          onRetry: _estimate,
          loading: _quoting,
        )
      else if (_quote != null)
        _QuoteCard(quote: _quote!)
      else
        const _QuoteLoadingCard(),
    ];
  }

  String _formatAddress(Map<String, dynamic> address) {
    final parts = [
      if (address['label'] is String) address['label'] as String,
      if (address['address_text'] is String) address['address_text'] as String,
    ].where((part) => part.trim().isNotEmpty).toList();
    final locality = [
      if (address['area'] is String) address['area'] as String,
      if (address['city'] is String) address['city'] as String,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    if (locality.isNotEmpty) {
      parts.add(locality);
    }
    return parts.isEmpty ? '—' : parts.join('\n');
  }

  Widget _gpsStrip({
    required double? latitude,
    required double? longitude,
    required VoidCallback onClear,
  }) {
    if (latitude == null || longitude == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.orangeLight,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Row(
          children: [
            const Icon(Icons.my_location, size: 16, color: AppColors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Position GPS : ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.orangeDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Retirer',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            AppDimens.md,
            AppDimens.pagePadding,
            AppDimens.md,
          ),
          child: Row(
            children: [
              if (_step > 0) ...[
                SizedBox(
                  width: 56,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _creating ? null : _goBack,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Icon(Icons.arrow_back),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
              ],
              Expanded(
                child: _PrimaryActionButton(
                  label: _step == 2 ? 'Créer et payer' : 'Continuer',
                  icon: _step == 2 ? Icons.payment : Icons.arrow_forward,
                  loading: _creating || (_step == 2 && _quoting),
                  onPressed: _step == 2 && _quote == null ? null : _goNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocateChip extends StatelessWidget {
  const _LocateChip({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location, size: 16),
      label: const Text('Ma position'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.green,
        side: const BorderSide(color: AppColors.greenLight, width: 1.4),
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, this.onStepTap});

  final int current;
  final ValueChanged<int>? onStepTap;

  static const _labels = ['Adresses', 'Colis', 'Confirmation'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < _labels.length; index++)
          Expanded(
            child: GestureDetector(
              onTap: onStepTap == null ? null : () => onStepTap!(index),
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _segment(
                          active: index <= current,
                          visible: index != 0,
                        ),
                      ),
                      _StepDot(
                        number: index + 1,
                        active: index <= current,
                        completed: index < current,
                      ),
                      Expanded(
                        child: _segment(
                          active: index < current,
                          visible: index != _labels.length - 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _labels[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: index == current
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: index <= current
                          ? AppColors.green
                          : AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _segment({required bool active, required bool visible}) => Container(
    height: 2,
    color: !visible
        ? Colors.transparent
        : (active ? AppColors.green : AppColors.border),
  );
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.number,
    required this.active,
    required this.completed,
  });

  final int number;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.green : AppColors.surfaceVariant;
    final fg = active ? Colors.white : AppColors.textFaint;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? AppColors.green : AppColors.border,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: completed
          ? Icon(Icons.check_rounded, size: 16, color: fg)
          : Text(
              '$number',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
    );
  }
}

class _SameAddressToggle extends StatelessWidget {
  const _SameAddressToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (value) => onChanged(value ?? false),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Identique à l\'adresse de ramassage',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SameAddressStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: AppColors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'La livraison utilisera l\'adresse de ramassage.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow(),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    required this.background,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color background;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.text,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                children: [
                  const SizedBox(width: 22),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(icon, size: 22),
                ],
              ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: const Icon(
              Icons.delivery_dining,
              color: AppColors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: AppDimens.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimation de livraison',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  'Les frais seront calculés après validation des adresses.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.info_outline, size: 18, color: AppColors.orange),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuoteLine extends StatelessWidget {
  const _QuoteLine({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        AmountText(
          amount,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});

  final Map<String, dynamic> quote;

  @override
  Widget build(BuildContext context) {
    final distance = quote['distance_km'];
    final fee = (quote['delivery_fee'] as num?)?.toInt() ?? 0;
    final creationFee = (quote['creation_fee'] as num?)?.toInt() ?? 0;
    final total = (quote['total_amount'] as num?)?.toInt() ?? fee + creationFee;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.local_shipping_outlined,
            title: 'Frais du colis',
            color: AppColors.green,
            background: AppColors.greenLight,
          ),
          const SizedBox(height: AppDimens.lg),
          if (distance is num)
            Text(
              'Distance estimée : ${distance.toStringAsFixed(1)} km',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: AppDimens.md),
          _QuoteLine(label: 'Frais de livraison', amount: fee),
          if (creationFee > 0) ...[
            const SizedBox(height: 8),
            _QuoteLine(label: 'Frais de création', amount: creationFee),
          ],
          const SizedBox(height: AppDimens.md),
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: AppColors.orangeLight,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total à payer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                AmountText(
                  total,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.orangeDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le paiement en ligne libère aussitôt le colis pour les livreurs.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteLoadingCard extends StatelessWidget {
  const _QuoteLoadingCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: AppDimens.md),
          Expanded(
            child: Text(
              'Calcul des frais de livraison…',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteErrorCard extends StatelessWidget {
  const _QuoteErrorCard({
    required this.message,
    required this.onRetry,
    this.loading = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.red),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Devis indisponible',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.md),
          OutlinedButton.icon(
            onPressed: loading ? null : onRetry,
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
