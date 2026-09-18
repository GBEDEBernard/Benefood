import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/address.dart';
import '../../../shared/models/checkout.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/amount_widgets.dart';
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
    });
    try {
      final summary = await widget.marketplace.orderSummary(address.id);
      if (mounted) {
        setState(() => _summary = summary);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Livraison impossible : ${e.message}'), behavior: SnackBarBehavior.floating),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
          );
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
    final url = 'https://kkiapay.me/fr/mobilepay/' +
        Uri(queryParameters: {
          'key': key,
          'amount': amountValue,
          'order_id': orderId?.toString() ?? order.id,
          if (callback is String) 'callback': callback,
        }).query;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
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
              const Text('Adresse de livraison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              if (_addresses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Aucune adresse enregistrée.'),
                )
              else
                RadioGroup<Address>(
                  groupValue: _selectedAddress,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedAddress = value);
                      _loadSummary();
                    }
                  },
                  child: Column(
                    children: _addresses.map((a) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: RadioListTile<Address>(
                          value: a,
                          title: Text(a.label ?? 'Adresse'),
                          subtitle: Text(_addressSummary(a)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              TextButton.icon(
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
                label: const Text('Ajouter une adresse'),
              ),
              const SizedBox(height: 20),
              if (_summaryLoading)
                const Center(child: CircularProgressIndicator())
              else if (_summary != null) ...[
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
                              child: Text(
                                'Zone : ${_summary!.deliveryZoneName}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                        const Divider(height: 24),
                        _SummaryRow(label: 'Total', amount: _summary!.total, emphasized: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                        AmountText(item.subtotal),
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