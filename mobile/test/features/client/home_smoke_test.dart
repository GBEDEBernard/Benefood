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
import 'package:beninfood/shared/widgets/state_widgets.dart';

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

MockClient _mockBackend({bool unwrapHomeData = false}) {
  final homeBody = File('test/fixtures/home.json').readAsStringSync();
  final homeMap = jsonDecode(homeBody) as Map<String, dynamic>;
  final homePayload = unwrapHomeData
      ? jsonEncode(homeMap['data'])
      : homeBody;

  return MockClient((request) async {
    final path = request.url.path;
    final json = {'content-type': 'application/json'};

    if (path.endsWith('/home')) {
      return http.Response(homePayload, 200, headers: json);
    }
    if (path.endsWith('/products')) {
      return http.Response(jsonEncode({'data': []}), 200, headers: json);
    }
    if (path.endsWith('/cart') ||
        path.endsWith('/orders') ||
        path.endsWith('/me')) {
      return http.Response(
        jsonEncode({'message': 'Unauthenticated.'}),
        401,
        headers: json,
      );
    }
    return http.Response(jsonEncode({'message': 'Not found'}), 404,
        headers: json);
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
  testWidgets('accueil affiche les données (réponse API enrobée dans data)',
      (tester) async {
    await _pumpShell(tester, _mockBackend());
    final exception = tester.takeException();
    expect(exception, isNull, reason: 'exception pendant le build: $exception');

    expect(find.text('Restaurants populaires'), findsOneWidget);
    expect(find.text('La Boulangerie du Centre'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Plats du jour'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Plats du jour'), findsOneWidget);
    expect(find.byType(ListSkeleton), findsNothing);
  });

  testWidgets('accueil affiche les données (données non enrobées)',
      (tester) async {
    await _pumpShell(tester, _mockBackend(unwrapHomeData: true));
    final exception = tester.takeException();
    expect(exception, isNull, reason: 'exception pendant le build: $exception');

    expect(find.text('Restaurants populaires'), findsOneWidget);
    expect(find.text('La Boulangerie du Centre'), findsOneWidget);
  });
}
