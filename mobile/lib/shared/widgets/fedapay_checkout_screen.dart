import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/data/marketplace_api.dart';
import '../../core/theme/app_colors.dart';

/// Ouvre la page de paiement hébergée FedaPay et renvoie `true` si la
/// transaction est confirmée.
Future<bool> startFedaPayCheckout(
  BuildContext context, {
  required MarketplaceApi marketplace,
  required String checkoutUrl,
  String? transactionId,
}) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => FedaPayCheckoutScreen(
        marketplace: marketplace,
        checkoutUrl: checkoutUrl,
        transactionId: transactionId,
      ),
    ),
  );
  return result ?? false;
}

/// Ouvre la page de paiement hébergée FedaPay dans l'application.
///
/// Ferme l'écran en renvoyant `true` lorsque la transaction est confirmée
/// (retour sur l'URL de callback ou vérification serveur réussie).
class FedaPayCheckoutScreen extends StatefulWidget {
  const FedaPayCheckoutScreen({
    super.key,
    required this.marketplace,
    required this.checkoutUrl,
    this.transactionId,
    this.title = 'Paiement sécurisé',
  });

  final MarketplaceApi marketplace;
  final String checkoutUrl;
  final String? transactionId;
  final String title;

  @override
  State<FedaPayCheckoutScreen> createState() => _FedaPayCheckoutScreenState();
}

class _FedaPayCheckoutScreenState extends State<FedaPayCheckoutScreen> {
  bool _loading = true;
  bool _resolving = false;

  bool _isCallback(String url) =>
      url.contains('/payments/callback') || url.contains('/payments/webhook');

  Future<void> _resolve({required bool verify}) async {
    if (_resolving || !mounted) {
      return;
    }
    _resolving = true;

    var paid = false;
    final transactionId = widget.transactionId;
    if (verify && transactionId != null && transactionId.isNotEmpty) {
      try {
        final result = await widget.marketplace.verifyPayment(transactionId);
        final status = (result['status'] ?? '').toString().toLowerCase();
        paid = result['paid'] == true ||
            const ['success', 'successful', 'approved', 'paid', 'completed']
                .contains(status);
      } on Object {
        paid = false;
      }
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(paid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => _resolve(verify: true),
        ),
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: InAppWebView(
              initialUrlRequest:
                  URLRequest(url: WebUri(widget.checkoutUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
                transparentBackground: true,
              ),
              onLoadStart: (controller, url) {
                if (mounted) {
                  setState(() => _loading = true);
                }
              },
              onLoadStop: (controller, url) {
                if (mounted) {
                  setState(() => _loading = false);
                }
                final value = url?.toString() ?? '';
                if (_isCallback(value)) {
                  _resolve(verify: true);
                }
              },
              shouldOverrideUrlLoading: (controller, action) async {
                final url = action.request.url?.toString() ?? '';
                if (_isCallback(url)) {
                  _resolve(verify: true);
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: () => _resolve(verify: true),
                child: const Text('J’ai terminé le paiement'),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.surface,
    );
  }
}
