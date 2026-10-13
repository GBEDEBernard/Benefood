import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/models/parcel.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/feedback_widgets.dart';

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
  final _dropoffLabel = TextEditingController();
  final _dropoffAddress = TextEditingController();
  final _dropoffArea = TextEditingController();
  final _dropoffCity = TextEditingController();

  Map<String, dynamic>? _quote;
  bool _quoting = false;
  String? _quoteError;

  bool _creating = false;
  bool _verifying = false;

  @override
  void dispose() {
    _description.dispose();
    _pickupLabel.dispose();
    _pickupAddress.dispose();
    _pickupArea.dispose();
    _pickupCity.dispose();
    _dropoffLabel.dispose();
    _dropoffAddress.dispose();
    _dropoffArea.dispose();
    _dropoffCity.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _pickup => {
        if (_pickupLabel.text.trim().isNotEmpty) 'label': _pickupLabel.text.trim(),
        if (_pickupAddress.text.trim().isNotEmpty) 'address_text': _pickupAddress.text.trim(),
        if (_pickupArea.text.trim().isNotEmpty) 'area': _pickupArea.text.trim(),
        if (_pickupCity.text.trim().isNotEmpty) 'city': _pickupCity.text.trim(),
      };

  Map<String, dynamic> get _dropoff => {
        if (_dropoffLabel.text.trim().isNotEmpty) 'label': _dropoffLabel.text.trim(),
        if (_dropoffAddress.text.trim().isNotEmpty) 'address_text': _dropoffAddress.text.trim(),
        if (_dropoffArea.text.trim().isNotEmpty) 'area': _dropoffArea.text.trim(),
        if (_dropoffCity.text.trim().isNotEmpty) 'city': _dropoffCity.text.trim(),
      };

  bool get _addressesFilled =>
      (_pickupAddress.text.trim().isNotEmpty || _pickupCity.text.trim().isNotEmpty) &&
      (_dropoffAddress.text.trim().isNotEmpty || _dropoffCity.text.trim().isNotEmpty);

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
    setState(() => _creating = true);
    try {
      final parcel = await widget.marketplace.createParcel(
        pickup: _pickup,
        dropoff: _dropoff,
        description: _description.text,
      );
      if (!mounted) {
        return;
      }
      setState(() => _creating = false);
      await _startPayment(parcel);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        showToast(context, e.message, isError: true);
      }
    }
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
        _SectionTitle(
          icon: Icons.trip_origin,
          title: 'Adresse de ramassage',
          color: AppColors.green,
          backgroundColor: AppColors.greenLight,
        ),
        const SizedBox(height: 12),
        AppTextField(controller: _pickupLabel, label: 'Libellé', hint: 'Ex : Boutique, domicile…', icon: Icons.label_outline),
        const SizedBox(height: AppDimens.sm),
        AppTextField(controller: _pickupAddress, label: 'Adresse *', hint: 'Rue, quartier, repère…', icon: Icons.place_outlined),
        const SizedBox(height: AppDimens.sm),
        Row(
          children: [
            Expanded(
              child: AppTextField(controller: _pickupArea, label: 'Quartier', icon: Icons.location_city_outlined),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: AppTextField(controller: _pickupCity, label: 'Ville', icon: Icons.map_outlined),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.xl),
        _SectionTitle(
          icon: Icons.place,
          title: 'Adresse de livraison',
          color: AppColors.orange,
          backgroundColor: AppColors.orangeLight,
        ),
        const SizedBox(height: 12),
        AppTextField(controller: _dropoffLabel, label: 'Libellé', hint: 'Ex : Bureau, domicile du destinataire…', icon: Icons.label_outline),
        const SizedBox(height: AppDimens.sm),
        AppTextField(controller: _dropoffAddress, label: 'Adresse *', hint: 'Rue, quartier, repère…', icon: Icons.place_outlined),
        const SizedBox(height: AppDimens.sm),
        Row(
          children: [
            Expanded(
              child: AppTextField(controller: _dropoffArea, label: 'Quartier', icon: Icons.location_city_outlined),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: AppTextField(controller: _dropoffCity, label: 'Ville', icon: Icons.map_outlined),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.xl),
        _SectionTitle(
          icon: Icons.notes_outlined,
          title: 'Détails du colis',
          color: AppColors.gold,
          backgroundColor: AppColors.goldLight,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _description,
          label: 'Description',
          hint: 'Ex : Document, colis fragile, taille… (optionnel)',
          icon: Icons.description_outlined,
          maxLines: 2,
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

  List<Widget> _buildQuote(Map<String, dynamic> quote) {
    final theme = Theme.of(context);
    final distance = quote['distance_km'];
    final deliveryFee = (quote['delivery_fee'] as num?)?.toInt() ?? 0;
    final partner = (quote['partner_amount'] as num?)?.toInt() ?? 0;
    final platform = (quote['platform_amount'] as num?)?.toInt() ?? 0;

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
              _QuoteRow(label: 'Part livreur (80 %)', amount: partner),
              _QuoteRow(label: 'Part plateforme (20 %)', amount: platform),
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
                    Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
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