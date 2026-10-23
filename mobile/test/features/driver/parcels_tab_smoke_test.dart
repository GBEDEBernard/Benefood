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

/// Backend de test : une course assignée + une offre de colis, avec
/// coordonnées (la carte s'affiche) et une action bouton dans le pied de carte.
MockClient _mockBackend() {
  const runs = [
    {
      'id': 'r1',
      'reference': 'COL-001',
      'status': 'assigned',
      'payment_method': 'mobile_money',
      'delivery_fee': 500,
      'partner_amount': 400,
      'pickup': {'label': 'Depot', 'latitude': 6.36, 'longitude': 2.42},
      'dropoff': {'label': 'Client', 'latitude': 6.37, 'longitude': 2.43},
    },
  ];
  const offers = [
    {
      'id': 'p1',
      'reference': 'COL-002',
      'status': 'paid',
      'payment_method': 'mobile_money',
      'description': 'Un colis à livrer',
      'delivery_fee': 600,
      'partner_amount': 500,
      'pickup': {'label': 'Depot', 'latitude': 6.36, 'longitude': 2.42},
      'dropoff': {'label': 'Client', 'latitude': 6.37, 'longitude': 2.43},
    },
  ];

  return MockClient((request) async {
    final json = {'content-type': 'application/json'};
    final path = request.url.path;
    if (path.endsWith('/driver/me/parcels/offers')) {
      return http.Response(jsonEncode({'data': offers}), 200, headers: json);
    }
    if (path.endsWith('/driver/me/parcels')) {
      return http.Response(jsonEncode({'data': runs}), 200, headers: json);
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

Future<void> _pump(WidgetTester tester) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(),
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(home: DriverParcelsScreen(marketplace: MarketplaceApi(api))),
  );
  await tester.pump();
  // La carte (flutter_map) anime son fond de tuiles : on évite pumpAndSettle.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('onglet colis : courses + offres avec carte et boutons', (
    tester,
  ) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Mes courses colis'), findsOneWidget);
    expect(find.text('Offres de colis'), findsOneWidget);
    expect(find.text('COL-001'), findsOneWidget);
    expect(find.text('COL-002'), findsOneWidget);
    // Le bouton pleine largeur du pied de carte ne force plus de largeur
    // infinie dans la `Row`.
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.text('J\'ai récupéré le colis'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Le livreur voit sa part nette, pas le prix de livraison payé par le client.
    expect(find.text('Votre gain'), findsNWidgets(2));
    expect(find.textContaining('400'), findsOneWidget);
    expect(find.textContaining('500'), findsOneWidget);
    expect(find.textContaining('600'), findsNothing);
  });
}
