import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/vendor/restaurant/restaurant_shell_screen.dart';

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
  final vendor = <String, dynamic>{
    'id': 'vnd_1',
    'business_name': 'Le Délice Fast-Food',
    'city': 'Cadjèhoun, Cotonou',
    'address': 'Carrefour des 3 collèges',
    'status': 'active',
    'closed_at': null,
    'is_open': true,
    'hours': [
      {'day_of_week': 0, 'opens_at': '08:00', 'closes_at': '22:00', 'is_closed': false},
      {'day_of_week': 1, 'opens_at': '08:00', 'closes_at': '22:00', 'is_closed': false},
      {'day_of_week': 2, 'opens_at': '08:00', 'closes_at': '22:00', 'is_closed': false},
      {'day_of_week': 3, 'opens_at': '08:00', 'closes_at': '22:00', 'is_closed': false},
      {'day_of_week': 4, 'opens_at': '08:00', 'closes_at': '22:00', 'is_closed': false},
      {'day_of_week': 5, 'opens_at': null, 'closes_at': null, 'is_closed': true},
      {'day_of_week': 6, 'opens_at': null, 'closes_at': null, 'is_closed': true},
    ],
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
      if (body.containsKey('closed_at')) {
        final open = body['closed_at'] == null;
        vendor['is_open'] = open;
        vendor['closed_at'] = body['closed_at'];
      }
      for (final entry in body.entries) {
        if (entry.key == 'hours' && entry.value is List) {
          vendor['hours'] = entry.value;
          continue;
        }
        if (entry.value != null) {
          vendor[entry.key] = entry.value;
        }
      }
      final response = Map<String, dynamic>.of(vendor);
      return http.Response(
        jsonEncode({'data': response}),
        200,
        headers: headers,
      );
    }
    return http.Response(jsonEncode({'message': 'Not found'}), 404, headers: headers);
  });
}

Future<void> _pumpShell(
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
      home: RestaurantShellScreen(marketplace: MarketplaceApi(api)),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile : tableau de bord avec hamburger → drawer → boutique', (tester) async {
    final log = <String>[];
    await _pumpShell(tester, log, size: const Size(390, 844));

    // En-tête : hamburger, logo + écriture Béninfood, cloche de notifications.
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text('BÉNINFOOD', findRichText: true), findsOneWidget);
    expect(find.image(const AssetImage('assets/Logo.jpeg')), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    // Titre vert du tableau de bord + badge d'état, stats, commandes.
    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Ouvert'), findsOneWidget);
    expect(find.text('Commandes du jour'), findsOneWidget);
    expect(find.text('CA du jour'), findsOneWidget);
    expect(find.text('Nouvelles commandes'), findsOneWidget);
    expect(find.text('#BF1256'), findsOneWidget);
    expect(find.text('Accepter'), findsWidgets);

    // Le drawer est fermé au départ.
    expect(find.text('Boutique'), findsNothing);

    // Ouvrir le menu latéral via le hamburger.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Tableau de bord'), findsWidgets);
    expect(find.text('LE DÉLICE FAST-FOOD'), findsOneWidget);
    expect(find.text('Ouvert'), findsWidgets);
    expect(find.text('Boutique'), findsOneWidget);
    expect(find.text('Produits'), findsOneWidget);
    expect(find.text('Commandes'), findsOneWidget);
    expect(find.text('Revenus'), findsOneWidget);
    expect(find.text('Profil & Paramètres'), findsOneWidget);
    expect(find.text('Déconnexion'), findsOneWidget);

    // Cliquer « Boutique » : l'écran principale bascule sur Ma boutique.
    await tester.tap(find.text('Boutique'));
    await tester.pumpAndSettle();
    expect(find.text('Ma boutique'), findsWidgets);
    expect(find.text('Statut de la boutique'), findsOneWidget);
    expect(find.text('Statut du compte'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('fermeture boutique : interrupteur → PATCH /vendors/me puis toast', (tester) async {
    final log = <String>[];
    await _pumpShell(tester, log, size: const Size(390, 844));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boutique'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(log, contains('PATCH /vendors/me'));
    expect(find.text('Boutique fermée.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Boutique fermée.'), findsNothing);
  });

  testWidgets('modification infos boutique : éditeur → PATCH /vendors/me', (tester) async {
    final log = <String>[];
    await _pumpShell(tester, log, size: const Size(390, 844));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boutique'));
    await tester.pumpAndSettle();

    // Le profil affiche les infos issues de l'API.
    expect(find.text('Le Délice Fast-Food'), findsWidgets);

    // Ouvrir l'éditeur d'informations depuis l'en-tête.
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer'), findsOneWidget);

    // Renommer la boutique.
    await tester.enterText(find.byType(TextFormField).first, 'Le Délice Gourmet');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(log, contains('PATCH /vendors/me'));
    // Le shell re-charge le statut : le nouveau nom apparaît dans la boutique.
    expect(find.text('Le Délice Gourmet'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ma boutique : carte horaires → éditeur horaires', (tester) async {
    final log = <String>[];
    await _pumpShell(tester, log, size: const Size(390, 844));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boutique'));
    await tester.pumpAndSettle();

    // La semaine est affichée et chaque jour ouvre l'éditeur.
    expect(find.text('Lundi'), findsOneWidget);
    expect(find.text('Dimanche'), findsOneWidget);
    await tester.tap(find.text('Lundi'));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('produits : bouton retour vers le tableau de bord', (tester) async {
    final log = <String>[];
    await _pumpShell(tester, log, size: const Size(390, 844));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Produits'));
    await tester.pumpAndSettle();

    expect(find.text('Mes produits'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Tableau de bord'), findsWidgets);
    expect(find.text('Commandes du jour'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}