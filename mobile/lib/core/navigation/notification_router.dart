import 'package:flutter/material.dart';

import '../../features/client/orders/order_tracking_screen.dart';
import '../../features/vendor/restaurant/screens/order_details_screen.dart';
import '../data/marketplace_api.dart';
import '../../shared/widgets/feedback_widgets.dart';

/// Navigation « notification → détail » (J24) : à partir des données d'une
/// notification, ouvre le bon écran (détail d'une commande vendeur/client…).
///
/// Renvoie `true` quand un écran a été poussé.
Future<bool> openNotificationTarget(
  BuildContext context, {
  required MarketplaceApi marketplace,
  required Map<String, dynamic> data,
  bool isVendor = false,
}) async {
  final rawOrderId = data['order_id'];
  final orderId = rawOrderId is String && rawOrderId.isNotEmpty ? rawOrderId : null;

  if (orderId == null) {
    return false;
  }

  try {
    final order = await marketplace.order(orderId);
    if (!context.mounted) {
      return true;
    }

    final vendorSide = isVendor || data['role'] == 'vendor' || data['type'] == 'order.paid';

    if (vendorSide) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrderDetailsScreen(
            order: order,
            onAccept: (o) => _vendorAction(() => marketplace.vendorAccept(o.id)),
            onRefuse: (o) => _vendorAction(() => marketplace.vendorRefuse(o.id, reason: 'Refusé par le vendeur')),
            onPrepare: (o) => _vendorAction(() => marketplace.vendorPreparing(o.id)),
            onReady: (o) => _vendorAction(() => marketplace.vendorReady(o.id)),
          ),
        ),
      );
    } else {
      // Côté client : écran de suivi réel (pas de route push dédiée, le
      // shell client la rejouerait sous le détail).
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrderTrackingScreen(
            marketplace: marketplace,
            orderId: order.id,
          ),
        ),
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      showToast(context, 'Impossible d\'ouvrir cette commande.', isError: true);
    }
    return false;
  }
}

Future<bool> _vendorAction(Future<void> Function() call) async {
  try {
    await call();
    return true;
  } catch (_) {
    return false;
  }
}

String? notificationOrderId(Map<String, dynamic> data) =>
    data['order_id'] is String ? data['order_id'] as String : null;
