import 'package:flutter_test/flutter_test.dart';
import 'package:beninfood/shared/models/checkout.dart';

void main() {
  test('parses delivery distance from order summary', () {
    final summary = OrderSummary.fromJson({
      'items': <dynamic>[],
      'subtotal': 2500,
      'delivery_fee': 500,
      'delivery_distance_km': 2.35,
      'total': 3150,
    });

    expect(summary.deliveryDistanceKm, 2.35);
  });

  test('keeps delivery distance optional for older summaries', () {
    final summary = OrderSummary.fromJson({
      'items': <dynamic>[],
      'subtotal': 2500,
      'delivery_fee': 500,
      'total': 3150,
    });

    expect(summary.deliveryDistanceKm, isNull);
  });
}
