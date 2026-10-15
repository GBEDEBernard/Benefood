import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/checkout/checkout_screen.dart';
import 'package:beninfood/features/client/orders/orders_screen.dart';

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

Map<String, dynamic> _orderPayload({required String paymentMethod}) => {
      'id': 'o1',
      'reference': 'BEN-261013-CASH01',
      'status': 'awaiting_payment',
      'payment_status': 'initiated',
      'payment_method': paymentMethod,
      'subtotal': 5000,
      'delivery_fee': 1000,
      'total': 6300,
      'created_at': '2026-10-13T10:00:00Z',
      'vendor': {'id': 'v1', 'business_name': 'Chez Awalou'},
      'items': [
        {
          'id': 'i1',
          'name': 'Poulet DG',
          'quantity': 1,
          'unit_price': 5000,
          'subtotal': 5000,
        },
      ],
    };

/// Backend simulé du checkout : adresses, récapitulatif, commande et paiement.
class _CheckoutBackend {
  final List<Map<String, dynamic>> orderBodies = [];
  int paymentCreateCalls = 0;

  MockClient client() => MockClient((request) async {
        final jsonHeaders = {'content-type': 'application/json'};
        final path = request.url.path;

        if (path.endsWith('/addresses')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'a1',
                  'full_address': 'Akpakpa, Cotonou',
                  'city': 'Cotonou',
                },
              ],
            }),
            200,
            headers: jsonHeaders,
          );
        }

        if (path.endsWith('/orders/summary')) {
          return http.Response(
            jsonEncode({
              'data': {
                'subtotal': 5000,
                'delivery_fee': 1000,
                'service_fee': 300,
                'total': 6300,
                'items': const [],
              },
            }),
            200,
            headers: jsonHeaders,
          );
        }

        if (path.endsWith('/payments/create')) {
          paymentCreateCalls++;
          return http.Response(
            jsonEncode({
              'data': {
                'provider': 'fedapay',
                'status': 'pending',
                'amount': 6300,
                'checkout_url': null,
                'transaction_id': null,
              },
            }),
            200,
            headers: jsonHeaders,
          );
        }

        if (path.endsWith('/orders')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          orderBodies.add(body);
          return http.Response(
            jsonEncode({
              'data': _orderPayload(
                paymentMethod: body['payment_method'] as String? ?? 'online',
              ),
            }),
            201,
            headers: jsonHeaders,
          );
        }

        return http.Response(jsonEncode({'message': 'Not found'}), 404,
            headers: jsonHeaders);
      });
}

Future<void> _pumpCheckout(WidgetTester tester, _CheckoutBackend backend) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: backend.client(),
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(home: CheckoutScreen(marketplace: MarketplaceApi(api))),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tapCommander(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byType(FilledButton),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byType(FilledButton).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
      'checkout : l\'option « paiement à la livraison » envoie payment_method=cash '
      'et n\'appelle pas la passerelle', (tester) async {
    final backend = _CheckoutBackend();
    await _pumpCheckout(tester, backend);

    expect(find.text('Mode de paiement'), findsOneWidget);

    // L'en-tête BÉN INFOOD occupe le haut de l'écran : les options de
    // paiement se trouvent plus bas dans la liste, on défile jusqu'à elles.
    final onlineOption = find.text('Mobile Money (en ligne)');
    await tester.scrollUntilVisible(
      onlineOption,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(onlineOption, findsOneWidget);

    final cashOption = find.text('Paiement à la livraison');
    await tester.scrollUntilVisible(
      cashOption,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(cashOption);
    await tester.pumpAndSettle();
    await tester.tap(cashOption);
    await tester.pump();
    expect(
      find.textContaining('en espèces pour le livreur'),
      findsOneWidget,
      reason: 'montant à prévoir affiché au client',
    );

    await _tapCommander(tester);

    expect(backend.orderBodies, hasLength(1));
    expect(backend.orderBodies.single['payment_method'], 'cash');
    expect(
      backend.paymentCreateCalls,
      0,
      reason: 'commandes cash : aucun appel à la passerelle de paiement',
    );
    expect(find.text('Commande enregistrée !'), findsOneWidget);
    expect(find.textContaining('en espèces au livreur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout : Mobile Money reste le défaut et passe par la passerelle',
      (tester) async {
    final backend = _CheckoutBackend();
    await _pumpCheckout(tester, backend);

    await _tapCommander(tester);

    expect(backend.orderBodies.single['payment_method'], 'online');
    expect(backend.paymentCreateCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('commandes : une commande cash en attente s\'affiche « à la livraison »',
      (tester) async {
    final backend = _CheckoutBackend();
    final api = ApiClient(
      tokenStore: _NoopTokenStore(),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [_orderPayload(paymentMethod: 'cash')],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUrl: 'http://api.test',
    );

    await tester.pumpWidget(
      MaterialApp(home: OrdersScreen(marketplace: MarketplaceApi(api))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('À la livraison'), findsOneWidget);
    expect(find.text('Paiement en espèces à la livraison'), findsOneWidget);
    expect(find.text('À payer'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(backend.orderBodies, isEmpty);
  });
}
