import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/models/delivery_tracking.dart';

void main() {
  test('DeliveryTrackingSnapshot : positions, distances et ETA', () {
    final snapshot = DeliveryTrackingSnapshot.fromJson({
      'active': true,
      'status': 'in_delivery',
      'points': {
        'client': {
          'role': 'client',
          'latitude': 6.34,
          'longitude': 2.41,
          'label': 'Client',
        },
        'shop': {
          'role': 'shop',
          'latitude': 6.35,
          'longitude': 2.42,
        },
        'driver': {
          'role': 'driver',
          'latitude': 6.36,
          'longitude': 2.43,
        },
      },
      'distances': {
        'straight_km': {'client_driver': 1.42, 'shop_client': null},
        'road_m': 2350,
        'road_provider': 'osrm',
        'road_duration_s': 510,
      },
      'eta': {
        'seconds': 510,
        'minutes': 9,
        'source': 'road',
        'provider': 'osrm',
        'available': true,
      },
      'legacy_position': {
        'latitude': 6.36,
        'longitude': 2.43,
        'accuracy_m': 30,
      },
    });

    expect(snapshot.active, isTrue);
    expect(snapshot.status, 'in_delivery');
    expect(snapshot.points.keys, ['client', 'shop', 'driver']);
    expect(snapshot.pointLocation('driver')?.latitude, 6.36);
    expect(snapshot.point('client')?.label, 'Client');
    expect(snapshot.pointLocation('shop')?.longitude, 2.42);
    expect(snapshot.straightKm['client_driver'], 1.42);
    expect(snapshot.straightKm['shop_client'], isNull);
    expect(snapshot.roadDistanceM, 2350);
    expect(snapshot.roadProvider, 'osrm');
    expect(snapshot.roadDurationS, 510);
    expect(snapshot.etaSeconds, 510);
    expect(snapshot.etaMinutes, 9);
    expect(snapshot.etaAvailable, isTrue);
    expect(snapshot.legacyPosition?['accuracy_m'], 30);
    expect(snapshot.point('unknown'), isNull);
  });

  test('DeliveryTrackingSnapshot : mission terminée sans positions', () {
    final snapshot = DeliveryTrackingSnapshot.fromJson({
      'active': false,
      'status': 'delivered',
      'points': const {},
      'distances': const {'straight_km': {}},
      'eta': const {'available': false},
    });

    expect(snapshot.active, isFalse);
    expect(snapshot.status, 'delivered');
    expect(snapshot.points, isEmpty);
    expect(snapshot.roadDistanceM, isNull);
    expect(snapshot.etaAvailable, isFalse);
    expect(snapshot.legacyPosition, isNull);
  });
}
