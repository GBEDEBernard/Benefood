import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/marketplace_api.dart';
import '../../core/navigation/notification_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatters.dart';
import 'app_network_image.dart';

IconData notificationIcon(String type) {
  if (type.startsWith('order.')) {
    return Icons.receipt_long_outlined;
  }
  if (type.startsWith('complaint.')) {
    return Icons.support_agent;
  }
  if (type.startsWith('delivery.')) {
    return Icons.delivery_dining_outlined;
  }
  if (type.startsWith('parcel.')) {
    return Icons.inventory_2_outlined;
  }
  if (type.startsWith('driver.favorite.')) {
    return Icons.handshake_outlined;
  }
  if (type.startsWith('promo') || type.startsWith('coupon')) {
    return Icons.local_offer_outlined;
  }
  return Icons.notifications_none;
}

Color notificationAccent(String type) {
  if (type.startsWith('order.')) {
    return AppColors.orange;
  }
  if (type.startsWith('complaint.')) {
    return AppColors.green;
  }
  if (type.startsWith('delivery.')) {
    return AppColors.goldDark;
  }
  if (type.startsWith('parcel.')) {
    return AppColors.info;
  }
  if (type.startsWith('driver.favorite.')) {
    return AppColors.green;
  }
  return AppColors.orange;
}

String notificationCategory(String type) {
  if (type.startsWith('order.')) {
    return 'Commande';
  }
  if (type.startsWith('complaint.')) {
    return 'Réclamation';
  }
  if (type.startsWith('delivery.')) {
    return 'Livraison';
  }
  if (type.startsWith('parcel.')) {
    return 'Colis';
  }
  if (type.startsWith('driver.favorite.')) {
    return 'Livreurs favoris';
  }
  if (type.startsWith('promo') || type.startsWith('coupon')) {
    return 'Offre';
  }
  return 'Notification';
}

/// Détail d'une notification : contenu complet (titre, message, image, date)
/// et action d'ouverture de l'élément lié (commande, mission, réclamation)
/// quand il existe. Partagé par la cloche et l'écran de notifications, pour
/// les espaces client, vendeur et livreur.
Future<void> showNotificationDetail(
  BuildContext context, {
  required Map<String, dynamic> item,
  required MarketplaceApi marketplace,
  NotificationAudience audience = NotificationAudience.client,
}) {
  final outerContext = context;
  final type = item['type'] is String ? item['type'] as String : '';
  final accent = notificationAccent(type);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
    ),
    builder: (sheetContext) {
      final title = item['title'] is String ? item['title'] as String : '';
      final body = item['body'] is String ? item['body'] as String : '';
      final createdAt =
          item['created_at'] is String ? item['created_at'] as String : null;
      final imageUrl =
          item['image_url'] is String ? item['image_url'] as String : null;

      final rawData = item['data'];
      final data =
          rawData is Map<String, dynamic> ? rawData : const <String, dynamic>{};
      final orderId = notificationString(item, 'order_id') ??
          notificationString(data, 'order_id');
      final complaintId = notificationString(data, 'complaint_id');
      final deliveryId = notificationString(data, 'delivery_id') ??
          notificationString(data, 'course_id');
      final parcelId = notificationString(data, 'parcel_id');

      // Cible réelle selon l'espace : suivi client, commande vendeur, mission
      // livreur ou réclamation. L'action n'apparaît que si la notification
      // porte un identifiant exploitable dans l'espace courant.
      final isFavorite = type.startsWith('driver.favorite.');
      final IconData? actionIcon;
      final String? actionLabel;
      if (isFavorite) {
        actionIcon = Icons.people_outline;
        actionLabel = audience == NotificationAudience.driver
            ? 'Voir la demande'
            : 'Voir mes livreurs';
      } else if (audience == NotificationAudience.driver) {
        actionIcon = deliveryId != null ? Icons.delivery_dining_outlined : null;
        actionLabel = deliveryId != null ? 'Ouvrir la mission' : null;
      } else if (orderId != null) {
        actionIcon = audience == NotificationAudience.vendor
            ? Icons.storefront_outlined
            : Icons.receipt_long_outlined;
        actionLabel = audience == NotificationAudience.vendor
            ? 'Ouvrir la commande'
            : 'Suivre la commande';
      } else if (parcelId != null) {
        actionIcon = Icons.inventory_2_outlined;
        actionLabel = 'Suivre le colis';
      } else if (complaintId != null) {
        actionIcon = Icons.support_agent;
        actionLabel = 'Voir la réclamation';
      } else {
        actionIcon = null;
        actionLabel = null;
      }

      void openTarget() {
        Navigator.of(sheetContext).pop();
        if (orderId != null ||
            deliveryId != null ||
            parcelId != null ||
            isFavorite) {
          openNotificationTarget(
            outerContext,
            marketplace: marketplace,
            data: {
              ...data,
              'order_id': ?orderId,
              'parcel_id': ?parcelId,
            },
            audience: audience,
            type: type,
          );
        } else if (complaintId != null) {
          // Seul l'espace client dispose d'une route de détail ; côté vendeur
          // et livreur on ouvre la liste des réclamations du contexte.
          outerContext.push(
            audience == NotificationAudience.client
                ? '/client/complaints/$complaintId'
                : '/${audience.name}/complaints',
          );
        }
      }

      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            12,
            AppDimens.pagePadding,
            AppDimens.pagePadding + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(notificationIcon(type), color: accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusPill),
                          ),
                          child: Text(
                            notificationCategory(type),
                            style: TextStyle(
                              color: accent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title.isEmpty ? 'Notification' : title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  formatDateTime(createdAt),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (body.isNotEmpty) ...[
                const SizedBox(height: AppDimens.lg),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.text,
                  ),
                ),
              ],
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                const SizedBox(height: AppDimens.lg),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  child: SizedBox(
                    width: double.infinity,
                    height: 180,
                    child: AppNetworkImage(url: imageUrl, fit: BoxFit.cover),
                  ),
                ),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: AppDimens.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: openTarget,
                    icon: Icon(actionIcon, size: 20),
                    label: Text(actionLabel),
                  ),
                ),
              ],
              const SizedBox(height: AppDimens.md),
            ],
          ),
        ),
      );
    },
  );
}
