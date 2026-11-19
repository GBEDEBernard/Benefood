import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/auth/session_provider.dart';
import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/home/home_screen.dart';
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

MockClient _mockBackend({
  bool unwrapHomeData = false,
  String? customHomePayload,
  Future<http.Response>? pendingHome,
  void Function()? onHomeCalled,
}) {
  final homeBody = File('test/fixtures/home.json').readAsStringSync();
  final homeMap = jsonDecode(homeBody) as Map<String, dynamic>;
  final homePayload = customHomePayload ??
      (unwrapHomeData ? jsonEncode(homeMap['data']) : homeBody);

  return MockClient((request) async {
    final path = request.url.path;
    final json = {'content-type': 'application/json'};

    if (path.endsWith('/home')) {
      onHomeCalled?.call();
      if (pendingHome != null) {
        return pendingHome;
      }
      return http.Response(homePayload, 200, headers: json);
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
  testWidgets('accueil affiche les données (réponse API enrobée dans data)', (
    tester,
  ) async {
    await _pumpShell(tester, _mockBackend());
    final exception = tester.takeException();
    expect(exception, isNull, reason: 'exception pendant le build: $exception');

    expect(find.text('Boutiques les mieux notées'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('La Boulangerie du Centre'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('La Boulangerie du Centre'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Plats du jour les mieux notés'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Plats du jour les mieux notés'), findsOneWidget);
    expect(find.byType(ListSkeleton), findsNothing);
  });

  testWidgets('accueil affiche les données (données non enrobées)', (
    tester,
  ) async {
    await _pumpShell(tester, _mockBackend(unwrapHomeData: true));
    final exception = tester.takeException();
    expect(exception, isNull, reason: 'exception pendant le build: $exception');

    expect(find.text('Boutiques les mieux notées'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('La Boulangerie du Centre'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('La Boulangerie du Centre'), findsOneWidget);
  });

  testWidgets('accueil n’affiche qu’un seul loader pendant le chargement', (
    tester,
  ) async {
    final homeResponse = Completer<http.Response>();
    var homeCalls = 0;

    await _pumpShell(
      tester,
      _mockBackend(
        pendingHome: homeResponse.future,
        onHomeCalled: () => homeCalls++,
      ),
    );

    expect(tester.takeException(), isNull);

    // Le shell monte aussi les autres onglets dans l'IndexedStack : on cible
    // uniquement l'accueil pour compter ses indicateurs de chargement.
    expect(
      find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.byType(ListSkeleton), findsNothing);
    expect(homeCalls, 1, reason: 'l’accueil ne doit charger qu’une seule fois');

    // Termine la requête pour ne pas laisser de future en attente.
    homeResponse.complete(
      http.Response(
        File('test/fixtures/home.json').readAsStringSync(),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('accueil met en avant les promotions créées par les vendeurs', (
    tester,
  ) async {
    final homeMap =
        jsonDecode(File('test/fixtures/home.json').readAsStringSync())
            as Map<String, dynamic>;
    final data = homeMap['data'] as Map<String, dynamic>;
    final products = data['featured_products'] as List<dynamic>;
    final product = products.first as Map<String, dynamic>;
    final now = DateTime.now().toUtc();

    data['promotions'] = [
      {
        'id': 'promo-home-test',
        'product_id': product['id'],
        'vendor_id': product['vendor_id'],
        'title': 'Offre test du jour',
        'promo_price': 300,
        'original_price': product['price'],
        'discount_percent': 33,
        'starts_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'ends_at': now.add(const Duration(days: 2)).toIso8601String(),
        'is_active': true,
        'is_currently_active': true,
        'product': product,
      },
    ];

    await _pumpShell(
      tester,
      _mockBackend(customHomePayload: jsonEncode(homeMap)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Offres du moment'), findsOneWidget);
    expect(find.text('Offre test du jour'), findsOneWidget);
    expect(find.text('−33 %'), findsWidgets);
    expect(find.text('Voir l’offre'), findsOneWidget);
  });
}
