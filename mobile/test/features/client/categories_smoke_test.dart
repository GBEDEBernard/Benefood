import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/categories/categories_screen.dart';
import 'package:beninfood/shared/widgets/app_search_field.dart';
import 'package:beninfood/shared/widgets/state_widgets.dart';

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

/// Catalogue minimal : la boulangerie a une photo produit, les autres non.
MockClient _mockBackend() {
  const categories = [
    {
      'id': 'c-snack',
      'name': 'Snacks et restauration',
      'slug': 'snacks-et-restauration',
      'products_count': 2,
    },
    {
      'id': 'c-bakery',
      'name': 'Boulangerie',
      'slug': 'boulangerie',
      'products_count': 1,
    },
    {
      'id': 'c-meat',
      'name': 'Viandes et poissons',
      'slug': 'viandes-et-poissons',
      'products_count': 0,
    },
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
      return http.Response(
        jsonEncode({'data': categories}),
        200,
        headers: headers,
      );
    }
    if (request.url.path.endsWith('/products')) {
      return http.Response(
        jsonEncode({'data': products}),
        200,
        headers: headers,
      );
    }
    if (request.url.path.endsWith('/me/stats')) {
      return http.Response(
        jsonEncode({
          'data': {'unread_notifications': 3},
        }),
        200,
        headers: headers,
      );
    }
    if (request.url.path.endsWith('/me/notifications')) {
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 'n1',
              'type': 'delivery.assigned',
              'title': 'Livraison en cours',
              'body': 'Votre livreur est en route.',
              'read_at': null,
              'created_at': '2026-10-06T10:00:00Z',
            },
          ],
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
}

MarketplaceApi _api({MockClient? client}) {
  return MarketplaceApi(
    ApiClient(
      tokenStore: _NoopTokenStore(),
      httpClient: client ?? _mockBackend(),
      baseUrl: 'http://api.test',
    ),
  );
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(home: CategoriesScreen(marketplace: _api())),
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
  testWidgets('catégories : en-tête, recherche, catégories dynamiques', (
    tester,
  ) async {
    await _pumpScreen(tester);
    final exception = tester.takeException();
    expect(exception, isNull, reason: 'exception pendant le build: $exception');

    expect(find.byType(AppSearchField), findsOneWidget);
    expect(find.text('Catégories'), findsOneWidget);
    expect(find.text('Voir tout'), findsOneWidget);

    // Catégories renvoyées par l'API (plus de liste codée en dur).
    expect(find.text('Snacks et restauration'), findsOneWidget);
    expect(find.text('Boulangerie'), findsOneWidget);
    expect(find.text('Viandes et poissons'), findsOneWidget);

    // Nombre de produits réels.
    expect(find.text('2 produits'), findsOneWidget);
    expect(find.text('1 produit'), findsOneWidget);

    // Bannière promotionnelle (plus bas que le premier écran).
    final verticalScrollable = find
        .byWidgetPredicate(
          (widget) => widget is Scrollable && widget.axis == Axis.vertical,
          skipOffstage: false,
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Explorer'),
      300,
      scrollable: verticalScrollable,
    );
    expect(find.text('Envie de découvrir de nouveaux plats ?'), findsOneWidget);
    expect(find.text('Explorer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catégories : visuel photo si dispo, sinon icône de repli', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 300));

    // Seule la boulangerie a une photo produit.
    expect(_networkImageCount(tester), 1);

    // Repli icône (pas d'emoji) selon le libellé : cercle + visuel.
    expect(find.byIcon(Icons.kebab_dining), findsNWidgets(2));
    expect(find.byIcon(Icons.fastfood), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('catégories : erreur réseau affiche un état d’erreur', (
    tester,
  ) async {
    final api = _api(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({'message': 'Server error'}),
          500,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: CategoriesScreen(marketplace: api)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ErrorState), findsOneWidget);
    expect(_networkImageCount(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catégories : cloche avec pastille 3 ouvre les notifications', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Livraison en cours'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catégories : un appui ouvre la recherche filtrée', (
    tester,
  ) async {
    final marketplace = _api();
    final router = GoRouter(
      initialLocation: '/categories',
      routes: [
        GoRoute(
          path: '/categories',
          builder: (context, state) =>
              CategoriesScreen(marketplace: marketplace),
        ),
        GoRoute(
          path: '/client/search',
          builder: (context, state) {
            final extra = state.extra;
            final category = extra is Map<String, dynamic>
                ? extra['category']
                : null;
            return Scaffold(body: Center(child: Text('recherche:$category')));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Boulangerie'));
    await tester.pumpAndSettle();

    expect(find.text('recherche:c-bakery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
