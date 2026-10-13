import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/cart/cart_screen.dart';
import 'package:beninfood/shared/widgets/beninfood_header.dart';
import 'package:beninfood/shared/widgets/notification_bell.dart';

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

MockClient _mockBackend() {
  return MockClient((request) async {
    const json = {'content-type': 'application/json'};
    final path = request.url.path;

    if (path.endsWith('/cart')) {
      return http.Response(
        jsonEncode({
          'data': {
            'id': 'cart-1',
            'items': [
              {
                'id': 'ci1',
                'quantity': 2,
                'subtotal': 10000,
                'product': {
                  'id': 'p1',
                  'name': 'Poulet braisé',
                  'unit_price': 5000,
                  'image_url': null,
                },
              },
            ],
            'subtotal': 10000,
            'items_count': 2,
            'currency': 'XOF',
            'vendor': {
              'id': 'v1',
              'business_name': 'Chez Awa',
              'logo_url': null,
            },
          },
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

Future<void> _pump(WidgetTester tester) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(),
    baseUrl: 'http://api.test',
  );
  final marketplace = MarketplaceApi(api);
  final router = GoRouter(
    initialLocation: '/client/cart',
    routes: [
      GoRoute(
        path: '/client/cart',
        builder: (context, state) =>
            CartScreen(marketplace: marketplace, onOpenMenu: () {}),
      ),
      GoRoute(
        path: '/client/checkout',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('paiement'))),
      ),
      GoRoute(
        path: '/client/search',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('recherche'))),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('panier : en-tête standard (marque, cloche) et articles', (
    tester,
  ) async {
    await _pump(tester);

    final exception = tester.takeException();
    expect(exception, isNull, reason: 'exception pendant le build: $exception');

    // En-tête BÉN INFOOD : marque centrée + cloche de notification.
    expect(find.byType(BeninfoodAppBar), findsOneWidget);
    expect(find.byType(BeninfoodBrand), findsOneWidget);
    expect(find.byType(NotificationBell), findsOneWidget);

    // Contenu du panier.
    expect(find.text('Poulet braisé'), findsOneWidget);
    expect(find.text('Chez Awa'), findsOneWidget);
  });
}
