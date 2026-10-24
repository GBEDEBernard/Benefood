import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/models/delivery.dart';
import 'package:beninfood/shared/models/driver_mission.dart';
import 'package:beninfood/shared/models/parcel.dart';

Delivery _delivery({String status = 'en_route_pickup'}) {
  return Delivery.fromJson({
    'id': 'd-1',
    'status': status,
    'fee': 700,
    'driver_earnings': 550,
    'created_at': '2026-10-20T09:00:00Z',
    'vendor': {
      'id': 'v-1',
      'business_name': 'Chez Awa',
      'type': 'restaurant',
      'logo_url': 'https://cdn.test/logo.jpg',
      'address': 'Rue 12',
      'city': 'Cotonou',
      'phone': '+22990000001',
      'latitude': 6.3654,
      'longitude': 2.4183,
    },
    'order': {
      'id': 'o-1',
      'reference': 'CMD-9001',
      'address': {
        'full_address': 'Fidjrossè',
        'city': 'Cotonou',
        'landmark': 'Près de la pharmacie',
        'latitude': 6.3501,
        'longitude': 2.4002,
      },
      'client': {
        'id': 'u-1',
        'name': 'Koffi',
        'phone': '+22990000002',
        'avatar_url': 'https://cdn.test/koffi.jpg',
      },
      'items': [
        {
          'id': 'i-1',
          'name': 'Poulet braisé',
          'quantity': 2,
          'image_url': 'https://cdn.test/poulet.jpg',
        },
      ],
    },
  });
}

Parcel _parcel({
  String status = 'picked_up',
  Map<String, dynamic>? pickup,
  String? description,
}) {
  return Parcel.fromJson({
    'id': 'p-1',
    'reference': 'COL-9001',
    'status': status,
    'description': description,
    'distance_km': 4.2,
    'delivery_fee': 900,
    'partner_amount': 700,
    'created_at': '2026-10-21T09:00:00Z',
    'pickup':
        pickup ??
        {
          'label': 'Boutique',
          'address_text': 'Rue 12',
          'city': 'Cotonou',
          'latitude': 6.3654,
          'longitude': 2.4183,
        },
    'dropoff': {
      'label': 'Maison',
      'address_text': 'Fidjrossè',
      'city': 'Cotonou',
      'landmark': 'Face à l’école',
      'latitude': 6.3501,
      'longitude': 2.4002,
      'contact_name': 'Aline',
      'contact_phone': '+22990000003',
    },
    'sender': {
      'id': 'u-9',
      'name': 'Sylvain',
      'phone': '+22990000004',
      'avatar_url': 'https://cdn.test/sylvain.jpg',
    },
  });
}

void main() {
  test('mission commande : vendeur, adresse, articles et étapes', () {
    final mission = DriverMission.fromDelivery(_delivery());

    expect(mission.kind, DriverMissionKind.order);
    expect(mission.isActive, isTrue);
    expect(mission.isPickupPhase, isTrue);
    expect(mission.currentStep, 1);
    expect(mission.canStartPickup, isFalse);
    expect(mission.canStartDelivery, isFalse);
    expect(mission.actionLabel, 'Reprendre la navigation');
    expect(mission.title, 'Chez Awa');
    expect(mission.kindLabel, 'Commande restaurant');
    expect(mission.imageUrl, 'https://cdn.test/logo.jpg');
    expect(mission.pickup.title, 'Chez Awa');
    expect(mission.pickup.address, contains('Rue 12'));
    expect(mission.pickup.imageUrl, 'https://cdn.test/logo.jpg');
    expect(mission.dropoff.title, 'Koffi');
    expect(mission.dropoff.imageUrl, 'https://cdn.test/koffi.jpg');
    expect(mission.dropoff.displayAddress, contains('Près de la pharmacie'));
    expect(mission.items.single.name, 'Poulet braisé');
    expect(mission.itemCount, 2);
    expect(mission.earnings, 550);
    expect(mission.clientFee, 700);

    final assigned = mission.copyWithStatus('assigned');
    expect(assigned.currentStep, 0);
    expect(assigned.canStartPickup, isTrue);

    final delivered = mission.copyWithStatus('delivered');
    expect(delivered.currentStep, 4);
    expect(delivered.isActive, isFalse);
    expect(delivered.isDelivered, isTrue);
  });

  test('mission colis : contacts terrain, expéditeur et rémunération', () {
    final mission = DriverMission.fromParcel(
      _parcel(
        pickup: {
          'label': 'Dépôt',
          'address_text': 'Rue 8',
          'city': 'Cotonou',
          'latitude': 6.3654,
          'longitude': 2.4183,
          'contact_name': 'Awa',
          'contact_phone': '+22990000005',
        },
        description: 'Documents administratifs',
      ),
    );

    expect(mission.kind, DriverMissionKind.parcel);
    expect(mission.isDropoffPhase, isTrue);
    expect(mission.currentStep, 2);
    expect(mission.canStartDelivery, isTrue);
    expect(mission.title, 'Awa');
    expect(mission.pickup.contactName, 'Awa');
    expect(mission.pickup.contactPhone, '+22990000005');
    expect(mission.pickup.imageUrl, 'https://cdn.test/sylvain.jpg');
    expect(mission.dropoff.contactName, 'Aline');
    expect(mission.dropoff.contactPhone, '+22990000003');
    expect(mission.dropoff.note, 'Face à l’école');
    expect(mission.description, 'Documents administratifs');
    expect(mission.distanceKm, 4.2);
    expect(mission.earnings, 700);
    expect(mission.clientFee, 900);
  });

  test('mission colis : repli sur l’expéditeur quand le contact manque', () {
    final mission = DriverMission.fromParcel(_parcel(status: 'assigned'));

    expect(mission.isPickupPhase, isTrue);
    expect(mission.canStartPickup, isTrue);
    expect(mission.pickup.contactName, 'Sylvain');
    expect(mission.pickup.contactPhone, '+22990000004');
    expect(mission.title, 'Sylvain');
  });

  test('parcel address sérialise les contacts dans les snapshots', () {
    final json = _parcel().dropoff!.toJson();

    expect(json['contact_name'], 'Aline');
    expect(json['contact_phone'], '+22990000003');
    expect(json['landmark'], 'Face à l’école');
  });
}
