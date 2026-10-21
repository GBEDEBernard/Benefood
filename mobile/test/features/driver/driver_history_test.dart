import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/driver/history/driver_history_screen.dart';

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

/// Backend de test : une mission livrée (détaillée) + une annulée.
MockClient _mockBackend() {
  const delivered = {
    'id': 'd1',
    'status': 'delivered',
    'fee': 500,
    'partner_amount': 400,
    'proof_code': 'AB-42',
    'created_at': '2026-10-06T10:00:00Z',
    'assigned_at': '2026-10-06T10:05:00Z',
    'picked_up_at': '2026-10-06T10:30:00Z',
    'delivered_at': '2026-10-06T11:15:00Z',
    'order': {
      'id': 'o1',
      'reference': 'CMD-2026-018',
      'total': 12000,
      'delivery_fee': 500,
      'address': 'Quartier Ganhi, Cotonou',
      'client': {'id': 'c1', 'name': 'Aïcha K.', 'phone': '+228 90 55 44 33'},
      'items': [
        {
          'id': 'i1',
          'name': 'Riz cantonais',
          'quantity': 2,
        },
      ],
    },
    'vendor': {
      'id': 'v1',
      'business_name': 'Chez Aïcha',
      'address': 'Rue du Commerce',
      'city': 'Cotonou',
      'phone': '+228 90 11 22 33',
    },
  };
  const cancelled = {
    'id': 'd2',
    'status': 'cancelled',
    'fee': 200,
    'created_at': '2026-10-05T08:00:00Z',
  };

  return MockClient((request) async {
    final json = {'content-type': 'application/json'};
    if (request.url.path.endsWith('/driver/me/deliveries')) {
      return http.Response(
        jsonEncode({
          'data': [delivered, cancelled],
        }),
        200,
        headers: json,
      );
    }
    return http.Response(
      jsonEncode({'message': 'Not found'}),
      404,
      headers: json,
    );
  });
}

Future<void> _pumpScreen(WidgetTester tester) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(),
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: DriverHistoryScreen(marketplace: MarketplaceApi(api)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('historique livreur : le clic ouvre le détail de la mission', (
    tester,
  ) async {
    await _pumpScreen(tester);
    expect(tester.takeException(), isNull);

    // La liste affiche les missions terminées.
    expect(find.text('CMD-2026-018'), findsOneWidget);
    expect(find.text('Voir le détail de la mission'), findsNWidgets(2));

    // Le clic sur la mission ouvre la feuille de détail.
    await tester.tap(find.text('CMD-2026-018'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Détail de la mission'), findsOneWidget);
    expect(find.text('Avancement'), findsOneWidget);
    expect(find.text('Mission créée'), findsOneWidget);
    expect(find.text('Livraison terminée'), findsOneWidget);
    expect(find.text('Montants'), findsOneWidget);
    expect(find.text('Frais de livraison'), findsOneWidget);
    expect(find.text('Part livreur'), findsOneWidget);
    expect(find.text('Collecte'), findsOneWidget);
    expect(find.text('Chez Aïcha'), findsOneWidget);
    expect(find.text('Livraison'), findsOneWidget);
    expect(find.text('Quartier Ganhi, Cotonou'), findsOneWidget);
    expect(find.text('Aïcha K.'), findsOneWidget);
    expect(find.text('Contenu du colis'), findsOneWidget);
    expect(find.text('Riz cantonais'), findsOneWidget);
    expect(find.text('Preuve de livraison'), findsOneWidget);
    expect(find.text('AB-42'), findsOneWidget);
    expect(find.text('Fermer'), findsOneWidget);
  });

  testWidgets('historique livreur : la feuille se ferme', (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('CMD-2026-018'));
    await tester.pumpAndSettle();
    expect(find.text('Détail de la mission'), findsOneWidget);

    // Le bouton « Fermer » est en bas de la feuille : on la fait défiler.
    await tester.scrollUntilVisible(
      find.text('Fermer'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Détail de la mission'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
