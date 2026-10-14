import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/models/parcel.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/favorite_driver_picker.dart';
import '../../../shared/widgets/payment_method_screen.dart';

/// Envoi d'un colis (client ou boutique vendeuse) :
/// adresses → devis → création → paiement.
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
  final _description = TextEditingController();
  final _pickupLabel = TextEditingController();
  final _pickupAddress = TextEditingController();
  final _pickupArea = TextEditingController();
  final _pickupCity = TextEditingController();
  final _pickupLandmark = TextEditingController();
  final _dropoffLabel = TextEditingController();
  final _dropoffAddress = TextEditingController();
  final _dropoffArea = TextEditingController();
  final _dropoffCity = TextEditingController();
  final _dropoffLandmark = TextEditingController();

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
  bool _verifying = false;

  /// Livreur favori visé (optionnel) : l'offre lui sera réservée en priorité.
  String? _favoriteDriverId;
  String? _favoriteDriverName;

  @override
  void dispose() {
    _description.dispose();
    _pickupLabel.dispose();
    _pickupAddress.dispose();
    _pickupArea.dispose();
    _pickupCity.dispose();
    _pickupLandmark.dispose();
    _dropoffLabel.dispose();
    _dropoffAddress.dispose();
    _dropoffArea.dispose();
    _dropoffCity.dispose();
    _dropoffLandmark.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _pickup => {
        if (_pickupLabel.text.trim().isNotEmpty) 'label': _pickupLabel.text.trim(),
        if (_pickupAddress.text.trim().isNotEmpty) 'address_text': _pickupAddress.text.trim(),
        if (_pickupLandmark.text.trim().isNotEmpty) 'landmark': _pickupLandmark.text.trim(),
        if (_pickupArea.text.trim().isNotEmpty) 'area': _pickupArea.text.trim(),
        if (_pickupCity.text.trim().isNotEmpty) 'city': _pickupCity.text.trim(),
        if (_pickupLatitude != null) 'latitude': _pickupLatitude,
        if (_pickupLongitude != null) 'longitude': _pickupLongitude,
      };

  Map<String, dynamic> get _dropoff => {
        if (_dropoffLabel.text.trim().isNotEmpty) 'label': _dropoffLabel.text.trim(),
        if (_dropoffAddress.text.trim().isNotEmpty) 'address_text': _dropoffAddress.text.trim(),
        if (_dropoffLandmark.text.trim().isNotEmpty) 'landmark': _dropoffLandmark.text.trim(),
        if (_dropoffArea.text.trim().isNotEmpty) 'area': _dropoffArea.text.trim(),
        if (_dropoffCity.text.trim().isNotEmpty) 'city': _dropoffCity.text.trim(),
        if (_dropoffLatitude != null) 'latitude': _dropoffLatitude,
        if (_dropoffLongitude != null) 'longitude': _dropoffLongitude,
      };

  bool get _addressesFilled =>
      (_pickupAddress.text.trim().isNotEmpty || _pickupCity.text.trim().isNotEmpty) &&
      (_dropoffAddress.text.trim().isNotEmpty || _dropoffCity.text.trim().isNotEmpty);

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
        if (geo.city != null && city.text.trim().isEmpty) {
          city.text = geo.city!;
        }
        if (geo.area != null) {
          if (address.text.trim().isEmpty) {
            address.text = geo.area!;
          } else if (area.text.trim().isEmpty) {
            area.text = geo.area!;
          }
        }
      }
    });
    if (geo == null) {
      showToast(context, _locationFailureMessage(result.failure), isError: true);
    } else {
      showToast(context, 'Position GPS enregistrée.');
    }
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

  static String _locationFailureMessage(LocationFailure? failure) => switch (failure) {
        LocationFailure.serviceDisabled => 'Localisation indisponible : activez le GPS de votre appareil.',
        LocationFailure.permissionDenied => 'Localisation refusée : autorisez l\'accès à votre position dans les réglages.',
        _ => 'Position introuvable pour le moment. Vérifiez le GPS puis réessayez.',
      };

  Future<void> _estimate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_addressesFilled) {
      showToast(context, 'Renseignez les adresses de ramassage et de livraison.', isError: true);
      return;
    }
    setState(() {
      _quoting = true;
      _quoteError = null;
    });
    try {
      final quote = await widget.marketplace.parcelQuote(pickup: _pickup, dropoff: _dropoff);
      if (mounted) {
        setState(() => _quote = quote);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _quoteError = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _quoting = false);
      }
    }
  }

  Future<void> _create() async {
    final fee = (_quote?['delivery_fee'] as num?)?.toInt() ?? 0;
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
        description: _description.text,
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
      if (mounted) {
        setState(() => _creating = false);
        _showPaymentDialog(parcel, payload);
      }
    } on ApiException {
      if (mounted) {
        setState(() => _creating = false);
        _goToDetail(parcel);
      }
    }
  }

  void _showPaymentDialog(Parcel parcel, Map<String, dynamic> payload) {
    final widgetConfig = payload['widget'];
    if (widgetConfig is! Map<String, dynamic>) {
      _goToDetail(parcel);
      return;
    }

    final key = widgetConfig['key'];
    if (key is! String || key.isEmpty) {
      _goToDetail(parcel);
      return;
    }

    final amount = widgetConfig['amount'];
    final amountValue = amount is num ? '${amount.toInt()}' : '${amount ?? 0}';
    final orderId = widgetConfig['order_id'];
    final callback = widgetConfig['callback'];
    final url = 'https://kkiapay.me/fr/mobilepay/${Uri(queryParameters: {
          'key': key,
          'amount': amountValue,
          'order_id': orderId?.toString() ?? parcel.id,
          if (callback is String) 'callback': callback,
        }).query}';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paiement Kkiapay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Réglez vos frais de livraison via Kkiapay :'),
            const SizedBox(height: 12),
            SelectableText(url, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            IconButton(
              tooltip: 'Copier le lien',
              onPressed: () => Clipboard.setData(ClipboardData(text: url)),
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _goToDetail(parcel);
            },
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _verifyPayment(parcel);
            },
            child: const Text('J\'ai payé'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyPayment(Parcel parcel) async {
    setState(() => _verifying = true);
    try {
      final latest = await widget.marketplace.parcel(parcel.id);
      if (!mounted) {
        return;
      }
      setState(() => _verifying = false);
      _goToDetail(latest);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _verifying = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  /// Base des routes colis de l'espace courant.
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
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_verifying) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(AppDimens.pagePadding),
      children: [
        _addressSection(
          title: 'Adresse de ramassage',
          icon: Icons.trip_origin,
          color: AppColors.green,
          backgroundColor: AppColors.greenLight,
          label: _pickupLabel,
          labelHint: 'Ex : Boutique, domicile…',
          address: _pickupAddress,
          area: _pickupArea,
          city: _pickupCity,
          landmark: _pickupLandmark,
          latitude: _pickupLatitude,
          longitude: _pickupLongitude,
          locating: _pickupLocating,
          onLocate: () => _locate(pickup: true),
          onClear: () => _clearLocation(pickup: true),
        ),
        const SizedBox(height: AppDimens.xl),
        _addressSection(
          title: 'Adresse de livraison',
          icon: Icons.place,
          color: AppColors.orange,
          backgroundColor: AppColors.orangeLight,
          label: _dropoffLabel,
          labelHint: 'Ex : Bureau, domicile du destinataire…',
          address: _dropoffAddress,
          area: _dropoffArea,
          city: _dropoffCity,
          landmark: _dropoffLandmark,
          latitude: _dropoffLatitude,
          longitude: _dropoffLongitude,
          locating: _dropoffLocating,
          onLocate: () => _locate(pickup: false),
          onClear: () => _clearLocation(pickup: false),
        ),
        const SizedBox(height: AppDimens.xl),
        _SectionTitle(
          icon: Icons.notes_outlined,
          title: 'Détails du colis',
          color: AppColors.orange,
          backgroundColor: AppColors.orangeLight,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _description,
          label: 'Description',
          hint: 'Ex : Document, colis fragile, taille… (optionnel)',
          icon: Icons.description_outlined,
          maxLines: 3,
        ),
        const SizedBox(height: AppDimens.xl),
        _SectionTitle(
          icon: Icons.delivery_dining_outlined,
          title: 'Livreur favori (optionnel)',
          color: AppColors.green,
          backgroundColor: AppColors.greenLight,
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: _pickFavoriteDriver,
            leading: const Icon(Icons.delivery_dining_outlined, color: AppColors.green),
            title: Text(_favoriteDriverName ?? 'Aucun livreur'),
            subtitle: Text(
              _favoriteDriverName == null
                  ? 'L\'offre sera visible par tous les livreurs disponibles'
                  : 'Ce livreur recevra l\'offre en priorité',
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(height: AppDimens.xl),
        if (_quoteError != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            margin: const EdgeInsets.only(bottom: AppDimens.md),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Devis indisponible : $_quoteError',
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ),
        if (_quote != null) ..._buildQuote(_quote!),
        const SizedBox(height: AppDimens.lg),
        if (_quote != null)
          AppButton(
            label: 'Créer et payer',
            icon: Icons.payment,
            onPressed: _creating ? null : _create,
            loading: _creating,
          )
        else
          AppButton(
            label: 'Estimer le tarif',
            icon: Icons.calculate_outlined,
            onPressed: _quoting ? null : _estimate,
            loading: _quoting,
          ),
        const SizedBox(height: AppDimens.xl),
      ],
    );
  }

  Widget _addressSection({
    required String title,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required TextEditingController label,
    required String labelHint,
    required TextEditingController address,
    required TextEditingController area,
    required TextEditingController city,
    required TextEditingController landmark,
    required double? latitude,
    required double? longitude,
    required bool locating,
    required VoidCallback onLocate,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: icon, title: title, color: color, backgroundColor: backgroundColor),
        const SizedBox(height: 12),
        AppTextField(controller: label, label: 'Libellé', hint: labelHint, icon: Icons.label_outline),
        const SizedBox(height: AppDimens.sm),
        AppTextField(controller: address, label: 'Adresse *', hint: 'Rue, quartier, repère…', icon: Icons.place_outlined),
        const SizedBox(height: AppDimens.sm),
        Row(
          children: [
            Expanded(child: AppTextField(controller: area, label: 'Quartier', icon: Icons.location_city_outlined)),
            const SizedBox(width: AppDimens.sm),
            Expanded(child: AppTextField(controller: city, label: 'Ville', icon: Icons.map_outlined)),
          ],
        ),
        const SizedBox(height: AppDimens.sm),
        AppTextField(
          controller: landmark,
          label: 'Point de repère',
          hint: 'Ex : en face de la pharmacie…',
          icon: Icons.push_pin_outlined,
        ),
        const SizedBox(height: AppDimens.md),
        _locationControl(
          latitude: latitude,
          longitude: longitude,
          locating: locating,
          onLocate: onLocate,
          onClear: onClear,
        ),
      ],
    );
  }

  Widget _locationControl({
    required double? latitude,
    required double? longitude,
    required bool locating,
    required VoidCallback onLocate,
    required VoidCallback onClear,
  }) {
    final captured = latitude != null && longitude != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: locating ? null : onLocate,
          icon: locating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location, size: 18),
          label: Text(locating ? 'Localisation…' : captured ? 'Repositionner (GPS)' : 'Utiliser ma position (GPS)'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
        ),
        if (captured) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location, size: 16, color: AppColors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Position GPS : ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Retirer', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildQuote(Map<String, dynamic> quote) {
    final distance = quote['distance_km'];
    final deliveryFee = (quote['delivery_fee'] as num?)?.toInt() ?? 0;

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                distance is num ? 'Distance estimée : ${distance.toStringAsFixed(1)} km' : 'Distance estimée : —',
                style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const Divider(height: AppDimens.xl),
              _QuoteRow(label: 'Frais de livraison', amount: deliveryFee, emphasized: true),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.green),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Le paiement en ligne libère aussitôt le colis pour les livreurs.',
                        style: TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ],
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({required this.label, required this.amount, this.emphasized = false});

  final String label;
  final int amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          AmountText(amount, style: style),
        ],
      ),
    );
  }
}