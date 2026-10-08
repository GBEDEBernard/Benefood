import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/vendor/dashboard/vendor_dashboard_screen.dart';

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

/// Backend de test : statut vendeur ouvert, commandes mixtes et PATCH
/// d'ouverture/fermeture accepté.
MockClient _mockBackend(List<String> log) {
  const vendor = {
    'id': 'vnd_1',
    'business_name': 'Le Délice Fast-Food',
    'city': 'Cadjèhoun, Cotonou',
    'status': 'active',
    'closed_at': null,
    'is_open': true,
  };

  const orders = [
    {
      'id': 'ord_1',
      'reference': '#BF1256',
      'status': 'paid',
      'payment_status': 'paid',
      'total': 12000,
      'subtotal': 12000,
      'delivery_fee': 0,
      'items': [
        {
          'id': 'it_1',
          'name': 'Burger poulet',
          'quantity': 2,
          'unit_price': 6000,
          'subtotal': 12000,
        },
      ],
      'created_at': '2026-10-07T10:30:00Z',
    },
    {
      'id': 'ord_2',
      'reference': '#BF1255',
      'status': 'awaiting_payment',
      'payment_status': 'pending',
      'total': 4500,
      'subtotal': 4500,
      'delivery_fee': 0,
      'items': [
        {'id': 'it_2', 'name': 'Frites', 'quantity': 1, 'unit_price': 4500, 'subtotal': 4500},
      ],
      'created_at': '2026-10-07T10:15:00Z',
    },
    {
      'id': 'ord_3',
      'reference': '#BF1254',
      'status': 'preparing',
      'payment_status': 'paid',
      'total': 9000,
      'subtotal': 9000,
      'delivery_fee': 0,
      'items': [
        {'id': 'it_3', 'name': 'Pizza', 'quantity': 1, 'unit_price': 9000, 'subtotal': 9000},
      ],
      'created_at': '2026-10-07T09:50:00Z',
    },
    {
      'id': 'ord_4',
      'reference': '#BF1253',
      'status': 'delivered',
      'payment_status': 'paid',
      'total': 7500,
      'subtotal': 7500,
      'delivery_fee': 0,
      'items': [
        {'id': 'it_4', 'name': 'Wrap', 'quantity': 1, 'unit_price': 7500, 'subtotal': 7500},
      ],
      'created_at': '2026-10-07T09:00:00Z',
    },
  ];

  return MockClient((request) async {
    final headers = {'content-type': 'application/json'};
    final path = request.url.path;
    log.add('${request.method} $path');

    if (path.endsWith('/vendors/me/status')) {
      return http.Response(
        jsonEncode({'data': {'vendor': vendor, 'documents': <dynamic>[]}}),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/vendors/me/orders')) {
      return http.Response(jsonEncode({'data': orders}), 200, headers: headers);
    }
    if (request.method == 'PATCH' && path.endsWith('/vendors/me')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final open = body['closed_at'] == null;
      return http.Response(
        jsonEncode({'data': {...vendor, 'is_open': open, 'closed_at': body['closed_at']}}),
        200,
        headers: headers,
      );
    }
    return http.Response(jsonEncode({'message': 'Not found'}), 404, headers: headers);
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  List<String> log, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(log),
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: VendorDashboardScreen(
          marketplace: MarketplaceApi(api),
          onGoToTab: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop : sidebar, stats, commandes et panneau boutique', (tester) async {
    final log = <String>[];
    await _pumpDashboard(tester, log, size: const Size(1600, 900));

    // Sidebar verte (navigation).
    expect(find.text('LE DÉLICE'), findsOneWidget);
    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Boutique'), findsOneWidget);
    expect(find.text('Produits'), findsOneWidget);
    expect(find.text('Commandes'), findsOneWidget);
    expect(find.text('Revenus'), findsOneWidget);
    expect(find.text('Profil & Paramètres'), findsOneWidget);
    expect(find.text('Déconnexion'), findsOneWidget);

    // Colonnes centrales.
    expect(find.text('A. TABLEAU DE BORD'), findsOneWidget);
    expect(find.text('Commandes du jour'), findsOneWidget);
    expect(find.text('En attente d\'action'), findsOneWidget);
    expect(find.text('CA du jour'), findsOneWidget);
    expect(find.text('Note moyenne'), findsOneWidget);
    expect(find.text('Ajouter un produit'), findsOneWidget);
    expect(find.text('Modifier la boutique'), findsOneWidget);
    expect(find.text('Ouvrir / Fermer'), findsOneWidget);

    // Listes de commandes (2 nouvelles sur les 4 mockées, 4 récentes).
    expect(find.text('Nouvelles commandes'), findsOneWidget);
    expect(find.text('#BF1256'), findsWidgets);
    expect(find.text('Accepter'), findsWidgets);
    expect(find.text('Refuser'), findsWidgets);
    expect(find.text('Commandes récentes'), findsOneWidget);
    expect(find.text('Livrée'), findsOneWidget);

    // Panneau boutique à droite.
    expect(find.text('B. BOUTIQUE'), findsOneWidget);
    expect(find.text('< Ma boutique'), findsOneWidget);
    expect(find.text('Statut de la boutique'), findsOneWidget);
    expect(find.text('Statut du compte'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Ouvert'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('fermeture : interrupteur → PATCH /vendors/me puis toast', (tester) async {
    final log = <String>[];
    await _pumpDashboard(tester, log, size: const Size(1600, 900));

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(log, contains('PATCH /vendors/me'));
    expect(find.text('Boutique fermée.'), findsOneWidget);
    expect(find.text('Fermé'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Le toast laisse la place au widget suivant.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Boutique fermée.'), findsNothing);
  });

  testWidgets('mobile : sidebar masquée, panneau boutique empilé, sans débordement', (tester) async {
    final log = <String>[];
    await _pumpDashboard(tester, log, size: const Size(390, 844));

    expect(find.text('Tableau de bord'), findsNothing);
    expect(find.text('Déconnexion'), findsNothing);

    expect(find.text('A. TABLEAU DE BORD'), findsOneWidget);
    expect(find.text('Commandes du jour'), findsOneWidget);
    expect(find.text('Nouvelles commandes'), findsOneWidget);
    expect(find.text('Commandes récentes'), findsOneWidget);
    expect(find.text('B. BOUTIQUE'), findsOneWidget);

    // Le panneau empilé garde l'ouverture/fermeture accessible.
    final toggle = find.byType(Switch);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(log, contains('PATCH /vendors/me'));
    expect(find.text('Boutique fermée.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
