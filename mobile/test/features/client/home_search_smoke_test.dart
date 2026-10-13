import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/auth/session_provider.dart';
import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/presentation/client_shell.dart';

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

/// Recherche dynamique : renvoie une boutique et un plat pour « poulet ».
MockClient _mockBackend() {
  final homeBody = File('test/fixtures/home.json').readAsStringSync();

  return MockClient((request) async {
    final path = request.url.path;
    final json = {'content-type': 'application/json'};
    final matches = (request.url.queryParameters['q'] ?? '')
        .toLowerCase()
        .contains('poulet');

    if (path.endsWith('/home')) {
      return http.Response(homeBody, 200, headers: json);
    }
    if (path.endsWith('/client/me/status')) {
      return http.Response(
        jsonEncode({
          'data': {
            'profile': {'id': 'cp-1', 'status': 'active'},
            'required_documents': <String>[],
            'completed_documents': <String>[],
            'completed': true,
          },
        }),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/products')) {
      return http.Response(
        jsonEncode({
          'data': matches
              ? [
                  {
                    'id': 'p1',
                    'vendor_id': 'v1',
                    'category_id': 'c1',
                    'name': 'Poulet braisé',
                    'price': 5000,
                    'currency': 'XOF',
                    'unit': 'portion',
                    'is_active': true,
                    'is_available': true,
                    'is_orderable': true,
                    'status': 'active',
                  },
                ]
              : <Object?>[],
        }),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/vendors')) {
      return http.Response(
        jsonEncode({
          'data': matches
              ? [
                  {
                    'id': 'v1',
                    'business_name': 'Chez Awa',
                    'city': 'Cotonou',
                    'status': 'active',
                  },
                ]
              : <Object?>[],
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

Future<void> _pumpShell(WidgetTester tester, MockClient client) async {
  final api = ApiClient(
    tokenStore: _MemoryTokenStore(),
    httpClient: client,
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
}

void main() {
  testWidgets('la recherche dynamique affiche boutiques et plats', (
    tester,
  ) async {
    await _pumpShell(tester, _mockBackend());

    await tester.enterText(find.byType(TextField).first, 'poulet');
    // Dépasse le debounce de 350 ms puis laisse la réponse arriver.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('BOUTIQUES'), findsOneWidget);
    expect(find.text('PLATS'), findsOneWidget);
    expect(find.text('Chez Awa'), findsOneWidget);
    expect(find.text('Poulet braisé'), findsOneWidget);
  });

  testWidgets('la recherche dynamique signale l\'absence de résultat', (
    tester,
  ) async {
    await _pumpShell(tester, _mockBackend());

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Aucun résultat'), findsOneWidget);
  });
}
