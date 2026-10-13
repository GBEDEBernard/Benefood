import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/core/navigation/notification_router.dart';
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

const _notifications = [
  {
    'id': 'n1',
    'type': 'order.paid',
    'title': 'Commande reçue',
    'body': 'Nouvelle commande #BF-0107 à préparer.',
    'order_id': 'o-1',
    'data': {'order_id': 'o-1', 'reference': 'BF-0107'},
    'read_at': null,
    'created_at': '2026-10-07T08:30:00Z',
  },
  {
    'id': 'n2',
    'type': 'delivery.offered',
    'title': 'Nouvelle course disponible',
    'body': 'Nouvelle course #BF-0200 disponible.',
    'data': {'delivery_id': 'd-9'},
    'read_at': null,
    'created_at': '2026-10-07T09:00:00Z',
  },
  {
    'id': 'n3',
    'type': 'parcel.delivered',
    'title': 'Colis livré',
    'body': 'Votre colis #COL-2010 a été livré.',
    'data': {'parcel_id': 'p-7', 'reference': 'COL-2010'},
    'read_at': null,
    'created_at': '2026-10-07T10:00:00Z',
  },
];

MockClient _mockBackend() {
  const headers = {'content-type': 'application/json'};
  return MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/me/stats')) {
      return http.Response(
        jsonEncode({
          'data': {'unread_notifications': 2},
        }),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/read-all')) {
      return http.Response(jsonEncode({'data': {'updated': 2}}), 200,
          headers: headers);
    }
    if (path.endsWith('/me/notifications')) {
      return http.Response(
        jsonEncode({'data': _notifications}),
        200,
        headers: headers,
      );
    }
    if (path.contains('/me/notifications/')) {
      return http.Response(
        jsonEncode({
          'data': {'id': 'n1', 'read_at': '2026-10-07T10:00:00Z'},
        }),
        200,
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

MarketplaceApi _api() => MarketplaceApi(
  ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(),
    baseUrl: 'http://api.test',
  ),
);

/// Message intégral de la feuille de détail : la tuile de la liste, elle,
/// tronque le texte (`maxLines: 2`).
Finder _fullBody(String value) => find.byWidgetPredicate(
  (widget) => widget is Text && widget.data == value && widget.maxLines == null,
);

Future<void> _pumpBell(
  WidgetTester tester,
  NotificationAudience audience,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: NotificationBell(api: _api(), audience: audience)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('audience déduite du contexte actif', () {
    expect(
      notificationAudienceFromRole('vendor'),
      NotificationAudience.vendor,
    );
    expect(
      notificationAudienceFromRole('driver'),
      NotificationAudience.driver,
    );
    expect(
      notificationAudienceFromRole('client'),
      NotificationAudience.client,
    );
    expect(notificationAudienceFromRole(null), NotificationAudience.client);
  });

  testWidgets('cloche vendeur : liste réelle puis contenu complet', (
    tester,
  ) async {
    await _pumpBell(tester, NotificationAudience.vendor);

    // Pastille = notifications non lues (GET /me/stats).
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    expect(find.text('Commande reçue'), findsOneWidget);
    expect(find.text('Nouvelle course disponible'), findsOneWidget);

    await tester.tap(find.text('Commande reçue'));
    await tester.pumpAndSettle();

    // Détail : catégorie, message intégral et action vers la commande vendeur.
    expect(find.text('Commande'), findsOneWidget);
    expect(_fullBody('Nouvelle commande #BF-0107 à préparer.'), findsOneWidget);
    expect(find.text('Ouvrir la commande'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cloche livreur : l’action ouvre la mission', (tester) async {
    await _pumpBell(tester, NotificationAudience.driver);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nouvelle course disponible'));
    await tester.pumpAndSettle();

    expect(find.text('Livraison'), findsOneWidget);
    expect(_fullBody('Nouvelle course #BF-0200 disponible.'), findsOneWidget);
    expect(find.text('Ouvrir la mission'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cloche client : l’action ouvre le suivi de commande', (
    tester,
  ) async {
    await _pumpBell(tester, NotificationAudience.client);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Commande reçue'));
    await tester.pumpAndSettle();

    expect(find.text('Suivre la commande'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cloche : bandeau à l’arrivée d’une nouvelle notification', (
    tester,
  ) async {
    var unread = 1;
    const headers = {'content-type': 'application/json'};
    final api = MarketplaceApi(
      ApiClient(
        tokenStore: _NoopTokenStore(),
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/me/stats')) {
            return http.Response(
              jsonEncode({
                'data': {'unread_notifications': unread},
              }),
              200,
              headers: headers,
            );
          }
          return http.Response(
            jsonEncode({'data': _notifications}),
            200,
            headers: headers,
          );
        }),
        baseUrl: 'http://api.test',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: NotificationBell(api: api))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Premier chargement : pas de bandeau, seulement la pastille.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('1'), findsOneWidget);

    // Une notification arrive : le poll suivant la signale.
    unread = 2;
    await tester.pump(const Duration(seconds: 31));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Commande reçue'), findsOneWidget);
    expect(find.text('Voir'), findsOneWidget);

    // Le bandeau ouvre le contenu complet de la notification.
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();

    expect(_fullBody('Nouvelle commande #BF-0107 à préparer.'), findsOneWidget);
    expect(find.text('Suivre la commande'), findsOneWidget);

    // Laisse le bandeau expirer pour ne pas laisser de timer en attente.
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cloche vendeur : notification de colis lisible', (tester) async {
    await _pumpBell(tester, NotificationAudience.vendor);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Colis livré'));
    await tester.pumpAndSettle();

    expect(find.text('Colis'), findsOneWidget);
    expect(_fullBody('Votre colis #COL-2010 a été livré.'), findsOneWidget);
    expect(find.text('Suivre le colis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cloche : état vide de la liste', (tester) async {
    final api = MarketplaceApi(
      ApiClient(
        tokenStore: _NoopTokenStore(),
        httpClient: MockClient((request) async {
          final headers = {'content-type': 'application/json'};
          if (request.url.path.endsWith('/me/stats')) {
            return http.Response(
              jsonEncode({
                'data': {'unread_notifications': 0},
              }),
              200,
              headers: headers,
            );
          }
          return http.Response(
            jsonEncode({'data': const []}),
            200,
            headers: headers,
          );
        }),
        baseUrl: 'http://api.test',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: NotificationBell(api: api))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    expect(find.text('Aucune notification pour le moment.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
