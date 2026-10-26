import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/address.dart';
import '../../../shared/models/checkout.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/favorite_driver_picker.dart';
import '../../../shared/widgets/fedapay_checkout_screen.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../account/addresses_screen.dart';
import '../orders/order_tracking_screen.dart';

/// Checkout client (J151) : adresse → récapitulatif serveur → commande → paiement.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<Address> _addresses = [];
  Address? _selectedAddress;
  bool _loadingAddresses = true;
  String? _addressesError;

  OrderSummary? _summary;
  bool _summaryLoading = false;
  String? _summaryError;

  Order? _order;
  bool _creating = false;

  /// Mode de règlement choisi au checkout : `online` (Mobile Money) ou `cash`
  /// (espèces remises au livreur — cahier de conception v1.0).
  String _paymentMethod = 'online';

  /// Livreur favori visé (optionnel) : l'offre lui sera réservée en priorité.
  String? _favoriteDriverId;
  String? _favoriteDriverName;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _loadingAddresses = true;
      _addressesError = null;
    });
    try {
      final addresses = await widget.marketplace.addresses();
      if (!mounted) {
        return;
      }
      setState(() {
        _addresses = addresses;
        _loadingAddresses = false;
        if (_selectedAddress == null && addresses.isNotEmpty) {
          _selectedAddress = addresses.first;
        }
      });
      if (_selectedAddress != null) {
        await _loadSummary();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _addressesError = e.message;
          _loadingAddresses = false;
        });
      }
    }
  }

  Future<void> _loadSummary() async {
    final address = _selectedAddress;
    if (address == null) {
      return;
    }
    if (!address.hasCoordinates) {
      setState(() {
        _summaryLoading = false;
        _summary = null;
        _summaryError =
            'Positionnez cette adresse sur la carte pour calculer la livraison.';
      });
      return;
    }
    setState(() {
      _summaryLoading = true;
      _summary = null;
      _summaryError = null;
    });
    try {
      final summary = await widget.marketplace.orderSummary(address.id);
      if (mounted) {
        setState(() => _summary = summary);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _summaryLoading = false;
          _summary = null;
          _summaryError = e.message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _summaryLoading = false);
      }
    }
  }

  Future<void> _pinSelectedAddress() async {
    final address = _selectedAddress;
    if (address == null) {
      return;
    }
    final updated = await showAddressLocationSheet(
      context,
      widget.marketplace,
      address,
    );
    if (updated == null || !mounted) {
      return;
    }
    setState(() {
      _addresses = _addresses
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
      _selectedAddress = updated;
    });
    await _loadSummary();
  }

  Future<void> _createOrder() async {
    final address = _selectedAddress;
    if (address == null) {
      return;
    }
    setState(() => _creating = true);
    try {
      final order = await widget.marketplace.createOrder(
        address.id,
        paymentMethod: _paymentMethod,
        favoriteDriverId: _favoriteDriverId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _order = order;
        _creating = false;
      });
      if (order.isCash) {
        // Paiement à la livraison : aucun règlement en ligne, la commande part
        // chez le vendeur et sera encaissée par le livreur.
        _goToTracking(order, success: true);
        return;
      }
      _startPayment(order);
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

  Future<void> _startPayment(Order order) async {
    if (order.isCash) {
      // Les commandes en espèces ne passent pas par la passerelle de paiement.
      _goToTracking(order, success: true);
      return;
    }
    if (!order.isAwaitingPayment) {
      _goToTracking(order, success: order.isPaid);
      return;
    }

    setState(() => _creating = true);
    try {
      final payload = await widget.marketplace.createPayment(order.id);
      if (!mounted) {
        return;
      }
      setState(() => _creating = false);

      final checkoutUrl = payload['checkout_url'];
      if (checkoutUrl is! String || checkoutUrl.isEmpty) {
        // Passerelle injoignable ou non configurée : on informe le client au
        // lieu d'enchaîner silencieusement vers le suivi.
        final message = payload['message']?.toString();
        if (message != null && message.isNotEmpty) {
          showToast(context, message, isError: false);
        }
        _goToTracking(order, success: false);
        return;
      }

      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => FedaPayCheckoutScreen(
            marketplace: widget.marketplace,
            checkoutUrl: checkoutUrl,
            transactionId: payload['transaction_id']?.toString(),
          ),
        ),
      );
      if (!mounted) {
        return;
      }

      final fresh = await _refreshOrder(order);
      if (!mounted) {
        return;
      }
      _goToTracking(fresh, success: paid == true || fresh.isPaid);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<Order> _refreshOrder(Order order) async {
    try {
      return await widget.marketplace.order(order.id);
    } on ApiException {
      return order;
    }
  }

  void _goToTracking(Order order, {required bool success}) {
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TrackingResultScreen(
          marketplace: widget.marketplace,
          order: order,
          success: success,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BeninfoodPageScaffold(
      title: 'Valider la commande',
      api: widget.marketplace,
      body: _order != null ? _buildPaymentStep() : _buildAddressStep(),
    );
  }

  Widget _buildAddressStep() {
    if (_loadingAddresses) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_addressesError != null) {
      return ErrorState(message: _addressesError!, onRetry: _loadAddresses);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle(
                icon: Icons.location_on_outlined,
                title: 'Adresse de livraison',
              ),
              const SizedBox(height: 12),
              if (_addresses.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.add_location_alt_outlined, size: 36, color: AppColors.textSecondary),
                        const SizedBox(height: 8),
                        Text(
                          'Aucune adresse enregistrée.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                for (final a in _addresses)
                  _AddressCard(
                    address: a,
                    selected: _selectedAddress?.id == a.id,
                    onTap: () {
                      setState(() => _selectedAddress = a);
                      _loadSummary();
                    },
                  ),
                if (_selectedAddress != null &&
                    !_selectedAddress!.hasCoordinates)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: AppColors.orangeLight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_off_outlined,
                            color: AppColors.orangeDark,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Cette adresse n’a pas de repère GPS. Positionnez-la sur la carte avant de commander.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.orangeDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _pinSelectedAddress,
                            child: const Text('Positionner'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
              OutlinedButton.icon(
                onPressed: () async {
                  final created = await showAddAddressSheet(context, widget.marketplace);
                  if (created != null && mounted) {
                    setState(() {
                      _addresses = [created, ..._addresses];
                      _selectedAddress = created;
                    });
                    await _loadSummary();
                  }
                },
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Ajouter une nouvelle adresse'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  side: BorderSide(color: AppColors.orange.withValues(alpha: 0.5)),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 24),
              if (_summaryError != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Livraison impossible : $_summaryError',
                            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_summaryLoading)
                const Center(child: CircularProgressIndicator())
              else if (_summary != null) ...[
                _SectionTitle(
                  icon: Icons.receipt_long_outlined,
                  title: 'Récapitulatif',
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _SummaryRow(label: 'Sous-total', amount: _summary!.subtotal),
                        _SummaryRow(label: 'Livraison', amount: _summary!.deliveryFee),
                        if (_summary!.deliveryDistanceKm != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 6),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Distance estimée : ${_summary!.deliveryDistanceKm!.toStringAsFixed(2)} km',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        if (_summary!.serviceFee > 0)
                          _SummaryRow(label: 'Commission client', amount: _summary!.serviceFee),
                        if (_summary!.deliveryZoneName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.greenLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Zone : ${_summary!.deliveryZoneName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.green,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const Divider(height: 24),
                        _SummaryRow(label: 'Total', amount: _summary!.total, emphasized: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionTitle(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Mode de paiement',
                ),
                const SizedBox(height: 12),
                Card(
                  child: RadioGroup<String>(
                    groupValue: _paymentMethod,
                    onChanged: (value) => setState(() => _paymentMethod = value ?? 'online'),
                    child: Column(
                      children: [
                        const RadioListTile<String>(
                          value: 'online',
                          activeColor: AppColors.orange,
                          title: Text('Mobile Money (en ligne)'),
                          subtitle: Text('Réglez maintenant, la commande part aussitôt'),
                          secondary: Icon(Icons.phone_android, color: AppColors.orange),
                        ),
                        const RadioListTile<String>(
                          value: 'cash',
                          activeColor: AppColors.orange,
                          title: Text('Paiement à la livraison'),
                          subtitle: Text('Vous payez le livreur en espèces'),
                          secondary: Icon(Icons.payments_outlined, color: AppColors.orange),
                        ),
                        if (_paymentMethod == 'cash')
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Prévoyez ${formatAmount(_summary!.total)} en espèces pour le livreur.',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionTitle(
                  icon: Icons.delivery_dining_outlined,
                  title: 'Livreur favori (optionnel)',
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    onTap: _pickFavoriteDriver,
                    leading: const Icon(Icons.delivery_dining_outlined, color: AppColors.orange),
                    title: Text(_favoriteDriverName ?? 'Aucun livreur'),
                    subtitle: Text(
                      _favoriteDriverName == null
                          ? 'L\'offre sera visible par tous les livreurs disponibles'
                          : 'Ce livreur recevra l\'offre en priorité',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: _paymentMethod == 'cash' ? 'Commander et payer à la livraison' : 'Commander',
                  icon: Icons.shopping_bag_outlined,
                  onPressed: _creating ? null : _createOrder,
                  loading: _creating,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStep() {
    final order = _order!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Commande ${order.reference}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text('À régler : ${formatAmount(order.total)}', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text('${item.quantity} × ${item.name}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: AmountText(item.subtotal, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 24),
                _SummaryRow(label: 'Sous-total', amount: order.subtotal),
                _SummaryRow(label: 'Livraison', amount: order.deliveryFee),
                if ((order.financials?.serviceFee ?? 0) > 0)
                  _SummaryRow(label: 'Commission client', amount: order.financials!.serviceFee!),
                const SizedBox(height: 4),
                _SummaryRow(label: 'Total à payer', amount: order.total, emphasized: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: order.isAwaitingPayment ? 'Payer maintenant' : 'Voir la commande',
          icon: Icons.payment,
          onPressed: () => _startPayment(order),
          loading: _creating,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: AppColors.green),
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

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.selected, required this.onTap});

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.orange : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? AppColors.orangeLight : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? Icons.location_on : Icons.location_on_outlined,
                  color: selected ? AppColors.orangeDark : AppColors.textSecondary,
                  size: 22,
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
                              color: AppColors.goldLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Par défaut',
                              style: TextStyle(fontSize: 10.5, color: AppColors.gold, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _addressSummary(address),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.orange : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppColors.orange
                        : AppColors.textSecondary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, this.amount, this.emphasized = false});

  final String label;
  final int? amount;
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
          if (amount != null)
            AmountText(amount!, style: style)
          else
            Text('—', style: style),
        ],
      ),
    );
  }
}

String _addressSummary(Address address) {
  final parts = [
    address.fullAddress,
    address.city,
    if (address.landmark != null) 'près de ${address.landmark}',
  ].whereType<String>().where((p) => p.isNotEmpty).toList();
  return parts.join(' · ');
}