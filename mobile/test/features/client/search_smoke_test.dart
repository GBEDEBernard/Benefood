import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/search/search_screen.dart';
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

    if (path.endsWith('/vendors')) {
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 'v1',
              'business_name': 'Chez Awa',
              'type': 'restaurant',
              'city': 'Cotonou',
              'area': 'Akpakpa',
              'logo_url': null,
              'cover_url': null,
              'latitude': 6.36,
              'longitude': 2.42,
              'is_open': true,
              'rating': 4.5,
              'reviews_count': 3,
              'prep_minutes': 25,
            },
          ],
        }),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/products')) {
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 'p1',
              'vendor_id': 'v1',
              'vendor_name': 'Chez Awa',
              'category_id': 'c1',
              'name': 'Poulet braisé',
              'price': 5000,
              'currency': 'XOF',
              'unit': 'portion',
              'is_active': true,
              'is_available': true,
              'is_orderable': true,
              'stock_qty': 10,
              'status': 'active',
              'image_url': null,
              'image_main': null,
            },
          ],
        }),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/me/stats')) {
      return http.Response(
        jsonEncode({
          'data': {'unread_notifications': 2},
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
    initialLocation: '/client/search',
    routes: [
      GoRoute(
        path: '/client/search',
        builder: (context, state) => SearchScreen(marketplace: marketplace),
      ),
      GoRoute(
        path: '/client',
        builder: (context, state) => const Scaffold(body: Text('accueil')),
      ),
      GoRoute(
        path: '/client/product/:id',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('produit'))),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('recherche : en-tête standard (marque, cloche) et résultats', (
    tester,
  ) async {
    await _pump(tester);

    final exception = tester.takeException();
    expect(exception, isNull, reason: 'exception pendant le build: $exception');

    // En-tête BÉN INFOOD : marque centrée + cloche de notification.
    expect(find.byType(BeninfoodAppBar), findsOneWidget);
    expect(find.byType(BeninfoodBrand), findsOneWidget);
    expect(find.byType(NotificationBell), findsOneWidget);

    // Champ de recherche + résultats (plats et boutiques).
    expect(find.text('Rechercher un plat, un restaurant, une boutique…'), findsOneWidget);
    expect(find.text('Chez Awa'), findsWidgets);
    expect(find.text('Poulet braisé'), findsOneWidget);
  });
}
