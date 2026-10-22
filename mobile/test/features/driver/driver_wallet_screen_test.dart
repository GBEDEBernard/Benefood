import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/core/utils/formatters.dart';
import 'package:beninfood/features/driver/wallet/driver_wallet_screen.dart';
import 'package:beninfood/features/wallet/widgets/payout_request_sheet.dart';
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

/// Backend de test livreur : wallet avec commissions prélevées, flottant et
/// retrait Mobile Money.
MockClient _driverBackend({
  List<Map<String, dynamic>> posts = const [],
  String payoutStatus = 'pending',
}) {
  const wallet = {
    'pending_balance': 1000,
    'available_balance': 3200,
    'balance': 4200,
    'currency': 'XOF',
    'min_payout': 1000,
    'phone': '+22997000000',
    'commission_rate': 20,
    'commission_total': 800,
    'commission_count': 4,
    'transactions': [
      {
        'id': 't1',
        'type': 'credit',
        'amount': 1000,
        'description': 'Prix de livraison — COL-001',
        'balance_after': 4200,
        'created_at': '2026-10-10T09:00:00Z',
      },
      {
        'id': 't2',
        'type': 'debit',
        'amount': 200,
        'description': 'Commission Béninfood — COL-001',
        'balance_after': 4000,
        'created_at': '2026-10-10T09:00:01Z',
      },
    ],
  };
  const float = {'prepaid_balance': 2500, 'transactions': []};
  final created = {
    'id': 'p1',
    'amount': 3200,
    'method': 'mtn_open',
    'status': payoutStatus,
    'created_at': '2026-10-10T10:00:00Z',
  };

  return MockClient((request) async {
    final json = {'content-type': 'application/json'};
    final path = request.url.path;

    if (path.endsWith('/driver/me/wallet/payouts') &&
        request.method == 'POST') {
      posts.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'data': created}), 201, headers: json);
    }
    if (path.endsWith('/driver/me/float')) {
      return http.Response(jsonEncode({'data': float}), 200, headers: json);
    }
    if (path.endsWith('/driver/me/wallet/payouts')) {
      return http.Response(jsonEncode({'data': []}), 200, headers: json);
    }
    if (path.endsWith('/driver/me/wallet')) {
      return http.Response(jsonEncode({'data': wallet}), 200, headers: json);
    }
    if (path.endsWith('/me/notifications')) {
      return http.Response(jsonEncode({'data': []}), 200, headers: json);
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
    MaterialApp(home: DriverWalletScreen(marketplace: MarketplaceApi(api))),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('wallet livreur : soldes, commissions et journal affichés', (
    tester,
  ) async {
    await _pump(tester, _driverBackend());

    expect(find.byType(BeninfoodAppBar), findsOneWidget);
    expect(find.byType(BeninfoodBrand), findsOneWidget);
    expect(find.byType(NotificationBell), findsOneWidget);
    expect(find.text('Solde disponible'), findsOneWidget);
    expect(find.text(formatAmount(3200)), findsWidgets);
    expect(find.text('En attente de livraison'), findsOneWidget);
    expect(find.text(formatAmount(1000)), findsWidgets);

    // Flottant et commissions du livreur.
    expect(find.text('Flottant espèces (cash)'), findsOneWidget);
    expect(find.text(formatAmount(2500)), findsOneWidget);
    expect(find.text('Frais de commission'), findsOneWidget);
    expect(find.text('20 %'), findsOneWidget);
    expect(find.text(formatAmount(800)), findsWidgets);
    expect(find.text('Total prélevé'), findsOneWidget);
    expect(find.text('Commissions'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Retrait minimum'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Retrait minimum'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('Commission Béninfood'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Commission Béninfood'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet livreur : retrait direct dans la feuille Mobile Money', (
    tester,
  ) async {
    final posts = <Map<String, dynamic>>[];
    await _pump(tester, _driverBackend(posts: posts));

    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();

    // Le formulaire s'ouvre seul : pas de seconde page de solde.
    expect(find.byType(PayoutRequestSheet), findsOneWidget);
    expect(find.text('Retirer mes gains'), findsOneWidget);
    expect(find.text('Confirmer le retrait'), findsOneWidget);

    final amount = tester.widget<TextField>(
      find.byKey(PayoutRequestSheet.amountFieldKey),
    );
    final phone = tester.widget<TextField>(
      find.byKey(PayoutRequestSheet.phoneFieldKey),
    );
    expect(amount.controller?.text, '3200');
    expect(phone.controller?.text, '+22997000000');

    await tester.tap(find.text('Confirmer le retrait'));
    await tester.pumpAndSettle();

    expect(find.byType(PayoutRequestSheet), findsNothing);
    expect(
      find.text('Demande de retrait enregistrée, en cours de traitement.'),
      findsOneWidget,
    );
    expect(posts, hasLength(1));
    expect(posts.single['amount'], 3200);
    expect(posts.single['method'], 'mtn_open');
    expect(posts.single['destination'], '+22997000000');
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet livreur : montant sous le minimum bloqué', (
    tester,
  ) async {
    final posts = <Map<String, dynamic>>[];
    await _pump(tester, _driverBackend(posts: posts));

    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(PayoutRequestSheet.amountFieldKey),
      '500',
    );
    await tester.tap(find.text('Confirmer le retrait'));
    await tester.pumpAndSettle();

    expect(find.text('Le minimum est de 1 000 FCFA.'), findsOneWidget);
    expect(find.byType(PayoutRequestSheet), findsOneWidget);
    expect(posts, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
