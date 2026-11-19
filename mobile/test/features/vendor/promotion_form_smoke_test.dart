import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/vendor/promotions/promotion_form_screen.dart';
import 'package:beninfood/shared/models/product.dart';

class _NoopTokenStore implements TokenStore {
  @override
  Future<String?> readToken() async => 'test-token';

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> write(Map<String, dynamic> authPayload) async {}

  @override
  Future<void> clear() async {}
}

List<Product> _products() => [
  const Product(
    id: 'prod-1',
    vendorId: 'vendor-1',
    categoryId: 'cat-1',
    name: 'Attiéké poisson',
    price: 10000,
    currency: 'XOF',
    unit: 'portion',
  ),
  const Product(
    id: 'prod-2',
    vendorId: 'vendor-1',
    categoryId: 'cat-1',
    name: 'Poulet frit',
    price: 5000,
    currency: 'XOF',
    unit: 'portion',
  ),
];

MockClient _mockBackend({
  required Map<String, dynamic>? bulkBody,
  required Map<String, dynamic>? singleBody,
}) {
  final headers = {'content-type': 'application/json'};

  Map<String, dynamic> promotionPayload(String id, String productId, int price) =>
      {
    'id': id,
    'product_id': productId,
    'vendor_id': 'vendor-1',
    'promo_price': price,
    'original_price': 10000,
    'discount_percent': 20,
    'is_active': true,
  };

  return MockClient((request) async {
    final path = request.url.path;

    if (path.endsWith('/me/stats')) {
      return http.Response(
        jsonEncode({'data': {'unread_notifications': 0}}),
        200,
        headers: headers,
      );
    }

    if (request.method == 'POST' && path.endsWith('/promotions/bulk')) {
      bulkBody?.addAll(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode({
          'data': {
            'promotions': [promotionPayload('promo-1', 'prod-1', 8000)],
            'skipped': <dynamic>[],
            'created_count': 1,
            'skipped_count': 0,
          },
        }),
        201,
        headers: headers,
      );
    }

    if (request.method == 'POST' && path.contains('/promotions/products/')) {
      singleBody?.addAll(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode({
          'data': promotionPayload('promo-2', 'prod-1', 6000),
        }),
        201,
        headers: headers,
      );
    }

    return http.Response(
      jsonEncode({'message': 'Not found'}),
      404,
      headers: headers,
    );
  });
}

Future<void> _pumpForm(
  WidgetTester tester,
  MockClient client, {
  List<Product>? products,
}) async {
  tester.view.physicalSize = const Size(420, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: client,
    baseUrl: 'http://api.test',
  );
  final marketplace = MarketplaceApi(api);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PromotionFormScreen(
                    marketplace: marketplace,
                    products: products ?? _products(),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Finder _fieldWithLabel(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(TextFormField),
);

Future<void> _enterPercent(WidgetTester tester, String value) async {
  await tester.enterText(
    _fieldWithLabel('Pourcentage de réduction (%)'),
    value,
  );
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.scrollUntilVisible(
    button,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  testWidgets('pourcentage appliqué à plusieurs plats envoie la sélection', (
    tester,
  ) async {
    final bulkBody = <String, dynamic>{};
    await _pumpForm(
      tester,
      _mockBackend(bulkBody: bulkBody, singleBody: <String, dynamic>{}),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Comment fixer la remise ?'), findsOneWidget);
    expect(find.text('Appliquer la remise à…'), findsOneWidget);
    expect(find.text('1 plat'), findsOneWidget);
    expect(find.text('Plusieurs plats'), findsOneWidget);
    expect(find.text('Tous les plats'), findsOneWidget);

    await tester.tap(find.text('Plusieurs plats'));
    await tester.pump();
    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.pump();
    expect(find.text('2 plat(s) sélectionné(s)'), findsOneWidget);

    await _enterPercent(tester, '20');
    expect(find.text('−20 %'), findsOneWidget);

    await _tapSave(tester, 'Créer 2 offres');

    expect(bulkBody, isNotEmpty);
    expect(bulkBody['discount_percent'], 20);
    expect(bulkBody['product_ids'], ['prod-1', 'prod-2']);
    expect(bulkBody.containsKey('all_products'), isFalse);
    expect(bulkBody['starts_at'], isA<String>());
    expect(bulkBody['ends_at'], isA<String>());
  });

  testWidgets('pourcentage appliqué à tous les plats envoie all_products', (
    tester,
  ) async {
    final bulkBody = <String, dynamic>{};
    await _pumpForm(
      tester,
      _mockBackend(bulkBody: bulkBody, singleBody: <String, dynamic>{}),
    );

    await tester.tap(find.text('Tous les plats'));
    await tester.pump();
    expect(find.text('Toute la boutique'), findsOneWidget);

    await _enterPercent(tester, '15');
    expect(find.text('−15 %'), findsOneWidget);

    await _tapSave(tester, 'Créer 2 offres');

    expect(bulkBody, isNotEmpty);
    expect(bulkBody['discount_percent'], 15);
    expect(bulkBody['all_products'], isTrue);
    expect(bulkBody.containsKey('product_ids'), isFalse);
  });

  testWidgets('prix fixe reste limité à un seul plat', (tester) async {
    final singleBody = <String, dynamic>{};
    await _pumpForm(
      tester,
      _mockBackend(
        bulkBody: <String, dynamic>{},
        singleBody: singleBody,
      ),
    );

    await tester.tap(find.text('Prix fixe'));
    await tester.pump();

    expect(find.text('Appliquer la remise à…'), findsNothing);
    expect(_fieldWithLabel('Prix promo (FCFA)'), findsOneWidget);

    await tester.enterText(_fieldWithLabel('Prix promo (FCFA)'), '6000');
    await tester.pump();
    await _tapSave(tester, 'Créer la promotion');

    expect(singleBody, isNotEmpty);
    expect(singleBody['promo_price'], 6000);
  });
}
