import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/account/coupons_screen.dart';
import 'package:beninfood/features/client/account/favorites_screen.dart';
import 'package:beninfood/features/client/account/notifications_screen.dart';
import 'package:beninfood/features/client/account/payment_methods_screen.dart';
import 'package:beninfood/features/client/account/security_screen.dart';

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

const _notifications = [
  {
    'id': 'n1',
    'type': 'order.accepted',
    'title': 'Commande acceptée',
    'body': 'Chez Awalou prépare votre commande.',
    'read_at': null,
    'created_at': '2026-10-06T10:00:00Z',
  },
];

const _favorites = [
  {
    'id': 'f1',
    'product_id': 'p1',
    'product': {
      'id': 'p1',
      'name': 'Poulet DG',
      'price': 2500,
      'image_url': null,
      'vendor_name': 'Chez Awalou',
    },
  },
];

const _coupons = [
  {
    'code': 'BIENVENUE10',
    'label': 'Bienvenue −10 %',
    'discount_type': 'percent',
    'discount_value': 10,
    'expires_at': '2026-12-31T23:59:59Z',
    'used_at': null,
    'is_available': true,
  },
];

const _devices = [
  {
    'platform': 'android',
    'app_version': '1.2.0',
    'last_seen_at': '2026-10-01T09:00:00Z',
    'is_active': true,
  },
];

MockClient _mockBackend({bool empty = false}) {
  return MockClient((request) async {
    final json = {'content-type': 'application/json'};
    final path = request.url.path;
    if (path.endsWith('/me/notifications')) {
      return http.Response(
        jsonEncode({'data': empty ? const [] : _notifications}),
        200,
        headers: json,
      );
    }
    if (request.method == 'DELETE' && path.contains('/me/favorites')) {
      return http.Response('', 204, headers: json);
    }
    if (path.endsWith('/me/favorites')) {
      return http.Response(
        jsonEncode({'data': empty ? const [] : _favorites}),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/me/coupons')) {
      return http.Response(
        jsonEncode({'data': empty ? const [] : _coupons}),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/me/devices')) {
      return http.Response(
        jsonEncode({'data': empty ? const [] : _devices}),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/me/payment-methods')) {
      return http.Response(
        jsonEncode({'data': empty ? const [] : const []}),
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

MarketplaceApi _api({bool empty = false}) {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(empty: empty),
    baseUrl: 'http://api.test',
  );
  return MarketplaceApi(api);
}

Future<void> _pump(
  WidgetTester tester,
  Widget Function(MarketplaceApi api) build, {
  bool empty = false,
}) async {
  await tester.pumpWidget(MaterialApp(home: build(_api(empty: empty))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('paiement : état vide et feuille d’ajout sans PAN', (
    tester,
  ) async {
    await _pump(tester, (api) => PaymentMethodsScreen(marketplace: api));
    expect(find.text('Méthodes de paiement'), findsOneWidget);
    expect(find.text('Aucun moyen de paiement'), findsOneWidget);

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter un moyen de paiement'), findsOneWidget);
    expect(find.textContaining('Aucun numéro complet'), findsOneWidget);
    expect(find.text('Mobile money'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sécurité : formulaire mot de passe et appareils', (
    tester,
  ) async {
    await _pump(tester, (api) => SecurityScreen(marketplace: api));

    expect(find.text('Sécurité'), findsOneWidget);
    expect(find.text('Changer le mot de passe'), findsOneWidget);
    expect(find.text('Mot de passe actuel'), findsOneWidget);
    expect(
      find.text('Après modification, les autres appareils seront déconnectés.'),
      findsOneWidget,
    );

    // Appareil actif issu de GET /me/devices.
    expect(find.text('ANDROID'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications : liste réelle et bouton « Tout lire »', (
    tester,
  ) async {
    await _pump(tester, (api) => NotificationsScreen(marketplace: api));

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Commande acceptée'), findsOneWidget);
    expect(find.text('Tout lire'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications : état vide', (tester) async {
    await _pump(
      tester,
      (api) => NotificationsScreen(marketplace: api),
      empty: true,
    );

    expect(find.text('Aucune notification pour le moment.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favoris : produit enregistré et retrait', (tester) async {
    await _pump(tester, (api) => FavoritesScreen(marketplace: api));

    expect(find.text('Mes favoris'), findsOneWidget);
    expect(find.text('Poulet DG'), findsOneWidget);
    expect(find.text('2 500 • Chez Awalou'), findsOneWidget);

    await tester.tap(find.byTooltip('Retirer des favoris'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun favori'), findsOneWidget);
    expect(find.text('Retiré des favoris'), findsOneWidget);
    // Laisse le SnackBar expirer pour ne pas laisser de timer en attente.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('favoris : état vide', (tester) async {
    await _pump(
      tester,
      (api) => FavoritesScreen(marketplace: api),
      empty: true,
    );

    expect(find.text('Aucun favori'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coupons : code disponible avec copie', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    await _pump(tester, (api) => CouponsScreen(marketplace: api));

    expect(find.text('Mes coupons'), findsOneWidget);
    expect(find.text('BIENVENUE10'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('10 %'), findsOneWidget);

    await tester.tap(find.text('BIENVENUE10'));
    await tester.pumpAndSettle();

    expect(find.text('Code BIENVENUE10 copié'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('coupons : état vide', (tester) async {
    await _pump(tester, (api) => CouponsScreen(marketplace: api), empty: true);

    expect(find.text('Aucun coupon pour le moment.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
