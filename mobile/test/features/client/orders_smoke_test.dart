import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/orders/orders_screen.dart';
import 'package:beninfood/shared/widgets/state_widgets.dart';

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

Map<String, dynamic> _order({
  required String id,
  required String reference,
  required String status,
  required String vendor,
  required int total,
  String? updatedAt,
  String? cancellationReason,
  Map<String, dynamic>? delivery,
}) {
  return {
    'id': id,
    'reference': reference,
    'status': status,
    'payment_status': 'paid',
    'subtotal': total - 500,
    'delivery_fee': 500,
    'total': total,
    'delivery_address': 'Akpakpa, Cotonou',
    'created_at': '2025-05-04T12:30:00Z',
    'updated_at': updatedAt,
    'cancellation_reason': cancellationReason,
    'vendor': {'id': 'v1', 'business_name': vendor},
    'items': [
      {
        'id': 'i1',
        'name': 'Poulet DG',
        'quantity': 1,
        'unit_price': total - 500,
        'subtotal': total - 500,
        'image_url': null,
      },
    ],
    'delivery': delivery,
  };
}

MockClient _mockBackend() {
  final orders = [
    _order(
      id: '1',
      reference: 'BEN-260929-SAE3ZC',
      status: 'in_delivery',
      vendor: 'Chez Awalou',
      total: 5500,
      delivery: {
        'id': 'd1',
        'status': 'in_delivery',
        'driver': {
          'id': 'dr1',
          'name': 'Kofi',
          'phone': '+22997000001',
        },
      },
    ),
    _order(
      id: '2',
      reference: 'BEN-260929-K7DPXM',
      status: 'delivered',
      vendor: 'La Boulangerie du Centre',
      total: 2500,
      updatedAt: '2025-05-04T13:10:00Z',
    ),
    _order(
      id: '3',
      reference: 'BEN-260929-8QJ4RT',
      status: 'cancelled',
      vendor: 'Maison Tantie',
      total: 3000,
      cancellationReason: 'Restaurant indisponible',
    ),
    _order(
      id: '4',
      reference: 'BEN-260929-ZZ44AA',
      status: 'awaiting_payment',
      vendor: 'Le Grill Royal',
      total: 7000,
    ),
  ];

  return MockClient((request) async {
    final json = {'content-type': 'application/json'};
    if (request.url.path.endsWith('/orders')) {
      return http.Response(jsonEncode({'data': orders}), 200, headers: json);
    }
    return http.Response(jsonEncode({'message': 'Not found'}), 404, headers: json);
  });
}

Future<void> _pumpOrders(WidgetTester tester) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(),
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(home: OrdersScreen(marketplace: MarketplaceApi(api))),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('commandes : en-tête, onglets et carte en cours avec progression',
      (tester) async {
    await _pumpOrders(tester);
    final exception = tester.takeException();
    expect(exception, isNull, reason: 'exception pendant le build: $exception');

    expect(find.text('Mes commandes'), findsOneWidget);
    expect(find.text('Toutes'), findsOneWidget);
    // Le libellé « En cours » sert aussi d'étiquette de statut sur la carte
    // in_delivery (l'autre carte active est « À payer »).
    expect(find.text('En cours'), findsNWidgets(2));
    expect(find.text('Terminées'), findsOneWidget);
    expect(find.text('Annulées'), findsOneWidget);

    expect(find.text('Chez Awalou'), findsOneWidget);
    expect(find.text('#SAE3ZC'), findsOneWidget);
    expect(find.text('5 500 FCFA'), findsOneWidget);
    expect(find.text('Livraison en cours'), findsOneWidget);

    // Seule la première carte active est visible dans le viewport : elle
    // affiche la progression et les actions.
    expect(find.text('Confirmée'), findsOneWidget);
    expect(find.text('En livraison'), findsOneWidget);
    expect(find.text('Livrée'), findsOneWidget);
    expect(find.text('Voir détails'), findsOneWidget);
    expect(find.text('Contacter le livreur'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Le Grill Royal'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Le Grill Royal'), findsOneWidget);
    expect(find.text('À payer'), findsOneWidget);
    expect(find.text('Paiement en attente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('commandes : onglets Terminées et Annulées filtrent les cartes',
      (tester) async {
    await _pumpOrders(tester);

    await tester.tap(find.text('Terminées'));
    await tester.pump();
    expect(find.text('La Boulangerie du Centre'), findsOneWidget);
    expect(find.text('Chez Awalou'), findsNothing);
    expect(find.text('Noter votre commande'), findsOneWidget);
    expect(find.text('Terminée'), findsOneWidget);
    expect(
      find.textContaining('Livrée le'),
      findsOneWidget,
      reason: 'date de livraison en français',
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Annulées'));
    await tester.pump();
    expect(find.text('Maison Tantie'), findsOneWidget);
    expect(find.text('La Boulangerie du Centre'), findsNothing);
    expect(find.text('Annulée'), findsOneWidget);
    expect(find.text('Restaurant indisponible'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('En cours'));
    await tester.pump();
    expect(find.text('Chez Awalou'), findsOneWidget);
    expect(find.text('Le Grill Royal'), findsOneWidget);
    expect(find.text('Paiement en attente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('commandes : état vide sans erreur de layout', (tester) async {
    final api = ApiClient(
      tokenStore: _NoopTokenStore(),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      baseUrl: 'http://api.test',
    );
    await tester.pumpWidget(
      MaterialApp(home: OrdersScreen(marketplace: MarketplaceApi(api))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ListSkeleton), findsNothing);
    expect(find.text('Aucune commande'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
