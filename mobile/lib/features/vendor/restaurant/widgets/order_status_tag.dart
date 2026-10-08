import 'package:flutter/material.dart';

import '../restaurant_palette.dart';

/// Étiquette de statut de commande (« Nouveau », « Préparation », « Prête »…)
/// partagée par la liste et le détail.
class OrderStatusTag extends StatelessWidget {
  const OrderStatusTag(this.status, {super.key, this.small = false});

  final String status;
  final bool small;

  /// Libellé français + couleur associés au statut.
  static (String, Color) describe(String status) => switch (status) {
        'draft' || 'awaiting_payment' || 'paid' => ('Nouveau', RestaurantPalette.orange),
        'accepted' || 'preparing' => ('Préparation', RestaurantPalette.forest),
        'ready' => ('Prête', RestaurantPalette.ready),
        'assigned' || 'picked_up' || 'in_delivery' => ('Livraison', RestaurantPalette.ready),
        'delivered' => ('Livrée', RestaurantPalette.success),
        'refunded' => ('Remboursée', RestaurantPalette.success),
        'cancelled' => ('Annulée', RestaurantPalette.danger),
        _ => ('En cours', RestaurantPalette.grayText),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color) = describe(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 9 : 11, vertical: small ? 4 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}
