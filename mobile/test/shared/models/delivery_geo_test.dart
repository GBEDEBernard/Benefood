import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/models/delivery.dart';
import 'package:beninfood/shared/models/order.dart';

const _addressSnapshot = {
  'label': 'Domicile',
  'full_address': 'Cotonou, quartier Gbédjèy, rue des Fleurs',
  'landmark': null,
  'city': 'Cotonou',
  'area': 'Cotonou Centre',
  'latitude': 6.3668,
  'longitude': 2.4251,
  'zone_id': 'zone-1',
  'notes': 'Livrer avant 20h.',
};

Map<String, dynamic> _delivery(Map<String, dynamic> order, Map<String, dynamic> vendor) => {
      'id': 'del-1',
      'status': 'assigned',
      'fee': 1000,
      'order': order,
      'vendor': vendor,
    };

void main() {
  group('Delivery — géolocalisation de la mission (J162)', () {
    test('expose le point de collecte du vendeur', () {
      final delivery = Delivery.fromJson(_delivery(
        {'id': 'ord-1', 'reference': 'REF-1', 'address': _addressSnapshot},
        {
          'id': 'ven-1',
          'business_name': 'La Boulangerie',
          'address': 'Cotonou, avenue Clozel',
          'city': 'Cotonou',
          'latitude': 6.3703,
          'longitude': 2.3942,
        },
      ));

      expect(delivery.pickupPoint?.latitude, 6.3703);
      expect(delivery.pickupPoint?.longitude, 2.3942);
    });

    test('expose le point de livraison depuis l’address_snapshot', () {
      final delivery = Delivery.fromJson(_delivery(
        {'id': 'ord-1', 'reference': 'REF-1', 'address': _addressSnapshot},
        {'id': 'ven-1', 'latitude': 6.3703, 'longitude': 2.3942},
      ));

      expect(delivery.dropoffPoint?.latitude, 6.3668);
      expect(delivery.dropoffPoint?.longitude, 2.4251);
      expect(delivery.order?.addressSnapshot?.notes, 'Livrer avant 20h.');
    });

    test('affiche une adresse lisible au lieu de l’objet JSON brut', () {
      final delivery = Delivery.fromJson(_delivery(
        {'id': 'ord-1', 'reference': 'REF-1', 'address': _addressSnapshot},
        {'id': 'ven-1', 'latitude': 6.3703, 'longitude': 2.3942},
      ));

      expect(
        delivery.order?.address,
        'Cotonou, quartier Gbédjèy, rue des Fleurs, Cotonou',
      );
    });

    test('reste sans coordonnée si le vendeur n’en a pas', () {
      final delivery = Delivery.fromJson(_delivery(
        {'id': 'ord-1', 'reference': 'REF-1', 'address': _addressSnapshot},
        {'id': 'ven-1', 'business_name': 'Boutique sans GPS'},
      ));

      expect(delivery.pickupPoint, isNull);
      expect(delivery.dropoffPoint, isNotNull);
    });

    test('tolère l’ancienne adresse en chaîne', () {
      final delivery = Delivery.fromJson(_delivery(
        {'id': 'ord-1', 'reference': 'REF-1', 'address': 'Cotonou, Fidjrossè'},
        {'id': 'ven-1', 'latitude': 6.37, 'longitude': 2.39},
      ));

      expect(delivery.order?.address, 'Cotonou, Fidjrossè');
      expect(delivery.dropoffPoint, isNull);
    });
  });

  group('Order — carte de suivi client (J177)', () {
    test('expose la destination et la position du livreur', () {
      final order = Order.fromJson({
        'id': 'ord-1',
        'reference': 'REF-1',
        'status': 'out_for_delivery',
        'payment_status': 'confirmed',
        'items': [],
        'subtotal': 1000,
        'delivery_fee': 1500,
        'total': 2500,
        'delivery_address': _addressSnapshot,
        'delivery': {
          'id': 'del-1',
          'status': 'in_delivery',
          'driver': {'id': 'drv-1', 'name': 'Achille'},
          'position': {
            'latitude': 6.371,
            'longitude': 2.392,
            'last_location_at': '2026-09-18T11:18:28+00:00',
            'distance_km': 0.16,
          },
        },
      });

      expect(order.deliveryAddress, 'Cotonou, quartier Gbédjèy, rue des Fleurs, Cotonou');
      expect(order.dropoffPoint?.latitude, 6.3668);
      expect(order.delivery?.position?.point.longitude, 2.392);
    });

    test('reste sans adresse si le snapshot est vide', () {
      final order = Order.fromJson({
        'id': 'ord-1',
        'reference': 'REF-1',
        'status': 'delivered',
        'payment_status': 'confirmed',
        'items': [],
        'subtotal': 1000,
        'delivery_fee': 1500,
        'total': 2500,
      });

      expect(order.deliveryAddress, isNull);
      expect(order.dropoffPoint, isNull);
    });
  });
}