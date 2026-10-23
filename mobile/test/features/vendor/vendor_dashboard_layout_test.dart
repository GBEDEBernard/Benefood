import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/vendor/restaurant/screens/dashboard_screen.dart';
import 'package:beninfood/shared/models/order.dart';
import 'package:beninfood/shared/widgets/app_network_image.dart';

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

Order _order(
  String reference,
  String product,
  int price, {
  String status = 'delivered',
}) {
  final item = OrderItem(
    id: '$reference-item',
    productId: '$reference-product',
    name: product,
    quantity: 1,
    unitPrice: price,
    subtotal: price,
    imageUrl: 'http://localhost:8000/storage/products/$reference.webp',
  );

  return Order(
    id: reference,
    reference: reference,
    status: status,
    paymentStatus: 'paid',
    items: [item],
    subtotal: price,
    deliveryFee: 0,
    total: price,
    createdAt: DateTime.now().toIso8601String(),
  );
}

Future<void> _pumpDashboard(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final orders = [
    _order('BF-POULET', 'Poulet braisé', 3500),
    _order('BF-RIZ', 'Riz au gras', 2500),
    _order('BF-JUS', 'Jus de bissap', 500),
    _order('BF-PIZZA', 'Pizza', 4000, status: 'paid'),
  ];

  final api = MarketplaceApi(
    ApiClient(tokenStore: _NoopTokenStore(), baseUrl: 'http://api.test'),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DashboardScreen(
          isOpen: true,
          onOpenDrawer: () {},
          onToggleOpen: (_) {},
          orders: orders,
          newOrders: [orders.last],
          pendingCount: 1,
          marketplace: api,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.text('Produits les plus vendus'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();

  expect(find.text('Produits les plus vendus'), findsOneWidget);
  expect(find.text('Poulet braisé'), findsWidgets);
  expect(find.text('Riz au gras'), findsOneWidget);

  final images = tester
      .widgetList<AppNetworkImage>(find.byType(AppNetworkImage))
      .toList();
  expect(images, isNotEmpty);
  expect(
    images.any((image) => image.url?.contains('BF-POULET') == true),
    isTrue,
  );
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('tableau de bord : grille produits responsive sur mobile', (
    tester,
  ) async {
    await _pumpDashboard(tester, const Size(320, 720));
  });

  testWidgets('tableau de bord : grille produits responsive sur tablette', (
    tester,
  ) async {
    await _pumpDashboard(tester, const Size(1180, 900));
  });
}
