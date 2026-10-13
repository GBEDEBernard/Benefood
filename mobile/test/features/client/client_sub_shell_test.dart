import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/presentation/client_shell.dart';
import 'package:beninfood/features/client/presentation/client_sub_shell.dart';

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
            'items': <Object?>[],
            'subtotal': 0,
            'items_count': 3,
            'currency': 'XOF',
            'vendor': null,
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

Future<void> _pump(WidgetTester tester, {required GoRouter router}) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => ClientNavigation.requestedTab.value = null);

  testWidgets('page secondaire : barre du bas visible et compte panier', (
    tester,
  ) async {
    final api = ApiClient(
      tokenStore: _NoopTokenStore(),
      httpClient: _mockBackend(),
      baseUrl: 'http://api.test',
    );
    final marketplace = MarketplaceApi(api);
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
                  const Scaffold(body: Center(child: Text('page recherche'))),
            ),
          ],
        ),
        GoRoute(
          path: '/client',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('accueil'))),
        ),
      ],
    );

    await _pump(tester, router: router);

    final exception = tester.takeException();
    expect(exception, isNull, reason: 'exception pendant le build: $exception');

    expect(find.byType(ClientBottomBar), findsOneWidget);
    expect(find.text('page recherche'), findsOneWidget);
    expect(find.text('Commandes'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('toucher un onglet depuis une page secondaire revient au shell', (
    tester,
  ) async {
    final api = ApiClient(
      tokenStore: _NoopTokenStore(),
      httpClient: _mockBackend(),
      baseUrl: 'http://api.test',
    );
    final marketplace = MarketplaceApi(api);
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
                  const Scaffold(body: Center(child: Text('page recherche'))),
            ),
          ],
        ),
        GoRoute(
          path: '/client',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('accueil'))),
        ),
      ],
    );

    await _pump(tester, router: router);

    await tester.tap(find.text('Commandes'));
    await tester.pumpAndSettle();

    expect(find.text('accueil'), findsOneWidget);
    expect(ClientNavigation.requestedTab.value, 3);
  });
}
