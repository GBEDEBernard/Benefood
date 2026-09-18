import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/core/services/location_service.dart';

void main() {
  group('LocateResult (J179)', () {
    test('success conserve la position et indique isSuccess', () {
      const result = LocateResult.success(GeoResult(latitude: 6.37, longitude: 2.39));

      expect(result.isSuccess, isTrue);
      expect(result.failure, isNull);
      expect(result.geo?.latitude, 6.37);
    });

    test('failure conserve la cause', () {
      const result = LocateResult.failure(LocationFailure.permissionDenied);

      expect(result.isSuccess, isFalse);
      expect(result.geo, isNull);
      expect(result.failure, LocationFailure.permissionDenied);
    });

    test('none ne signale ni succès ni échec', () {
      const result = LocateResult.none;

      expect(result.isSuccess, isFalse);
      expect(result.geo, isNull);
      expect(result.failure, isNull);
    });
  });
}