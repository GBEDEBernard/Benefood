import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/shop/shop_detail_screen.dart';
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

/// Panier vide au départ ; devient « 2 articles / 6 000 FCFA » après ajout.
MockClient _mockBackend() {
  const shop = {
    'id': 'v1',
    'business_name': 'Maquis Chez Awa',
    'description': 'Restaurant 100% béninois.',
    'cover_url': null,
    'logo_url': null,
    'phone': '+229 97 00 00 00',
    'city': 'Cotonou',
    'address': 'C/ 1560, Akpakpa',
    'is_open': true,
    'rating': 4.6,
    'reviews_count': 125,
    'max_preparation_minutes': 25,
    'delivery_fee_share': 0.1,
    'hours': <Map<String, Object?>>[],
    'products': <Map<String, Object?>>[
      {
        'id': 'p1',
        'vendor_id': 'v1',
        'category_id': 'c1',
        'name': 'Poulet braisé',
        'price': 5000,
        'currency': 'XOF',
        'unit': 'portion',
        'is_active': true,
        'is_available': true,
        'is_orderable': true,
        'stock_qty': 10,
        'status': 'active',
        'image_url': null,
        'image_main': null,
      },
      {
        'id': 'p2',
        'vendor_id': 'v1',
        'category_id': 'c1',
        'name': 'Aloko',
        'price': 1000,
        'currency': 'XOF',
        'unit': 'portion',
        'is_active': true,
        'is_available': true,
        'is_orderable': true,
        'stock_qty': 10,
        'status': 'active',
        'image_url': null,
        'image_main': null,
      },
    ],
  };

  var itemsCount = 0;
  var subtotal = 0;

  Map<String, Object?> cart() => {
    'id': 'cart-1',
    'items': <Object?>[],
    'subtotal': subtotal,
    'items_count': itemsCount,
    'currency': 'XOF',
    'vendor': null,
  };

  return MockClient((request) async {
    const json = {'content-type': 'application/json'};
    final path = request.url.path;

    if (path.endsWith('/vendors/v1')) {
      return http.Response(jsonEncode({'data': shop}), 200, headers: json);
    }
    if (request.method == 'GET' && path.endsWith('/me/favorites')) {
      return http.Response(
        jsonEncode({'data': <Object?>[]}),
        200,
        headers: json,
      );
    }
    if (request.method == 'POST' && path.endsWith('/me/favorites')) {
      return http.Response(
        jsonEncode({
          'data': {'id': 'f1', 'product_id': 'p1'},
        }),
        201,
        headers: json,
      );
    }
    if (request.method == 'DELETE' && path.contains('/me/favorites/')) {
      return http.Response('', 204, headers: json);
    }
    if (request.method == 'POST' && path.endsWith('/review')) {
      return http.Response(
        jsonEncode({
          'data': {
            'id': 'r1',
            'rating': 5,
            'product_rating': 5.0,
            'product_reviews_count': 1,
          },
        }),
        201,
        headers: json,
      );
    }
    if (path.endsWith('/cart/items')) {
      itemsCount = 2;
      subtotal = 6000;
      return http.Response(jsonEncode({'data': cart()}), 200, headers: json);
    }
    if (path.endsWith('/cart')) {
      return http.Response(jsonEncode({'data': cart()}), 200, headers: json);
    }
    return http.Response(
      jsonEncode({'message': 'Not found'}),
      404,
      headers: json,
    );
  });
}

GoRouter _router(MarketplaceApi api) {
  return GoRouter(
    initialLocation: '/client/shop/v1',
    routes: [
      GoRoute(
        path: '/client/shop/:id',
        builder: (context, state) => ShopDetailScreen(
          marketplace: api,
          vendorId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/client/product/:id',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('produit'))),
      ),
      GoRoute(
        path: '/client/checkout',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('checkout'))),
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, {MockClient? client}) async {
  final httpClient = client ?? _mockBackend();
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: httpClient,
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: _router(MarketplaceApi(api))),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('fiche boutique : couverture, infos, onglets et liste de plats', (
    tester,
  ) async {
    await _pump(tester);

    final exception = tester.takeException();
    expect(exception, isNull, reason: 'exception pendant le build: $exception');

    // Nom du restaurant.
    expect(find.text('Maquis Chez Awa'), findsOneWidget);

    // Ligne de détails : note, avis et délai de livraison.
    expect(find.text('4,6'), findsOneWidget);
    expect(find.text('(125 avis)'), findsOneWidget);
    expect(find.text('25-40 min'), findsOneWidget);

    // Onglets : Plats actif, Avis et Infos disponibles.
    expect(find.text('Plats'), findsOneWidget);
    expect(find.text('Avis'), findsOneWidget);
    expect(find.text('Infos'), findsOneWidget);

    // Liste des plats : nom + prix en FCFA.
    expect(find.text('Poulet braisé'), findsOneWidget);
    expect(find.text('5 000 FCFA'), findsOneWidget);
    expect(find.text('Aloko'), findsOneWidget);
    expect(find.text('1 000 FCFA'), findsOneWidget);

    // Barre de panier vide.
    expect(find.text('Voir le panier'), findsOneWidget);
    expect(find.text('0 article'), findsOneWidget);
    expect(find.text('0 FCFA'), findsWidgets);
    expect(find.byType(ListSkeleton), findsNothing);
  });

  testWidgets('onglet Avis : note synthétique puis vide informatif', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Avis'));
    await tester.pumpAndSettle();

    expect(find.text('4,6'), findsNWidgets(2));
    expect(find.text('125 avis'), findsOneWidget);
    expect(find.text('Aucun avis à afficher pour le moment'), findsOneWidget);
  });

  testWidgets('onglet Infos : statut, à propos, coordonnées et horaires', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Infos'));
    await tester.pumpAndSettle();

    expect(find.text('Ouvert maintenant'), findsOneWidget);
    expect(find.text('À propos'), findsOneWidget);
    expect(find.text('Restaurant 100% béninois.'), findsOneWidget);
    expect(find.text('Coordonnées'), findsOneWidget);
    expect(find.text('C/ 1560, Akpakpa'), findsOneWidget);
    expect(find.text('Cotonou'), findsOneWidget);
    expect(find.text('+229 97 00 00 00'), findsOneWidget);
  });

  testWidgets('ajout au panier : pastille du header et barre en bas à jour', (
    tester,
  ) async {
    await _pump(tester);

    // Ajout du premier plat via le bouton rond « + ».
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.text('Ajouté au panier'), findsOneWidget);
    expect(find.text('2 articles'), findsOneWidget);
    expect(find.text('6 000 FCFA'), findsOneWidget);

    // Taper une carte de plat ouvre sa fiche.
    await tester.ensureVisible(find.text('Poulet braisé'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poulet braisé'));
    await tester.pumpAndSettle();
    expect(find.text('produit'), findsOneWidget);
  });

  testWidgets('aimer un plat : le cœur et le compteur se mettent à jour', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester);

    // Aucun j'aime au départ.
    expect(find.text('0'), findsWidgets);

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();

    expect(find.text('Ajouté à vos favoris'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsWidgets);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets("noter un plat : la note et le nombre d'avis se mettent à jour", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester);

    await tester.tap(find.text('Noter').first);
    await tester.pumpAndSettle();

    expect(find.text('Envoyer mon avis'), findsOneWidget);

    await tester.tap(find.text('Envoyer mon avis'));
    await tester.pumpAndSettle();

    expect(find.text('Merci pour votre avis !'), findsOneWidget);
    expect(find.text('5,0 (1)'), findsOneWidget);
  });
}
