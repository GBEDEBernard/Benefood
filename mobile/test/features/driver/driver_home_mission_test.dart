import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/driver/missions/driver_home_screen.dart';

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

MockClient _backend() {
  const status = {
    'profile': {
      'status': 'active',
      'available': true,
      'vehicle': 'Moto TVN-4521',
      'rating': 4.7,
    },
    'documents': [],
  };
  const deliveries = [
    {
      'id': 'd-1',
      'status': 'assigned',
      'fee': 900,
      'driver_earnings': 700,
      'created_at': '2026-10-22T09:00:00Z',
      'vendor': {
        'id': 'v-1',
        'business_name': 'Chez Awa',
        'type': 'restaurant',
        'address': 'Rue 12',
        'city': 'Cotonou',
        'phone': '+22990000001',
        'latitude': 6.3654,
        'longitude': 2.4183,
      },
      'order': {
        'id': 'o-1',
        'reference': 'CMD-100',
        'address': {
          'full_address': 'Fidjrossè',
          'city': 'Cotonou',
          'latitude': 6.3501,
          'longitude': 2.4002,
        },
        'client': {'id': 'u-1', 'name': 'Koffi', 'phone': '+22990000002'},
        'items': [
          {'id': 'i-1', 'name': 'Poulet braisé', 'quantity': 2},
        ],
      },
    },
  ];
  const parcels = [
    {
      'id': 'p-1',
      'reference': 'COL-100',
      'status': 'picked_up',
      'description': 'Documents',
      'distance_km': 4.2,
      'delivery_fee': 900,
      'partner_amount': 700,
      'created_at': '2026-10-22T10:00:00Z',
      'pickup': {
        'label': 'Dépôt',
        'address_text': 'Rue 8',
        'city': 'Cotonou',
        'latitude': 6.3654,
        'longitude': 2.4183,
      },
      'dropoff': {
        'label': 'Maison',
        'address_text': 'Fidjrossè',
        'city': 'Cotonou',
        'contact_name': 'Aline',
        'latitude': 6.3501,
        'longitude': 2.4002,
      },
      'sender': {'id': 'u-9', 'name': 'Sylvain', 'phone': '+22990000004'},
    },
  ];
  const wallet = {'available_balance': 3200, 'pending_balance': 500};

  return MockClient((request) async {
    const headers = {'content-type': 'application/json'};
    final path = request.url.path;
    if (path.endsWith('/driver/me/status')) {
      return http.Response(jsonEncode({'data': status}), 200, headers: headers);
    }
    if (path.endsWith('/driver/me/deliveries')) {
      return http.Response(
        jsonEncode({'data': deliveries}),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/driver/me/parcels')) {
      return http.Response(
        jsonEncode({'data': parcels}),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/driver/me/wallet')) {
      return http.Response(jsonEncode({'data': wallet}), 200, headers: headers);
    }
    return http.Response(
      jsonEncode({'message': 'Not found'}),
      404,
      headers: headers,
    );
  });
}

void main() {
  testWidgets('accueil : commandes et colis unifiés, ouverture du détail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final api = ApiClient(
      tokenStore: _NoopTokenStore(),
      httpClient: _backend(),
      baseUrl: 'http://api.test',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DriverHomeScreen(
          marketplace: MarketplaceApi(api),
          userName: 'Awa',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Bonjour, Awa'), findsOneWidget);
    expect(find.text('2 missions en cours'), findsOneWidget);
    expect(find.text('Chez Awa'), findsOneWidget);
    expect(find.text('Sylvain'), findsOneWidget);
    expect(find.text('CMD-100'), findsOneWidget);
    expect(find.text('COL-100'), findsOneWidget);
    expect(find.text('COMMANDE'), findsOneWidget);
    expect(find.text('COLIS'), findsOneWidget);
    expect(find.text('Démarrer la récupération'), findsOneWidget);
    expect(find.text('Démarrer la livraison'), findsOneWidget);
    expect(find.text('3 200'), findsOneWidget);

    await tester.ensureVisible(find.text('Démarrer la récupération'));
    await tester.pump();
    await tester.tap(find.text('Démarrer la récupération'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Progression'), findsOneWidget);
    expect(find.text('Poulet braisé'), findsOneWidget);
    expect(find.text('Démarrer la récupération'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
  });
}
