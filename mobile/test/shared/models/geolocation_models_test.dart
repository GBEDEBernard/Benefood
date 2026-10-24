import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/models/address.dart';
import 'package:beninfood/shared/models/vendor.dart';

void main() {
  test('address exposes a pinned position and recipient phone', () {
    final address = Address.fromJson({
      'id': 'addr-1',
      'full_address': 'Rue 12, Cadjèhoun',
      'landmark': 'Face à la pharmacie',
      'contact_phone': '+22997000123',
      'latitude': 6.3654321,
      'longitude': 2.3912345,
      'city': 'Cotonou',
    });

    expect(address.hasCoordinates, isTrue);
    expect(address.contactPhone, '+22997000123');
    expect(address.latitude, 6.3654321);
    expect(address.longitude, 2.3912345);
  });

  test('address without GPS is flagged as incomplete', () {
    final address = Address.fromJson({
      'id': 'addr-2',
      'full_address': 'Adresse historique',
    });

    expect(address.hasCoordinates, isFalse);
  });

  test('vendor parses shop and pickup coordinates', () {
    final vendor = Vendor.fromJson({
      'id': 'vendor-1',
      'business_name': 'Chez Awa',
      'latitude': 6.3684,
      'longitude': 2.4221,
      'pickup_latitude': 6.3700,
      'pickup_longitude': 2.4250,
    });

    expect(vendor.latitude, 6.3684);
    expect(vendor.longitude, 2.4221);
    expect(vendor.pickupLatitude, 6.3700);
    expect(vendor.pickupLongitude, 2.4250);
  });
}
