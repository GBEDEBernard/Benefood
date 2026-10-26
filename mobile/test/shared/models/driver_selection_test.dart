import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/models/driver_selection.dart';
import 'package:beninfood/shared/models/order.dart';
import 'package:beninfood/shared/models/parcel.dart';

void main() {
  group('DriverSelectionPage.fromJson', () {
    test('parse les livreurs proches, distances et ETA', () {
      final page = DriverSelectionPage.fromJson({
        'pickup': {
          'latitude': 6.365,
          'longitude': 2.39,
          'address': 'Marché Dantokpa',
          'landmark': 'Entrée nord',
          'city': 'Cotonou',
        },
        'dropoff': {'latitude': 6.37, 'longitude': 2.391, 'address': 'Ganhi'},
        'radius_km': 5,
        'requested_radius_km': 5,
        'max_radius_km': 15,
        'expanded': false,
        'drivers': [
          {
            'id': 'drv-1',
            'name': 'Achille',
            'avatar_url': 'https://cdn.test/achille.jpg',
            'vehicle': 'Moto',
            'rating': 4.8,
            'completed_deliveries': 12,
            'distance_to_pickup_km': 1.2,
            'eta_to_pickup_s': 390,
            'pickup_to_dropoff_km': 3.4,
            'eta_to_dropoff_s': 780,
            'distance_to_dropoff_km': 4.6,
            'eta_total_s': 1170,
            'position': {
              'latitude': 6.366,
              'longitude': 2.391,
              'heading': 90,
              'last_location_at': '2026-10-26T10:00:00+00:00',
              'age_seconds': 12,
            },
          },
        ],
      });

      expect(page.radiusKm, 5);
      expect(page.expanded, isFalse);
      expect(page.pickup?.display, contains('Marché Dantokpa'));
      expect(page.drivers, hasLength(1));

      final driver = page.drivers.single;
      expect(driver.id, 'drv-1');
      expect(driver.displayName, 'Achille');
      expect(driver.completedDeliveries, 12);
      expect(driver.distanceToPickupKm, 1.2);
      expect(driver.etaToPickupSeconds, 390);
      expect(driver.pickupToDropoffKm, 3.4);
      expect(driver.etaTotalSeconds, 1170);
      expect(driver.position?.latitude, 6.366);
      expect(driver.position?.heading, 90);
      expect(driver.position?.ageSeconds, 12);
    });

    test('parse une demande en attente avant que la commande soit prête', () {
      final page = DriverSelectionPage.fromJson({
        'drivers': [],
        'request': {
          'id': 'req-1',
          'status': 'pending',
          'offered_at': null,
          'expires_at': null,
          'driver': {
            'id': 'drv-1',
            'name': 'Achille',
            'vehicle': 'Moto',
            'rating': 4.8,
          },
        },
      });

      final request = page.request!;
      expect(request.isPending, isTrue);
      expect(request.waitsForReady, isTrue);
      expect(request.driver?.displayName, 'Achille');
      expect(request.expiresAt, isNull);
    });
  });

  group('Commande et colis — driver_request', () {
    test(
      'Order expose la demande et bloque le choix tant qu\'elle est pending',
      () {
        final order = Order.fromJson({
          'id': 'ord-1',
          'reference': 'REF-001',
          'status': 'paid',
          'payment_status': 'confirmed',
          'items': [],
          'subtotal': 1000,
          'delivery_fee': 500,
          'total': 1500,
          'driver_request': {
            'id': 'req-1',
            'status': 'pending',
            'driver': {'id': 'drv-1', 'name': 'Achille'},
          },
        });

        expect(order.driverRequest?.isPending, isTrue);
        expect(order.isWaitingDriver, isTrue);
        expect(order.canChooseDriver, isFalse);
      },
    );

    test('Order autorise un nouveau choix après refus', () {
      final order = Order.fromJson({
        'id': 'ord-1',
        'reference': 'REF-001',
        'status': 'preparing',
        'payment_status': 'confirmed',
        'items': [],
        'subtotal': 1000,
        'delivery_fee': 500,
        'total': 1500,
        'driver_request': {
          'id': 'req-1',
          'status': 'refused',
          'refusal_reason': 'Trop loin',
          'driver': {'id': 'drv-1', 'name': 'Achille'},
        },
      });

      expect(order.driverRequest?.isRefused, isTrue);
      expect(order.canChooseDriver, isTrue);
    });

    test('Parcel expose la demande et le choix après expiration', () {
      final parcel = Parcel.fromJson({
        'id': 'par-1',
        'reference': 'COL-001',
        'status': 'paid',
        'driver_request': {
          'id': 'req-2',
          'status': 'expired',
          'driver': {'id': 'drv-2', 'name': 'Boris'},
        },
      });

      expect(parcel.isWaitingDriver, isFalse);
      expect(parcel.driverRequest?.isExpired, isTrue);
      expect(parcel.canChooseDriver, isTrue);
    });

    test('Parcel ne propose plus le choix après affectation', () {
      final parcel = Parcel.fromJson({
        'id': 'par-1',
        'reference': 'COL-001',
        'status': 'assigned',
        'driver': {'id': 'drv-2', 'name': 'Boris', 'phone': '+22990000000'},
      });

      expect(parcel.canChooseDriver, isFalse);
      expect(parcel.driver?.phone, '+22990000000');
    });
  });
}
