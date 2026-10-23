import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/driver/parcels/parcels_tab_screen.dart';

class _NoopTokenStore implements TokenStore {
  @override
  Future<String?> readToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> write(Map<String, dynamic> authPayload) async {}

  @override
  Future<void> clear() async {}
}

const _inDeliveryParcel = {
  'id': 'r1',
  'reference': 'COL-001',
  'status': 'in_delivery',
  'payment_method': 'mobile_money',
  'delivery_fee': 500,
  'partner_amount': 400,
  'pickup': {'label': 'Depot', 'latitude': 6.36, 'longitude': 2.42},
  'dropoff': {'label': 'Client', 'latitude': 6.37, 'longitude': 2.43},
};

MockClient _mockBackend({required List<Map<String, dynamic>> captured}) {
  return MockClient((request) async {
    final json = {'content-type': 'application/json'};
    final path = request.url.path;

    if (request.method == 'POST' &&
        path.endsWith('/driver/me/parcels/r1/deliver')) {
      captured.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode({
          'data': {..._inDeliveryParcel, 'status': 'delivered'},
        }),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/driver/me/parcels/offers')) {
      return http.Response(jsonEncode({'data': const []}), 200, headers: json);
    }
    if (path.endsWith('/driver/me/parcels')) {
      return http.Response(
        jsonEncode({
          'data': [_inDeliveryParcel],
        }),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/me/notifications')) {
      return http.Response(jsonEncode({'data': const []}), 200, headers: json);
    }
    return http.Response(
      jsonEncode({'message': 'Not found'}),
      404,
      headers: json,
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  List<Map<String, dynamic>> captured,
) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(captured: captured),
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(home: DriverParcelsScreen(marketplace: MarketplaceApi(api))),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('la livraison d\'un colis exige le code de confirmation', (
    tester,
  ) async {
    final captured = <Map<String, dynamic>>[];
    await _pump(tester, captured);

    await tester.tap(find.text('Marquer comme livré'));
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Code de confirmation'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);

    final confirm = find.widgetWithText(FilledButton, 'Confirmer');
    await tester.tap(confirm);
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(captured, isEmpty);

    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '123456');
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(captured, hasLength(1));
    expect(captured.single['proof_code'], '123456');
    expect(find.byType(AlertDialog), findsNothing);
  });
}
