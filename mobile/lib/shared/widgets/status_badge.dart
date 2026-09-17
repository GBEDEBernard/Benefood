import 'package:flutter/material.dart';

/// Badge de statut avec palette par type (J24 §3).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.color, this.icon, this.small = false});

  final String label;
  final Color? color;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final bg = (color ?? Colors.blueGrey).withValues(alpha: 0.12);
    final fg = color ?? Colors.blueGrey.shade700;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: small ? 11 : 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Palette statuts commande (J24 §3).
class BadgePalette {
  static const _grey = Color(0xFF757575);
  static const _amber = Color(0xFFF9A825);
  static const _indigo = Color(0xFF3949AB);
  static const _green = Color(0xFF2E7D32);
  static const _red = Color(0xFFC62828);

  static (String, Color)? order(String? status) => switch (status) {
        'draft' || 'awaiting_payment' => ('En attente de paiement', _grey),
        'paid' => ('Payée', _amber),
        'accepted' => ('Acceptée', _amber),
        'preparing' => ('En préparation', _amber),
        'ready' => ('Prête', _indigo),
        'assigned' => ('Livreur affecté', _indigo),
        'picked_up' => ('En cours de livraison', _indigo),
        'in_delivery' => ('En cours de livraison', _indigo),
        'delivered' => ('Livrée', _green),
        'refunded' => ('Remboursée', _green),
        'cancelled' => ('Annulée', _red),
        _ => null,
      };

  static (String, Color)? vendor(String? status) => switch (status) {
        'registered' || 'pending' => ('En vérification', _grey),
        'verified' => ('Vérifiée', _grey),
        'active' => ('Active', _green),
        'suspended' => ('Suspendue', _red),
        'closed' => ('Fermée', _red),
        _ => null,
      };

  static (String, Color)? driver(String? status) => switch (status) {
        'candidate' || 'pending' => ('En vérification', _grey),
        'validated' => ('Vérifié', _grey),
        'active' => ('Actif', _green),
        'suspended' => ('Suspendu', _red),
        'closed' => ('Fermé', _red),
        _ => null,
      };

  static (String, Color)? delivery(String? status) => switch (status) {
        'proposed' => ('Proposée', _amber),
        'available' => ('Disponible', _amber),
        'assigned' => ('Affectée', _indigo),
        'picked_up' => ('Collectée', _indigo),
        'in_delivery' => ('En livraison', _indigo),
        'delivered' => ('Livrée', _green),
        'cancelled' => ('Annulée', _red),
        'incident' => ('Incident', _red),
        _ => null,
      };

  static (String, Color)? refund(String? status) => switch (status) {
        'pending' => ('En attente', _amber),
        'processing' => ('En cours', _grey),
        'executed' => ('Exécuté', _green),
        'failed' => ('Échoué', _red),
        _ => null,
      };

  static (String, Color)? complaint(String? status) => switch (status) {
        'open' => ('Ouverte', _amber),
        'in_progress' => ('En traitement', _indigo),
        'closed' => ('Clôturée', _green),
        _ => null,
      };

  static (String, Color)? payment(String? status) => switch (status) {
        'initiated' => ('Initée', _grey),
        'confirmed' || 'paid' => ('Payé', _green),
        'failed' => ('Échoué', _red),
        'cancelled' => ('Annulé', _red),
        'expired' => ('Expiré', _grey),
        'refunded' => ('Remboursé', _green),
        _ => null,
      };

  static (String, Color)? bool(String? value, {String trueLabel = 'Oui', String falseLabel = 'Non'}) =>
      value == 'true' || value == '1' ? (trueLabel, _green) : (falseLabel, _grey);
}