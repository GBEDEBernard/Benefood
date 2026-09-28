import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/address.dart';
import '../../../shared/models/checkout.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';
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
  Map<String, dynamic>? _paymentPayload;
  bool _creating = false;
  bool _verifying = false;

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

  Future<void> _createOrder() async {
    final address = _selectedAddress;
    if (address == null) {
      return;
    }
    setState(() => _creating = true);
    try {
      final order = await widget.marketplace.createOrder(address.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _order = order;
        _creating = false;
      });
      _startPayment(order);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _startPayment(Order order) async {
    if (order.isAwaitingPayment) {
      setState(() => _creating = true);
      try {
        final payload = await widget.marketplace.createPayment(order.id);
        if (mounted) {
          setState(() {
            _paymentPayload = payload;
            _creating = false;
          });
          _showPaymentDialog(order);
        }
      } on ApiException catch (e) {
        if (mounted) {
          setState(() => _creating = false);
          showToast(context, e.message, isError: true);
        }
      }
    }
  }

  void _showPaymentDialog(Order order) {
    final payload = _paymentPayload;
    final widgetConfig = payload?['widget'];
    if (widgetConfig is! Map<String, dynamic>) {
      _goToTracking(order, success: false);
      return;
    }

    final key = widgetConfig['key'];
    if (key is! String || key.isEmpty) {
      // Mode sandbox sans clé : basculer en attente (démo).
      _goToTracking(order, success: false);
      return;
    }

    final amount = widgetConfig['amount'];
    final amountValue = amount is num ? '${amount.toInt()}' : '${amount ?? 0}';
    final orderId = widgetConfig['order_id'];
    final callback = widgetConfig['callback'];
    final url = 'https://kkiapay.me/fr/mobilepay/${Uri(queryParameters: {
          'key': key,
          'amount': amountValue,
          'order_id': orderId?.toString() ?? order.id,
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
            const Text(
              'Ouvrez le lien de paiement ci-dessous pour régler votre commande via Kkiapay :',
            ),
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
              _goToTracking(order, success: false);
            },
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _verifyPayment(order);
            },
            child: const Text('J\'ai payé'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyPayment(Order order) async {
    setState(() => _verifying = true);
    try {
      final latest = await widget.marketplace.order(order.id);
      if (!mounted) {
        return;
      }
      setState(() => _verifying = false);
      final paid = latest.status == 'paid' ||
          latest.paymentStatus == 'confirmed' ||
          latest.paymentStatus == 'paid';
      _goToTracking(latest, success: paid);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _verifying = false);
        showToast(context, e.message, isError: true);
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Valider la commande')),
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
                const SizedBox(height: 4),
              ],
              OutlinedButton.icon(
                onPressed: () async {
                  final created = await context.push<Address>('/client/addresses?select=1');
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
                  foregroundColor: AppColors.green,
                  side: BorderSide(color: AppColors.green.withValues(alpha: 0.4)),
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
                                    color: AppColors.greenDark,
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
                AppButton(
                  label: 'Commander',
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
                const SizedBox(height: 4),
                _SummaryRow(label: 'Total à payer', amount: order.total, emphasized: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_paymentPayload != null) ...[
          _PaymentWidgetInfo(payload: _paymentPayload!),
          const SizedBox(height: 12),
        ],
        if (_verifying)
          const Center(child: CircularProgressIndicator())
        else
          AppButton(
            label: order.isAwaitingPayment ? 'Payer maintenant' : 'Voir la commande',
            icon: Icons.payment,
            onPressed: order.isAwaitingPayment
                ? () {
                    setState(() => _paymentPayload = null);
                    _startPayment(order);
                  }
                : () => _goToTracking(order, success: order.isPaid),
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
          color: selected ? AppColors.green : Colors.transparent,
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
                  color: selected ? AppColors.greenLight : const Color(0xFFF0F2F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? Icons.location_on : Icons.location_on_outlined,
                  color: selected ? AppColors.green : AppColors.textSecondary,
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
                  color: selected ? AppColors.green : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.green : AppColors.textSecondary.withValues(alpha: 0.5),
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

class _PaymentWidgetInfo extends StatelessWidget {
  const _PaymentWidgetInfo({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final widget = payload['widget'];
    String info = 'Paiement via ${payload['provider'] ?? 'kkiapay'}';
    if (widget is Map<String, dynamic>) {
      info += '\nMontant : ${formatAmount((widget['amount'] as num?)?.toInt() ?? 0)}';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.security, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(info, style: Theme.of(context).textTheme.bodySmall)),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Copier la configuration paiement (démo)',
              onPressed: () => Clipboard.setData(ClipboardData(text: jsonEncode(widget))),
            ),
          ],
        ),
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