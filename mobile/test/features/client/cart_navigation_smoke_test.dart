import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/auth/session_provider.dart';
import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/presentation/client_shell.dart';
import 'package:beninfood/features/client/presentation/client_sub_shell.dart';
import 'package:beninfood/features/client/product/product_detail_screen.dart';

class _MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<String?> readRefreshToken() async => _token;

  @override
  Future<void> write(Map<String, dynamic> authPayload) async {
    _token = authPayload['access_token']?.toString();
  }

  @override
  Future<void> clear() async => _token = null;
}

Map<String, Object?> _cartData(bool hasItem) {
  return {
    'id': 'cart-1',
    'items': hasItem
        ? [
            {
              'id': 'ci1',
              'quantity': 1,
              'subtotal': 5000,
              'product': {
                'id': 'p1',
                'name': 'Poulet braisé',
                'unit_price': 5000,
                'image_url': null,
              },
            },
          ]
        : <Object?>[],
    'subtotal': hasItem ? 5000 : 0,
    'items_count': hasItem ? 1 : 0,
    'currency': 'XOF',
    'vendor': hasItem
        ? {'id': 'v1', 'business_name': 'Chez Awa', 'logo_url': null}
        : null,
  };
}

MockClient _mockBackend({
  required bool Function() cartHasItem,
  void Function()? onAddToCart,
}) {
  final homeBody = File('test/fixtures/home.json').readAsStringSync();

  return MockClient((request) async {
    const json = {'content-type': 'application/json'};
    final path = request.url.path;

    if (path.endsWith('/home')) {
      return http.Response(homeBody, 200, headers: json);
    }
    if (path.endsWith('/client/me/status')) {
      return http.Response(
        jsonEncode({
          'data': {
            'profile': {'id': 'cp-1', 'status': 'active'},
            'required_documents': ['id_card', 'proof_of_address'],
            'completed_documents': ['id_card', 'proof_of_address'],
            'completed': true,
          },
        }),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/products/p1')) {
      return http.Response(
        jsonEncode({
          'data': {
            'id': 'p1',
            'vendor_id': 'v1',
            'vendor_name': 'Chez Awa',
            'name': 'Poulet braisé',
            'description': 'Poulet mariné et grillé.',
            'price': 5000,
            'currency': 'XOF',
            'unit': 'portion',
            'is_active': true,
            'is_available': true,
            'is_orderable': true,
            'stock_qty': 10,
            'status': 'active',
            'rating': 4.6,
            'reviews_count': 12,
            'likes_count': 30,
            'images': <Object?>[],
          },
        }),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/me/favorites')) {
      return http.Response(
        jsonEncode({'data': <Object?>[]}),
        200,
        headers: json,
      );
    }
    if (request.method == 'POST' && path.endsWith('/cart/items')) {
      onAddToCart?.call();
      return http.Response(
        jsonEncode({'data': _cartData(cartHasItem())}),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/cart')) {
      return http.Response(
        jsonEncode({'data': _cartData(cartHasItem())}),
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

void main() {
  testWidgets('le bouton panier ouvre le panier à jour après un ajout', (
    tester,
  ) async {
    var hasItem = false;
    final api = ApiClient(
      tokenStore: _MemoryTokenStore(),
      httpClient: _mockBackend(cartHasItem: () => hasItem),
      baseUrl: 'http://api.test',
    );
    final session = SessionProvider(api: api);

    await tester.pumpWidget(
      MaterialApp(
        home: ClientShell(session: session, marketplace: MarketplaceApi(api)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    hasItem = true;
    final cartButton = find.descendant(
      of: find.byType(ClientBottomBar),
      matching: find.byIcon(Icons.shopping_cart),
    );

    await tester.tap(cartButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Poulet braisé'), findsOneWidget);
    expect(find.text('Explorer les boutiques'), findsNothing);
  });

  testWidgets('depuis une page secondaire, le bouton panier ouvre le panier', (
    tester,
  ) async {
    var hasItem = false;
    final api = ApiClient(
      tokenStore: _MemoryTokenStore(),
      httpClient: _mockBackend(cartHasItem: () => hasItem),
      baseUrl: 'http://api.test',
    );
    final marketplace = MarketplaceApi(api);
    final session = SessionProvider(api: api);
    final router = GoRouter(
      initialLocation: '/client/search',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              ClientSubShell(marketplace: marketplace, child: child),
          routes: [
            GoRoute(
              path: '/client/search',
              builder: (context, state) =>
                  const Scaffold(body: Text('page recherche')),
            ),
          ],
        ),
        GoRoute(
          path: '/client',
          builder: (context, state) =>
              ClientShell(session: session, marketplace: marketplace),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    hasItem = true;
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Poulet braisé'), findsOneWidget);
      expect(find.text('Explorer les boutiques'), findsNothing);
    },
  );

  testWidgets(
    'ajouter depuis une fiche produit puis ouvrir le panier depuis le footer',
    (tester) async {
      var hasItem = false;
      final api = ApiClient(
        tokenStore: _MemoryTokenStore(),
        httpClient: _mockBackend(
          cartHasItem: () => hasItem,
          onAddToCart: () => hasItem = true,
        ),
        baseUrl: 'http://api.test',
      );
      final marketplace = MarketplaceApi(api);
      final session = SessionProvider(api: api);
      final router = GoRouter(
        initialLocation: '/client/product/p1',
        routes: [
          ShellRoute(
            builder: (context, state, child) =>
                ClientSubShell(marketplace: marketplace, child: child),
            routes: [
              GoRoute(
                path: '/client/product/:id',
                builder: (context, state) => ProductDetailScreen(
                  marketplace: marketplace,
                  productId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/client',
            builder: (context, state) =>
                ClientShell(session: session, marketplace: marketplace),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Ajouter au panier'));
      await tester.pumpAndSettle();

      expect(find.text('Poulet braisé'), findsOneWidget);
      expect(find.text('Ajouter au panier'), findsOneWidget);

      final cartButton = find.descendant(
        of: find.byType(ClientBottomBar),
        matching: find.byIcon(Icons.shopping_cart),
      );
      await tester.tap(cartButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Poulet braisé'), findsOneWidget);
      expect(find.text('Explorer les boutiques'), findsNothing);
    },
  );
}
