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
        'requested_radius_km': 3,
        'max_radius_km': 15,
        'expanded': true,
        'trip': {'distance_km': 2.8, 'duration_s': 720},
        'diagnostics': {
          'online_drivers': 4,
          'with_position': 2,
          'fresh_position': 0,
          'stale_position': 1,
          'without_position': 1,
          'within_max_radius': 0,
          'max_radius_km': 15,
          'location_max_age_s': 300,
        },
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
      expect(page.requestedRadiusKm, 3);
      expect(page.expanded, isTrue);
      expect(page.tripDistanceKm, 2.8);
      expect(page.tripDurationSeconds, 720);
      expect(page.diagnostics.onlineDrivers, 4);
      expect(page.diagnostics.freshPosition, 0);
      expect(page.diagnostics.stalePosition, 1);
      expect(page.diagnostics.withoutPosition, 1);
      expect(page.diagnostics.hasPositionIssue, isTrue);
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

    test('diagnostics absents : aucun problème de position signalé', () {
      final page = DriverSelectionPage.fromJson({'drivers': []});

      expect(page.diagnostics.onlineDrivers, 0);
      expect(page.diagnostics.hasPositionIssue, isFalse);
      expect(page.tripDistanceKm, isNull);
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

    test('Order réautorise le choix après refus malgré l\'approche payée', () {
      final order = Order.fromJson({
        'id': 'ord-4',
        'reference': 'REF-004',
        'status': 'preparing',
        'payment_status': 'confirmed',
        'items': [],
        'subtotal': 1000,
        'delivery_fee': 500,
        'approach_fee': 350,
        'approach_payment_status': 'confirmed',
        'approach_driver_id': 'drv-3',
        'total': 1850,
        'driver_request': {
          'id': 'req-4',
          'status': 'refused',
          'refusal_reason': 'Trop loin',
          'driver': {'id': 'drv-3', 'name': 'Boris'},
        },
      });

      expect(order.approachIsPaid, isTrue);
      expect(order.driverRequest?.isRefused, isTrue);
      expect(order.canChooseDriver, isTrue);
    });

    test('Order parse les champs d\'approche et bloque un nouveau choix', () {
      final order = Order.fromJson({
        'id': 'ord-2',
        'reference': 'REF-002',
        'status': 'paid',
        'payment_status': 'confirmed',
        'items': [],
        'subtotal': 1000,
        'delivery_fee': 500,
        'approach_fee': 350,
        'approach_distance_km': 7,
        'approach_payment_method': 'cash',
        'approach_payment_status': 'pending',
        'approach_driver_id': 'drv-3',
        'total': 1850,
        'approach_payment': {
          'id': 'pay-2',
          'reference': 'PAY-002',
          'amount': 350,
          'status': 'pending',
        },
      });

      expect(order.approachFee, 350);
      expect(order.approachDistanceKm, 7);
      expect(order.approachPaymentMethod, 'cash');
      expect(order.approachIsPaid, isFalse);
      expect(order.hasApproachFee, isTrue);
      expect(order.approachDriverId, 'drv-3');
      expect(order.approachPayment?.amount, 350);
      expect(order.deliveryTotal, 850);
      expect(order.canChooseDriver, isFalse);
    });

    test(
      'Order autorise le choix quand aucun livreur n\'est encore retenu',
      () {
        final order = Order.fromJson({
          'id': 'ord-3',
          'reference': 'REF-003',
          'status': 'paid',
          'payment_status': 'confirmed',
          'items': [],
          'subtotal': 1000,
          'delivery_fee': 500,
          'total': 1500,
        });

        expect(order.approachDriverId, isNull);
        expect(order.canChooseDriver, isTrue);
      },
    );

    test('OrderDelivery expose un incident livreur ouvert', () {
      final order = Order.fromJson({
        'id': 'ord-5',
        'reference': 'REF-005',
        'status': 'assigned',
        'payment_status': 'confirmed',
        'items': [],
        'subtotal': 1000,
        'delivery_fee': 500,
        'total': 1500,
        'delivery': {
          'id': 'del-5',
          'status': 'en_route_pickup',
          'driver': {'id': 'drv-5', 'name': 'Cédric'},
          'open_incident': {
            'id': 'inc-5',
            'type': 'other',
            'message': 'Panne de moto',
          },
        },
      });

      expect(order.delivery?.hasOpenIncident, isTrue);
      expect(order.delivery?.status, 'en_route_pickup');
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

    test('Parcel expose les frais d\'approche et leur paiement', () {
      final parcel = Parcel.fromJson({
        'id': 'par-2',
        'reference': 'COL-002',
        'status': 'paid',
        'delivery_fee': 1000,
        'creation_fee': 200,
        'approach_fee': 350,
        'approach_distance_km': 7,
        'approach_payment_method': 'cash',
        'approach_payment_status': 'pending',
        'approach_driver_id': 'drv-3',
        'approach_payment': {
          'id': 'pay-3',
          'amount': 350,
          'status': 'pending',
          'purpose': 'parcel_approach',
        },
      });

      expect(parcel.approachFee, 350);
      expect(parcel.approachDistanceKm, 7);
      expect(parcel.approachPaymentMethod, 'cash');
      expect(parcel.approachIsPaid, isFalse);
      expect(parcel.hasApproachFee, isTrue);
      expect(parcel.approachDriverId, 'drv-3');
      expect(parcel.approachPayment?.amount, 350);
      expect(parcel.totalAmount, 1550);
    });

    test('Parcel expose un incident ouvert et le code de remise', () {
      final parcel = Parcel.fromJson({
        'id': 'par-3',
        'reference': 'COL-003',
        'status': 'in_delivery',
        'driver': {'id': 'drv-3', 'name': 'Boris'},
        'open_incident': {
          'id': 'inc-3',
          'type': 'breakdown',
          'message': 'Pneu crevé',
        },
        'handover_required': true,
        'handover_code': 'ABC123',
        'reassignment_count': 1,
      });

      expect(parcel.hasOpenIncident, isTrue);
      expect(parcel.openIncident?.message, 'Pneu crevé');
      expect(parcel.handoverRequired, isTrue);
      expect(parcel.handoverCode, 'ABC123');
      expect(parcel.reassignmentCount, 1);
      expect(parcel.canReassign, isFalse);
    });

    test(
      'Parcel autorise le remplacement après incident sans remise en attente',
      () {
        final parcel = Parcel.fromJson({
          'id': 'par-4',
          'reference': 'COL-004',
          'status': 'picked_up',
          'driver': {'id': 'drv-4', 'name': 'Cédric'},
          'open_incident': {
            'id': 'inc-4',
            'type': 'breakdown',
            'message': 'Panne',
          },
          'handover_required': false,
        });

        expect(parcel.canReassign, isTrue);
      },
    );

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
