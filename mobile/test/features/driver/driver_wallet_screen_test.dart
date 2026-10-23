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
  const earnings = {
    'currency': 'XOF',
    'eur_rate': 655.957,
    'periods': {
      'day': {'earnings': 800, 'missions': 2, 'comparison': 12.5},
      'week': {'earnings': 3200, 'missions': 8, 'comparison': -4.2},
      'month': {'earnings': 12500, 'missions': 31, 'comparison': 18.0},
    },
    'series': {
      'day': [
        {'label': 'Jeu', 'earnings': 0, 'missions': 0, 'current': false},
        {'label': 'Ven', 'earnings': 300, 'missions': 1, 'current': false},
        {'label': 'Sam', 'earnings': 500, 'missions': 2, 'current': false},
        {'label': 'Dim', 'earnings': 200, 'missions': 1, 'current': false},
        {'label': 'Lun', 'earnings': 400, 'missions': 1, 'current': false},
        {'label': 'Mar', 'earnings': 600, 'missions': 2, 'current': false},
        {'label': 'Mer', 'earnings': 800, 'missions': 2, 'current': true},
      ],
      'week': [
        {'label': 'Sem. 39', 'earnings': 1800, 'missions': 5, 'current': false},
        {'label': 'Sem. 40', 'earnings': 2400, 'missions': 6, 'current': false},
        {'label': 'Sem. 41', 'earnings': 2100, 'missions': 5, 'current': false},
        {
          'label': 'Cette sem.',
          'earnings': 3200,
          'missions': 8,
          'current': true,
        },
      ],
      'month': [
        {'label': 'Mai', 'earnings': 8200, 'missions': 20, 'current': false},
        {'label': 'Juin', 'earnings': 9300, 'missions': 22, 'current': false},
        {'label': 'Juil', 'earnings': 10100, 'missions': 24, 'current': false},
        {'label': 'Août', 'earnings': 11400, 'missions': 27, 'current': false},
        {'label': 'Sept', 'earnings': 12000, 'missions': 29, 'current': false},
        {'label': 'Oct', 'earnings': 12500, 'missions': 31, 'current': true},
      ],
    },
  };
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
    if (path.endsWith('/driver/me/earnings')) {
      return http.Response(jsonEncode({'data': earnings}), 200, headers: json);
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
    MaterialApp(
      home: Scaffold(
        body: DriverWalletScreen(marketplace: MarketplaceApi(api)),
      ),
    ),
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
    expect(find.text('SOLDE DISPONIBLE'), findsOneWidget);
    expect(find.text(formatAmount(3200, showSymbol: false)), findsWidgets);
    expect(find.text('EN ATTENTE'), findsWidgets);
    expect(find.text(formatAmount(1000, showSymbol: false)), findsWidgets);

    // Gains par période et conversion de devises.
    expect(find.text('Gains'), findsOneWidget);
    expect(find.text('Jour'), findsOneWidget);
    expect(find.text('Semaine'), findsOneWidget);
    expect(find.text('Mois'), findsOneWidget);
    expect(find.text(formatAmount(3200, showSymbol: false)), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Devises'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Devises'), findsOneWidget);
    expect(find.text('FCFA'), findsWidgets);
    expect(find.text('EUR'), findsOneWidget);
    expect(find.textContaining('parité fixe'), findsOneWidget);

    // Flottant et commissions du livreur.
    await tester.scrollUntilVisible(
      find.text('Flottant espèces'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Flottant espèces'), findsOneWidget);
    expect(find.text(formatAmount(2500)), findsOneWidget);
    expect(find.text('COMMISSIONS'), findsOneWidget);
    expect(find.text('20 % prélevé'), findsOneWidget);
    expect(find.text(formatAmount(800, showSymbol: false)), findsWidgets);
    expect(find.text('RETRAIT MIN.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('Commission Béninfood'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Commission Béninfood'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet livreur : gains par jour/semaine/mois et devises', (
    tester,
  ) async {
    await _pump(tester, _driverBackend());

    // Période par défaut : la semaine.
    expect(find.text(formatAmount(3200, showSymbol: false)), findsWidgets);

    await tester.tap(find.text('Jour'));
    await tester.pumpAndSettle();
    expect(find.text(formatAmount(800, showSymbol: false)), findsWidgets);

    await tester.tap(find.text('Mois'));
    await tester.pumpAndSettle();
    expect(find.text(formatAmount(12500, showSymbol: false)), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Devises'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('EUR'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(
      find.text(formatEuroFromXof(12500, showSymbol: false)),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet livreur : retrait direct dans la feuille Mobile Money', (
    tester,
  ) async {
    final posts = <Map<String, dynamic>>[];
    await _pump(tester, _driverBackend(posts: posts));

    await tester.tap(find.text('Faire un retrait'));
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

    await tester.tap(find.text('Faire un retrait'));
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
