import 'package:flutter/material.dart';

import '../../features/client/orders/order_tracking_screen.dart';
import '../../features/client/parcels/parcel_detail_screen.dart';
import '../../features/driver/missions/mission_detail_screen.dart';
import '../../features/vendor/orders/vendor_order_detail_screen.dart';
import '../../shared/models/user.dart';
import '../data/marketplace_api.dart';
import '../../shared/widgets/feedback_widgets.dart';

/// Espace depuis lequel une notification est lue (cloche, écran de la liste,
/// push FCM). Il détermine l'écran ouvert quand l'utilisateur touche la
/// notification : suivi client, détail commande vendeur ou mission livreur.
enum NotificationAudience { client, vendor, driver }

/// Espace correspondant au contexte actif de la session (`client`, `vendor`,
/// `driver`) ; le client est le repli.
NotificationAudience notificationAudienceFromRole(String? role) {
  if (role == AppContext.vendor) {
    return NotificationAudience.vendor;
  }
  if (role == AppContext.driver) {
    return NotificationAudience.driver;
  }
  return NotificationAudience.client;
}

/// Navigation « notification → détail » (J24) : à partir des données d'une
/// notification, ouvre le bon écran pour l'espace courant.
///
/// Renvoie `true` quand un écran a été poussé.
Future<bool> openNotificationTarget(
  BuildContext context, {
  required MarketplaceApi marketplace,
  required Map<String, dynamic> data,
  NotificationAudience audience = NotificationAudience.client,
}) async {
  // Livreur : la cible est la course (mission) portée par la notification.
  // Tant qu'aucun identifiant de course n'est fourni, la notification reste
  // lisible mais n'a pas de destination dédiée.
  if (audience == NotificationAudience.driver) {
    final deliveryId =
        notificationString(data, 'delivery_id') ??
        notificationString(data, 'course_id');
    if (deliveryId == null) {
      return false;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MissionDetailScreen(
          marketplace: marketplace,
          deliveryId: deliveryId,
        ),
      ),
    );
    return true;
  }

  // Colis : le suivi s'ouvre dans l'espace de lecture (client ou vendeur
  // expéditeur). Le livreur garde ses courses dans son onglet Colis.
  final parcelId = notificationString(data, 'parcel_id');
  if (parcelId != null) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParcelDetailScreen(
          marketplace: marketplace,
          parcelId: parcelId,
          audience: audience,
        ),
      ),
    );
    return true;
  }

  final orderId = notificationOrderId(data);

  if (orderId == null) {
    return false;
  }

  try {
    final order = await marketplace.order(orderId);
    if (!context.mounted) {
      return true;
    }

    if (audience == NotificationAudience.vendor) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              VendorOrderDetailScreen(marketplace: marketplace, order: order),
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

/// Identifiant de commande porté par les données d'une notification.
String? notificationOrderId(Map<String, dynamic> data) =>
    notificationString(data, 'order_id');

/// Lit une chaîne non vide dans le payload d'une notification.
String? notificationString(Map<String, dynamic> data, String key) {
  final value = data[key];
  return value is String && value.isNotEmpty ? value : null;
}
