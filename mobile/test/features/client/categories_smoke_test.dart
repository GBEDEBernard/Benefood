import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/categories/categories_screen.dart';
import 'package:beninfood/shared/widgets/app_search_field.dart';

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

/// Catalogue minimal : la boulangerie a une photo produit, les autres
/// catégories non (repli emoji attendu).
MockClient _mockBackend() {
  const categories = [
    {'id': 'c-snack', 'name': 'Snacks et restauration', 'slug': 'snacks-et-restauration'},
    {'id': 'c-bakery', 'name': 'Boulangerie', 'slug': 'boulangerie'},
    {'id': 'c-meat', 'name': 'Viandes et poissons', 'slug': 'viandes-et-poissons'},
  ];
  const products = [
    {
      'id': 'p1',
      'vendor_id': 'v1',
      'category_id': 'c-bakery',
      'name': 'Croissant',
      'price': 500,
      'stock_qty': 5,
      'image_url': 'http://api.test/storage/products/croissant.webp',
    },
    {
      'id': 'p2',
      'vendor_id': 'v1',
      'category_id': 'c-snack',
      'name': 'Poulet DG',
      'price': 2500,
      'stock_qty': 5,
      'image_url': null,
    },
  ];

  return MockClient((request) async {
    final headers = {'content-type': 'application/json'};
    if (request.url.path.endsWith('/categories')) {
      return http.Response(jsonEncode({'data': categories}), 200, headers: headers);
    }
    if (request.url.path.endsWith('/products')) {
      return http.Response(jsonEncode({'data': products}), 200, headers: headers);
    }
    return http.Response(jsonEncode({'message': 'Not found'}), 404, headers: headers);
  });
}

Future<void> _pumpScreen(WidgetTester tester) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(),
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(home: CategoriesScreen(marketplace: MarketplaceApi(api))),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Images distantes (le fetch réseau de test renvoie 400 → fallback).
int _networkImageCount(WidgetTester tester) => find
    .byWidgetPredicate(
      (widget) => widget is Image && widget.image is NetworkImage,
    )
    .evaluate()
    .length;

void main() {
  testWidgets('catégories : en-tête, recherche, grille et bannière',
      (tester) async {
    await _pumpScreen(tester);
    final exception = tester.takeException();
    expect(exception, isNull, reason: 'exception pendant le build: $exception');

    expect(find.byType(AppSearchField), findsOneWidget);
    expect(find.text('Catégories'), findsOneWidget);
    expect(find.text('Voir tout'), findsOneWidget);

    // Les 8 cartes de la spec.
    const titles = [
      'Plats locaux',
      'Fast-food',
      'Maquis',
      'Poulet',
      'Soupes & Sauce',
      'Riz & Accompagnements',
      'Boissons',
      'Desserts',
    ];
    for (final title in titles) {
      expect(find.text(title), findsOneWidget, reason: 'carte $title');
    }
    expect(find.text('124 restaurants'), findsOneWidget);
    expect(find.text('156 restaurants'), findsOneWidget);
    expect(find.text('29 restaurants'), findsOneWidget);

    // Bannière promotionnelle (plus bas que le premier écran).
    final verticalScrollable = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      skipOffstage: false,
    ).first;
    await tester.scrollUntilVisible(
      find.text('Explorer'),
      300,
      scrollable: verticalScrollable,
    );
    expect(
      find.text('Envie de découvrir de nouveaux plats ?'),
      findsOneWidget,
    );
    expect(
      find.text('Explorez nos meilleures adresses à Cotonou.'),
      findsOneWidget,
    );
    expect(find.text('Explorer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catégories : visuels dynamiques (photo si dispo, sinon emoji)',
      (tester) async {
    await _pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 300));

    // Desserts et Fast-food pointent vers « boulangerie » (photo dispo).
    expect(
      _networkImageCount(tester),
      2,
      reason: 'les 2 cartes mappées sur boulangerie ont une image',
    );

    // Maquis (snacks, sans photo) garde l'emoji de repli.
    expect(find.text('🍢'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catégories : échec réseau silencieux (repli emoji)',
      (tester) async {
    final api = ApiClient(
      tokenStore: _NoopTokenStore(),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'message': 'Server error'}),
          500,
          headers: {'content-type': 'application/json'},
        ),
      ),
      baseUrl: 'http://api.test',
    );
    await tester.pumpWidget(
      MaterialApp(home: CategoriesScreen(marketplace: MarketplaceApi(api))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_networkImageCount(tester), 0);
    expect(find.text('🍚'), findsOneWidget);
    expect(find.text('Plats locaux'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catégories : cloche avec pastille 3 ouvre les notifications',
      (tester) async {
    await _pumpScreen(tester);

    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Livraison en cours'), findsOneWidget);
    expect(find.text('Offre du jour'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
