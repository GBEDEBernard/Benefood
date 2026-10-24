import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/client/orders/order_tracking_screen.dart';
import '../../features/client/parcels/parcel_detail_screen.dart';
import '../../features/driver/missions/mission_detail_screen.dart';
import '../../features/vendor/orders/vendor_order_detail_screen.dart';
import '../../shared/models/driver_mission.dart';
import '../../shared/models/user.dart';
import '../data/marketplace_api.dart';

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
///
/// [navigator], [router] et [messenger] peuvent être fournis par l'appelant
/// quand le [context] d'origine est susceptible d'être désactivé entre-temps
/// (feuille de détail fermée juste avant l'ouverture) : tous les accès au
/// contexte sont alors évités après le moindre `await`.
Future<bool> openNotificationTarget(
  BuildContext context, {
  required MarketplaceApi marketplace,
  required Map<String, dynamic> data,
  NotificationAudience audience = NotificationAudience.client,
  String? type,
  NavigatorState? navigator,
  GoRouter? router,
  ScaffoldMessengerState? messenger,
}) async {
  // Résolution immédiate des dépendances du contexte : l'appelant peut fermer
  // la feuille courante avant que la requête réseau ne réponde.
  final nav = navigator ?? Navigator.of(context, rootNavigator: true);
  final go = router ?? GoRouter.maybeOf(context);
  final snack = messenger ?? ScaffoldMessenger.maybeOf(context);
  // La couleur d'erreur est lue depuis le messenger : son contexte racine
  // reste valide même si le contexte d'origine a été désactivé.
  final errorColor = snack == null
      ? null
      : Theme.of(snack.context).colorScheme.error;

  // Livreurs favoris : la demande reçue par le livreur (à accepter/refuser) et
  // l'acceptation reçue par le client/vendeur ouvrent la liste correspondante.
  if (type != null && type.startsWith('driver.favorite.')) {
    go?.push(switch (audience) {
      NotificationAudience.driver => '/driver/favorite-clients',
      NotificationAudience.vendor => '/vendor/favorite-drivers',
      NotificationAudience.client => '/client/favorite-drivers',
    });
    return go != null;
  }

  // Livreur : la cible est la mission (course ou colis) portée par la
  // notification. Tant qu'aucun identifiant n'est fourni, la notification
  // reste lisible mais n'a pas de destination dédiée.
  if (audience == NotificationAudience.driver) {
    final deliveryId =
        notificationString(data, 'delivery_id') ??
        notificationString(data, 'course_id');
    if (deliveryId != null) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => MissionDetailScreen(
            marketplace: marketplace,
            missionId: deliveryId,
            kind: DriverMissionKind.order,
          ),
        ),
      );
      return true;
    }

    final driverParcelId = notificationString(data, 'parcel_id');
    if (driverParcelId != null) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => MissionDetailScreen(
            marketplace: marketplace,
            missionId: driverParcelId,
            kind: DriverMissionKind.parcel,
          ),
        ),
      );
      return true;
    }
  }

  // Colis : le suivi s'ouvre dans l'espace de lecture (client ou vendeur
  // expéditeur).
  final parcelId = notificationString(data, 'parcel_id');
  if (parcelId != null) {
    await nav.push(
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

  // Sans course ni colis, une notification livreur n'a pas de cible dédiée
  // (le livreur suit ses offres depuis son onglet).
  if (audience == NotificationAudience.driver) {
    return false;
  }

  final orderId = notificationOrderId(data);

  if (orderId == null) {
    return false;
  }

  try {
    // Le vendeur n'a pas la permission `client.orders.manage` : la route
    // client `/orders/{id}` lui répondrait 403. Son détail passe par
    // `/vendors/me/orders/{id}`.
    final order = audience == NotificationAudience.vendor
        ? await marketplace.vendorOrder(orderId)
        : await marketplace.order(orderId);

    if (audience == NotificationAudience.vendor) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              VendorOrderDetailScreen(marketplace: marketplace, order: order),
        ),
      );
    } else {
      // Côté client : écran de suivi réel (pas de route push dédiée, le
      // shell client la rejouerait sous le détail).
      await nav.push(
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
    if (snack != null) {
      snack.hideCurrentSnackBar();
      snack.showSnackBar(
        SnackBar(
          content: const Text('Impossible d\'ouvrir cette commande.'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
