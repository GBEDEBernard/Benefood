import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/models/checkout.dart';
import 'package:beninfood/shared/models/order.dart';

Map<String, dynamic> _pickupOrderJson() => {
  'id': 'ord-1',
  'reference': 'REF-001',
  'status': 'ready',
  'payment_status': 'confirmed',
  'fulfillment_method': 'pickup',
  'confirmation_code': '123456',
  'items': <dynamic>[],
  'subtotal': 2500,
  'delivery_fee': 0,
  'total': 2500,
};

void main() {
  group('OrderSummary — mode de remise', () {
    test('parse un récapitulatif retrait sur place (total = produits)', () {
      final summary = OrderSummary.fromJson({
        'items': <dynamic>[],
        'subtotal': 2500,
        'delivery_fee': 0,
        'delivery_total': 0,
        'total': 2500,
        'fulfillment_method': 'pickup',
      });

      expect(summary.fulfillmentMethod, 'pickup');
      expect(summary.isPickup, isTrue);
      expect(summary.total, summary.subtotal);
    });

    test('par défaut en livraison si le champ est absent', () {
      final summary = OrderSummary.fromJson({
        'items': <dynamic>[],
        'subtotal': 2500,
        'delivery_fee': 500,
        'total': 3000,
      });

      expect(summary.fulfillmentMethod, 'delivery');
      expect(summary.isPickup, isFalse);
    });
  });

  group('Order — retrait sur place et codes de remise', () {
    test('parse le mode pickup et le code du client', () {
      final order = Order.fromJson(_pickupOrderJson());

      expect(order.isSelfPickup, isTrue);
      expect(order.confirmationCode, '123456');
      expect(order.canConfirmPickup, isTrue);
      expect(order.deliveryTotal, 0);
      expect(order.canChooseDriver, isFalse);
    });

    test('parse le code de collecte du vendeur (livraison)', () {
      final order = Order.fromJson({
        ..._pickupOrderJson(),
        'fulfillment_method': 'delivery',
        'delivery_fee': 500,
        'delivery': {
          'id': 'del-1',
          'status': 'ready',
          'fee': 500,
          'pickup_code': '654321',
        },
        'vendor_pickup_code': '654321',
      });

      expect(order.isSelfPickup, isFalse);
      expect(order.vendorPickupCode, '654321');
      expect(order.canConfirmPickup, isFalse);
      expect(order.deliveryTotal, 500);
    });

    test('par défaut en livraison pour une ancienne commande', () {
      final json = _pickupOrderJson()..remove('fulfillment_method');
      final order = Order.fromJson(json);

      expect(order.fulfillmentMethod, 'delivery');
      expect(order.isSelfPickup, isFalse);
    });

    test('withStatus conserve le mode de remise et le code', () {
      final order = Order.fromJson(_pickupOrderJson());
      final updated = order.withStatus('delivered');

      expect(updated.isSelfPickup, isTrue);
      expect(updated.confirmationCode, '123456');
      expect(updated.canConfirmPickup, isFalse);
    });
  });
}
