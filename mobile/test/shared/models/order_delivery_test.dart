import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/models/order.dart';
import 'package:beninfood/shared/models/parcel.dart';

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
      final order = Order.fromJson(
        _orderWith({
          'id': 'del-1',
          'status': 'in_delivery',
          'driver': {
            'id': 'drv-1',
            'name': 'Achille',
            'vehicle': 'Moto',
            'rating': 4.5,
          },
          'position': {
            'latitude': 6.371,
            'longitude': 2.392,
            'last_location_at': '2026-09-18T11:18:28+00:00',
            'distance_km': 0.16,
            'age_seconds': 42,
          },
        }),
      );

      expect(order.delivery?.id, 'del-1');
      expect(order.delivery?.status, 'in_delivery');
      expect(order.delivery?.hasActiveDriver, isTrue);
      expect(order.delivery?.driver?.name, 'Achille');
      expect(order.delivery?.driver?.vehicle, 'Moto');
      expect(order.delivery?.driver?.rating, 4.5);
      expect(order.delivery?.position?.latitude, 6.371);
      expect(order.delivery?.position?.distanceKm, 0.16);
      expect(order.delivery?.position?.ageSeconds, 42);
      expect(order.delivery?.isTracking, isTrue);
      expect(order.delivery?.isActive, isTrue);
    });

    test('reste sans position hors course active', () {
      final order = Order.fromJson(
        _orderWith({
          'id': 'del-1',
          'status': 'delivered',
          'driver': {'id': 'drv-1', 'name': 'Achille'},
          'position': null,
        }),
      );

      expect(order.delivery?.isTracking, isFalse);
      expect(order.delivery?.isActive, isFalse);
      expect(order.delivery?.position, isNull);
      expect(order.delivery?.driver?.name, 'Achille');
    });

    test('reste actif avant le premier relevé GPS', () {
      final order = Order.fromJson(
        _orderWith({'id': 'del-2', 'status': 'en_route_pickup'}),
      );

      expect(order.delivery?.isTracking, isFalse);
      expect(order.delivery?.isActive, isTrue);
    });

    test('ignore un bloc delivery absent', () {
      final order = Order.fromJson(_orderWith(null));

      expect(order.delivery, isNull);
    });
  });

  group('Code de confirmation', _confirmationCodeTests);

  group('Parcel — suivi temps réel', () {
    test('parse la position du livreur pendant la course', () {
      final parcel = Parcel.fromJson({
        'id': 'par-1',
        'reference': 'COL-001',
        'status': 'in_delivery',
        'pickup': {
          'label': 'Boutique',
          'latitude': 6.37,
          'longitude': 2.42,
        },
        'dropoff': {
          'label': 'Client',
          'latitude': 6.35,
          'longitude': 2.44,
        },
        'position': {
          'latitude': 6.36,
          'longitude': 2.43,
          'heading': 90,
          'last_location_at': '2026-10-24T12:00:00+00:00',
          'age_seconds': 3,
          'distance_km': 1.5,
        },
      });

      expect(parcel.isTrackingActive, isTrue);
      expect(parcel.isPickupPhase, isFalse);
      expect(parcel.position?.latitude, 6.36);
      expect(parcel.position?.longitude, 2.43);
      expect(parcel.position?.heading, 90);
      expect(parcel.position?.ageSeconds, 3);
      expect(parcel.position?.distanceKm, 1.5);
    });

    test('masque la position une fois le colis livré', () {
      final parcel = Parcel.fromJson({
        'id': 'par-2',
        'reference': 'COL-002',
        'status': 'delivered',
      });

      expect(parcel.isTrackingActive, isFalse);
      expect(parcel.position, isNull);
    });
  });
}

void _confirmationCodeTests() {
  test('Order.fromJson expose le code de confirmation au client', () {
    final order = Order.fromJson({
      ..._orderWith(null),
      'confirmation_code': '123456',
    });

    expect(order.confirmationCode, '123456');
  });

  test('Parcel.fromJson expose le code de confirmation au client', () {
    final parcel = Parcel.fromJson({
      'id': 'par-1',
      'reference': 'COL-001',
      'status': 'in_delivery',
      'confirmation_code': '654321',
    });

    expect(parcel.confirmationCode, '654321');
  });
}
