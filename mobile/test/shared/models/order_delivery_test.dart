import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/models/order.dart';

Map<String, dynamic> _orderWith(Map<String, dynamic>? delivery) => {
      'id': 'ord-1',
      'reference': 'REF-001',
      'status': 'in_delivery',
      'payment_status': 'confirmed',
      'items': [],
      'subtotal': 1000,
      'delivery_fee': 1500,
      'total': 2500,
      'delivery': delivery,
    }..removeWhere((key, value) => key == 'delivery' && value == null);

void main() {
  group('Order.fromJson — bloc delivery (J177)', () {
    test('parse le livreur et la position pendant la course', () {
      final order = Order.fromJson(_orderWith({
        'id': 'del-1',
        'status': 'in_delivery',
        'driver': {'id': 'drv-1', 'name': 'Achille', 'vehicle': 'Moto', 'rating': 4.5},
        'position': {
          'latitude': 6.371,
          'longitude': 2.392,
          'last_location_at': '2026-09-18T11:18:28+00:00',
          'distance_km': 0.16,
        },
      }));

      expect(order.delivery?.id, 'del-1');
      expect(order.delivery?.status, 'in_delivery');
      expect(order.delivery?.hasActiveDriver, isTrue);
      expect(order.delivery?.driver?.name, 'Achille');
      expect(order.delivery?.driver?.vehicle, 'Moto');
      expect(order.delivery?.driver?.rating, 4.5);
      expect(order.delivery?.position?.latitude, 6.371);
      expect(order.delivery?.position?.distanceKm, 0.16);
      expect(order.delivery?.isTracking, isTrue);
    });

    test('reste sans position hors course active', () {
      final order = Order.fromJson(_orderWith({
        'id': 'del-1',
        'status': 'delivered',
        'driver': {'id': 'drv-1', 'name': 'Achille'},
        'position': null,
      }));

      expect(order.delivery?.isTracking, isFalse);
      expect(order.delivery?.position, isNull);
      expect(order.delivery?.driver?.name, 'Achille');
    });

    test('ignore un bloc delivery absent', () {
      final order = Order.fromJson(_orderWith(null));

      expect(order.delivery, isNull);
    });
  });
}