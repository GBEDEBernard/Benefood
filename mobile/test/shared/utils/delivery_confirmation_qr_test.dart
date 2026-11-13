import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/shared/utils/delivery_confirmation_qr.dart';

void main() {
  test('QR order round-trips the order reference and six-digit PIN', () {
    final qr = buildDeliveryConfirmationQr(
      reference: 'CMD-26-1234',
      code: '004218',
    );

    expect(
      parseDeliveryConfirmationQr(qr, expectedReference: 'CMD-26-1234'),
      '004218',
    );
  });

  test('rejects a QR from another order', () {
    final qr = buildDeliveryConfirmationQr(
      reference: 'CMD-26-1234',
      code: '004218',
    );

    expect(
      parseDeliveryConfirmationQr(qr, expectedReference: 'CMD-26-5678'),
      isNull,
    );
  });

  test('rejects invalid codes and unrelated QR payloads', () {
    final invalidCode = buildDeliveryConfirmationQr(
      reference: 'CMD-26-1234',
      code: '12345',
    );

    expect(
      parseDeliveryConfirmationQr(
        invalidCode,
        expectedReference: 'CMD-26-1234',
      ),
      isNull,
    );
    expect(
      parseDeliveryConfirmationQr(
        'https://example.com?code=123456',
        expectedReference: 'CMD-26-1234',
      ),
      isNull,
    );
  });
}
