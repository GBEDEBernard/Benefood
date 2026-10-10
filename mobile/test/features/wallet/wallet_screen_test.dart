import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/core/utils/formatters.dart';
import 'package:beninfood/features/wallet/wallet_screen.dart';

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

/// Backend de test : wallet vendeur (4 500 dispo / 1 200 en attente) et un
/// historique de retraits.
MockClient _mockBackend({bool failPayout = false}) {
  const wallet = {
    'pending_balance': 1200,
    'available_balance': 4500,
    'balance': 5700,
    'currency': 'XOF',
    'min_payout': 1000,
    'transactions': [
      {
        'id': 't1',
        'type': 'credit',
        'amount': 4500,
        'description': 'Libération part vendeur — BEN-001',
        'balance_after': 4500,
        'created_at': '2026-10-10T09:00:00Z',
      },
    ],
  };
  const payouts = [
    {
      'id': 'p1',
      'amount': 2000,
      'method': 'mobile_money',
      'status': 'executed',
      'created_at': '2026-10-09T09:00:00Z',
    },
  ];
  const created = {
    'id': 'p2',
    'amount': 4500,
    'method': 'mobile_money',
    'status': 'pending',
    'created_at': '2026-10-10T10:00:00Z',
  };

  return MockClient((request) async {
    final json = {'content-type': 'application/json'};
    final path = request.url.path;

    if (path.endsWith('/wallet/payouts') && request.method == 'POST') {
      if (failPayout) {
        return http.Response(
          jsonEncode({
            'errors': [
              {'code': 'payout.below_minimum', 'message': 'Montant trop faible.', 'field': 'amount'},
            ],
          }),
          422,
          headers: json,
        );
      }
      return http.Response(jsonEncode({'data': created}), 201, headers: json);
    }
    if (path.endsWith('/wallet/payouts')) {
      return http.Response(jsonEncode({'data': payouts}), 200, headers: json);
    }
    if (path.endsWith('/wallet')) {
      return http.Response(jsonEncode({'data': wallet}), 200, headers: json);
    }
    return http.Response(jsonEncode({'data': null}), 404, headers: json);
  });
}

Future<void> _pump(WidgetTester tester, MockClient client) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: client,
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: WalletScreen(marketplace: MarketplaceApi(api), role: WalletRole.vendor),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('wallet vendeur : soldes et journal affichés', (tester) async {
    await _pump(tester, _mockBackend());

    expect(find.text('Portefeuille'), findsOneWidget);
    expect(find.text('Solde disponible'), findsOneWidget);
    expect(find.text(formatAmount(4500)), findsWidgets);
    expect(find.text('En attente de livraison'), findsOneWidget);
    expect(find.text(formatAmount(1200)), findsOneWidget);
    expect(find.text('Retrait minimum'), findsOneWidget);
    expect(find.textContaining('Libération part vendeur'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Versé'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Versé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet vendeur : demande de retrait envoyée', (tester) async {
    await _pump(tester, _mockBackend());

    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();

    expect(find.text('Demander un retrait'), findsOneWidget);

    await tester.tap(find.text('Confirmer la demande'));
    await tester.pumpAndSettle();

    expect(find.text('Demande de retrait envoyée.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet vendeur : erreur de retrait affichée', (tester) async {
    await _pump(tester, _mockBackend(failPayout: true));

    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer la demande'));
    await tester.pumpAndSettle();

    expect(find.text('Montant trop faible.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
