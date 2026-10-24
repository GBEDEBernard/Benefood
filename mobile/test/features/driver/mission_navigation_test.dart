import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/driver/missions/mission_navigation_screen.dart';
import 'package:beninfood/shared/models/driver_mission.dart';
import 'package:beninfood/shared/models/geo_point.dart';

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

class _Backend {
  final List<http.Request> requests = [];

  MockClient get client => MockClient((request) async {
    requests.add(request);
    const headers = {'content-type': 'application/json'};
    final path = request.url.path;

    if (path.endsWith('/start-pickup')) {
      return _ok(_parcel(status: 'en_route_pickup'), headers);
    }
    if (path.endsWith('/pickup')) {
      return _ok(_parcel(status: 'picked_up'), headers);
    }
    if (path.endsWith('/start')) {
      return _ok(_parcel(status: 'in_delivery'), headers);
    }
    if (path.endsWith('/deliver')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['proof_code'] != '654321') {
        return http.Response(
          jsonEncode({'message': 'Code de livraison invalide.'}),
          422,
          headers: headers,
        );
      }
      return _ok(_parcel(status: 'delivered'), headers);
    }
    if (path.endsWith('/availability/location')) {
      return http.Response(jsonEncode({'data': {}}), 200, headers: headers);
    }
    if (path.contains('/route')) {
      return http.Response(
        jsonEncode({
          'data': {
            'provider': 'straight',
            'distance_m': 1200,
            'duration_s': 240,
            'geometry': [
              [6.3654, 2.4183],
              [6.3501, 2.4002],
            ],
            'steps': [],
          },
        }),
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

  http.Response _ok(Map<String, dynamic> data, Map<String, String> headers) =>
      http.Response(jsonEncode({'data': data}), 200, headers: headers);
}

Map<String, dynamic> _parcel({required String status}) => {
  'id': 'p-1',
  'reference': 'COL-100',
  'status': status,
  'description': 'Documents',
  'delivery_fee': 900,
  'partner_amount': 700,
  'pickup': {
    'label': 'Dépôt',
    'address_text': 'Rue 12',
    'city': 'Cotonou',
    'latitude': 6.3654,
    'longitude': 2.4183,
  },
  'dropoff': {
    'label': 'Maison',
    'address_text': 'Fidjrossè',
    'city': 'Cotonou',
    'contact_name': 'Aline',
    'contact_phone': '+22990000003',
    'latitude': 6.3501,
    'longitude': 2.4002,
  },
};

DriverMission _mission({
  required DriverMissionKind kind,
  required String status,
}) {
  return DriverMission(
    id: kind == DriverMissionKind.order ? 'd-1' : 'p-1',
    kind: kind,
    reference: kind == DriverMissionKind.order ? 'CMD-100' : 'COL-100',
    status: status,
    pickup: const DriverMissionStop(
      title: 'Chez Awa',
      address: 'Rue 12, Cotonou',
      contactName: 'Awa',
      contactPhone: '+22990000001',
      point: GeoPoint(6.3654, 2.4183),
    ),
    dropoff: const DriverMissionStop(
      title: 'Aline',
      address: 'Fidjrossè, Cotonou',
      contactName: 'Aline',
      contactPhone: '+22990000003',
      point: GeoPoint(6.3501, 2.4002),
    ),
    items: kind == DriverMissionKind.order
        ? const [DriverMissionItem(name: 'Poulet braisé', quantity: 2)]
        : const [],
    earnings: 700,
    clientFee: 900,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required DriverMission mission,
  required _Backend backend,
}) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: backend.client,
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: MissionNavigationScreen(
        marketplace: MarketplaceApi(api),
        mission: mission,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  await tester.pump();
}

void main() {
  testWidgets('course restaurant : collecte puis livraison avec code', (
    tester,
  ) async {
    final backend = _Backend();
    await _pump(
      tester,
      mission: _mission(
        kind: DriverMissionKind.order,
        status: 'en_route_pickup',
      ),
      backend: backend,
    );

    expect(find.text('Je suis arrivé au point de collecte'), findsOneWidget);
    expect(find.text('CMD-100'), findsOneWidget);

    await _tap(tester, 'Je suis arrivé au point de collecte');
    expect(find.text('Confirmer la collecte ?'), findsOneWidget);
    expect(find.text('Poulet braisé'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Démarrer la livraison'), findsOneWidget);
    expect(
      backend.requests.any(
        (r) => r.method == 'POST' && r.url.path.endsWith('/d-1/pickup'),
      ),
      isTrue,
    );

    await _tap(tester, 'Démarrer la livraison');
    expect(find.text('Saisir le code de livraison'), findsOneWidget);
    expect(
      backend.requests.any(
        (r) => r.method == 'POST' && r.url.path.endsWith('/d-1/start'),
      ),
      isTrue,
    );

    await _tap(tester, 'Saisir le code de livraison');
    expect(find.text('Code de livraison'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Code de livraison invalide.'), findsOneWidget);
    expect(find.text('Code de livraison'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '654321');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Mission terminée'), findsOneWidget);
    expect(find.text('Terminer la mission'), findsOneWidget);
    final deliver = backend.requests.lastWhere(
      (r) => r.url.path.endsWith('/d-1/deliver'),
    );
    expect(jsonDecode(deliver.body)['proof_code'], '654321');

    await _dispose(tester);
  });

  testWidgets('colis : confirmation, départ livraison et code valide', (
    tester,
  ) async {
    final backend = _Backend();
    await _pump(
      tester,
      mission: _mission(
        kind: DriverMissionKind.parcel,
        status: 'en_route_pickup',
      ),
      backend: backend,
    );

    expect(find.text('Je suis arrivé au point de collecte'), findsOneWidget);
    await _tap(tester, 'Je suis arrivé au point de collecte');
    expect(find.text('Confirmer la collecte du colis ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Démarrer la livraison'), findsOneWidget);
    expect(
      backend.requests.any(
        (r) => r.method == 'POST' && r.url.path.endsWith('/p-1/pickup'),
      ),
      isTrue,
    );

    await _tap(tester, 'Démarrer la livraison');
    expect(find.text('Saisir le code de livraison'), findsOneWidget);
    expect(
      backend.requests.any(
        (r) => r.method == 'POST' && r.url.path.endsWith('/p-1/start'),
      ),
      isTrue,
    );

    await _tap(tester, 'Saisir le code de livraison');
    await tester.enterText(find.byType(TextField), '654321');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Mission terminée'), findsOneWidget);
    expect(
      backend.requests.any(
        (r) => r.method == 'POST' && r.url.path.endsWith('/p-1/deliver'),
      ),
      isTrue,
    );

    await _dispose(tester);
  });

  testWidgets('mission assignée : démarrage de la collecte', (tester) async {
    final backend = _Backend();
    await _pump(
      tester,
      mission: _mission(kind: DriverMissionKind.order, status: 'assigned'),
      backend: backend,
    );

    expect(find.text('Démarrer la récupération'), findsOneWidget);
    await _tap(tester, 'Démarrer la récupération');

    expect(find.text('Je suis arrivé au point de collecte'), findsOneWidget);
    expect(
      backend.requests.any(
        (r) => r.method == 'POST' && r.url.path.endsWith('/d-1/start-pickup'),
      ),
      isTrue,
    );

    await _dispose(tester);
  });
}
