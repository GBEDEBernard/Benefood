import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/parcels/parcel_detail_screen.dart';

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
  'id': 'p1',
  'reference': 'COL-001',
  'status': 'in_delivery',
  'payment_method': 'mobile_money',
  'payment_status': 'confirmed',
  'created_at': '2026-10-20T09:00:00Z',
  'payment': {
    'id': 'pay-p1',
    'reference': 'PAY-P1',
    'status': 'confirmed',
    'amount': 650,
    'paid_at': '2026-10-20T09:01:00Z',
  },
  'delivery_fee': 500,
  'creation_fee': 150,
  'total_amount': 650,
  'partner_amount': 400,
  'commission_amount': 100,
  'pickup': {'label': 'Depot', 'latitude': 6.36, 'longitude': 2.42},
  'dropoff': {'label': 'Client', 'latitude': 6.37, 'longitude': 2.43},
  'driver': {'id': 'd1', 'name': 'Ancien livreur'},
  'position': {'latitude': 6.36, 'longitude': 2.43, 'age_seconds': 5},
  'open_incident': {'id': 'i1', 'type': 'breakdown', 'message': 'Pneu crevé'},
  'handover_required': false,
  'reassignment_count': 0,
};

MockClient _backend({
  required List<String> calls,
  required List<Map<String, dynamic>> bodies,
}) {
  return MockClient((request) async {
    final headers = {'content-type': 'application/json'};
    final path = request.url.path;

    if (request.method == 'POST' &&
        path.endsWith('/parcels/p1/replacement-drivers')) {
      calls.add(path);
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode({
          'data': {
            'drivers': [
              {
                'id': 'd2',
                'name': 'Boris',
                'distance_to_pickup_km': 1.2,
                'eta_to_pickup_s': 300,
              },
            ],
          },
        }),
        200,
        headers: headers,
      );
    }
    if (request.method == 'POST' && path.endsWith('/parcels/p1/reassign')) {
      calls.add(path);
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode({
          'data': {'handover_code': 'XYZ789'},
        }),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/parcels/p1')) {
      return http.Response(
        jsonEncode({'data': _parcel}),
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
}) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _backend(calls: calls, bodies: bodies),
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: ParcelDetailScreen(
        marketplace: MarketplaceApi(api),
        parcelId: 'p1',
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('le client remplace le livreur après un incident', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calls = <String>[];
    final bodies = <Map<String, dynamic>>[];
    await _pump(tester, calls: calls, bodies: bodies);

    expect(find.text('Incident signalé'), findsOneWidget);
    expect(find.text('Pneu crevé'), findsOneWidget);
    expect(find.textContaining('Créé le'), findsOneWidget);
    expect(find.textContaining('Payé le'), findsOneWidget);

    await tester.ensureVisible(find.text('Changer de livreur'));
    await tester.tap(find.text('Changer de livreur'));
    await tester.pump();

    expect(find.text('Que s\'est-il passé ? *'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Livreur injoignable');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Choisir le nouveau livreur'), findsOneWidget);
    await tester.tap(find.text('Boris'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(calls, [
      endsWith('/parcels/p1/replacement-drivers'),
      endsWith('/parcels/p1/reassign'),
    ]);
    expect(bodies.first['latitude'], 6.36);
    expect(bodies.first['longitude'], 2.43);
    expect(bodies.last['driver_profile_id'], 'd2');
    expect(bodies.last['reason'], 'Livreur injoignable');

    expect(find.text('Nouveau livreur affecté'), findsOneWidget);
    expect(find.text('XYZ789'), findsOneWidget);
  });
}
