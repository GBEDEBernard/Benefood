import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/product/product_detail_screen.dart';
import 'package:beninfood/shared/widgets/product_media_gallery.dart';

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

MockClient _mockBackend() {
  return MockClient((request) async {
    const json = {'content-type': 'application/json'};
    final path = request.url.path;

    if (path.endsWith('/products/p1')) {
      return http.Response(
        jsonEncode({
          'data': {
            'id': 'p1',
            'vendor_id': 'v1',
            'vendor_name': 'Chez Awa',
            'category_id': 'c1',
            'name': 'Poulet braisé',
            'description': 'Poulet mariné et grillé.',
            'price': 5000,
            'currency': 'XOF',
            'unit': 'portion',
            'is_active': true,
            'is_available': true,
            'is_orderable': true,
            'stock_qty': 10,
            'status': 'active',
            'rating': 4.6,
            'reviews_count': 12,
            'likes_count': 30,
            'image_url': 'http://api.test/storage/products/p1/main.webp',
            'images': [
              {
                'id': 'image-main',
                'url': 'http://api.test/storage/products/p1/main.webp',
                'is_main': true,
              },
              {
                'id': 'image-second',
                'url': 'http://api.test/storage/products/p1/second.webp',
                'is_main': false,
              },
            ],
            'video_url': 'http://api.test/storage/products/p1/video.mp4',
          },
        }),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/me/favorites')) {
      return http.Response(
        jsonEncode({'data': <Object?>[]}),
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

Future<void> _pump(WidgetTester tester) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(),
    baseUrl: 'http://api.test',
  );
  final marketplace = MarketplaceApi(api);
  final router = GoRouter(
    initialLocation: '/client/product/p1',
    routes: [
      GoRoute(
        path: '/client/product/:id',
        builder: (context, state) => ProductDetailScreen(
          marketplace: marketplace,
          productId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/client',
        builder: (context, state) => const Scaffold(body: Text('accueil')),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('fiche produit : galerie, note, avis et j\'aime', (tester) async {
    await _pump(tester);

    final exception = tester.takeException();
    expect(exception, isNull, reason: 'exception pendant le build: $exception');

    expect(find.byType(ProductMediaGallery), findsOneWidget);
    final gallery = find.byType(ProductMediaGallery);
    final pageView = tester.widget<PageView>(
      find.descendant(of: gallery, matching: find.byType(PageView)),
    );
    expect(
      (pageView.childrenDelegate as SliverChildBuilderDelegate).childCount,
      3,
      reason: '2 photos et la vidéo doivent apparaître dans la galerie',
    );
    final firstImage = tester.widget<Image>(
      find.descendant(of: gallery, matching: find.byType(Image)).first,
    );
    expect((firstImage.image as NetworkImage).url, contains('/main.webp'));
    expect(find.text('Poulet braisé'), findsOneWidget);
    expect(find.text('4,6 (12 avis)'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Chez Awa'), findsOneWidget);
  });
}
