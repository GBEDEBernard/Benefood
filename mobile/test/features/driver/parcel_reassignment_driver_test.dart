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

const _parcel = {
  'id': 'r1',
  'reference': 'COL-001',
  'status': 'in_delivery',
  'payment_method': 'mobile_money',
  'delivery_fee': 500,
  'partner_amount': 400,
  'pickup': {'label': 'Depot', 'latitude': 6.36, 'longitude': 2.42},
  'dropoff': {'label': 'Client', 'latitude': 6.37, 'longitude': 2.43},
};

MockClient _backend({
  required List<String> calls,
  required List<Map<String, dynamic>> bodies,
  bool handoverRequired = false,
}) {
  return MockClient((request) async {
    final headers = {'content-type': 'application/json'};
    final path = request.url.path;

    if (request.method == 'POST' &&
        (path.endsWith('/handover') || path.endsWith('/incident'))) {
      calls.add(path);
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode({
          'data': {..._parcel},
        }),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/driver/me/parcels/offers')) {
      return http.Response(
        jsonEncode({'data': const []}),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/driver/me/parcels')) {
      return http.Response(
        jsonEncode({
          'data': [
            {..._parcel, 'handover_required': handoverRequired},
          ],
        }),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/me/notifications')) {
      return http.Response(
        jsonEncode({'data': const []}),
        200,
        headers: headers,
      );
    }
    return http.Response(
      jsonEncode({'message': 'Not found'}),
      404,
      headers: headers,
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required List<String> calls,
  required List<Map<String, dynamic>> bodies,
  bool handoverRequired = false,
}) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _backend(
      calls: calls,
      bodies: bodies,
      handoverRequired: handoverRequired,
    ),
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
  testWidgets('le nouveau livreur confirme la remise avec le code client', (
    tester,
  ) async {
    final calls = <String>[];
    final bodies = <Map<String, dynamic>>[];
    await _pump(tester, calls: calls, bodies: bodies, handoverRequired: true);

    await tester.tap(find.text('Confirmer la remise'));
    await tester.pump();

    expect(find.text('Code fourni par l\'expéditeur'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ABC123');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(calls.single, endsWith('/handover'));
    expect(bodies.single['code'], 'ABC123');
  });

  testWidgets('le livreur peut signaler un incident', (tester) async {
    final calls = <String>[];
    final bodies = <Map<String, dynamic>>[];
    await _pump(tester, calls: calls, bodies: bodies);

    await tester.ensureVisible(find.text('Signaler un incident'));
    await tester.tap(find.text('Signaler un incident'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Pneu crevé');
    await tester.tap(find.widgetWithText(FilledButton, 'Envoyer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(calls.single, endsWith('/incident'));
    expect(bodies.single['message'], 'Pneu crevé');
  });
}
