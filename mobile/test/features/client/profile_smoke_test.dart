import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/auth/session_provider.dart';
import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/account/account_screen.dart';

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

/// Backend de test : statistiques réelles, cloche avec 2 non lues,
/// feuille de notifications alimentée, tout le reste en 404.
MockClient _mockBackend() {
  const stats = {
    'orders_count': 23,
    'favorites_count': 7,
    'coupons_count': 3,
    'wallet_balance': 24500,
    'unread_notifications': 2,
  };
  const notifications = [
    {
      'id': 'n1',
      'type': 'order.accepted',
      'title': 'Commande acceptée',
      'body': 'Chez Awalou prépare votre commande.',
      'read_at': null,
      'created_at': '2026-10-06T10:00:00Z',
    },
    {
      'id': 'n2',
      'type': 'order.delivered',
      'title': 'Commande livrée',
      'body': 'Bon appétit !',
      'read_at': '2026-10-05T10:00:00Z',
      'created_at': '2026-10-05T10:00:00Z',
    },
  ];

  return MockClient((request) async {
    final json = {'content-type': 'application/json'};
    final path = request.url.path;
    if (path.endsWith('/me/stats')) {
      return http.Response(jsonEncode({'data': stats}), 200, headers: json);
    }
    if (path.endsWith('/me/notifications')) {
      return http.Response(
        jsonEncode({'data': notifications}),
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

late int _selectedTab;

GoRouter _router(SessionProvider session, MarketplaceApi api) {
  const sections = [
    '/client/profile/edit',
    '/client/addresses',
    '/client/payment-methods',
    '/client/notifications',
    '/client/security',
    '/client/complaints',
    '/client/favorites',
    '/client/coupons',
  ];
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => AccountScreen(
          session: session,
          marketplace: api,
          onSelectTab: (index) => _selectedTab = index,
        ),
      ),
      for (final path in sections)
        GoRoute(
          path: path,
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Section')),
            body: Center(child: Text(path)),
          ),
        ),
      GoRoute(
        path: '/landing',
        builder: (context, state) => const Scaffold(body: Text('landing')),
      ),
    ],
  );
}

SessionProvider _session(ApiClient api) => SessionProvider(api: api);

Future<void> _pumpScreen(WidgetTester tester, {MockClient? client}) async {
  final httpClient = client ?? _mockBackend();
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: httpClient,
    baseUrl: 'http://api.test',
  );
  final session = _session(api);
  final router = _router(session, MarketplaceApi(api));
  _selectedTab = -1;
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Descend jusqu'à un libellé donné (construit toute la colonne).
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final verticalScrollable = find
      .byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
        skipOffstage: false,
      )
      .first;
  await tester.scrollUntilVisible(target, 400, scrollable: verticalScrollable);
}

void main() {
  testWidgets('profil : en-tête, carte verte, statistiques et menu', (
    tester,
  ) async {
    await _pumpScreen(tester);
    expect(tester.takeException(), isNull);

    // En-tête + titre (utilisateur non connecté → repli « Utilisateur »).
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Utilisateur'), findsOneWidget);
    expect(find.text('⭐ 4,7'), findsOneWidget);
    expect(find.text('Client fidèle'), findsOneWidget);

    // Statistiques dynamiques (GET /me/stats).
    expect(find.text('23'), findsOneWidget);
    expect(find.text('Commandes'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Favoris'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Coupons'), findsOneWidget);
    // Text.rich : valeur + suffixe FCFA dans le même widget.
    expect(find.text('24 500 FCFA', findRichText: true), findsOneWidget);
    expect(find.text('Portefeuille'), findsOneWidget);
    // Pastille de la cloche = notifications non lues.
    expect(find.text('2'), findsOneWidget);

    // Menu « Mon compte » : les 6 entrées de la spec.
    expect(find.text('Mon compte'), findsOneWidget);
    await _scrollTo(tester, find.text('Se déconnecter'));
    const titles = [
      'Informations personnelles',
      'Adresses enregistrées',
      'Méthodes de paiement',
      'Notifications',
      'Sécurité',
      'Aide et support',
    ];
    for (final title in titles) {
      expect(find.text(title), findsOneWidget, reason: 'entrée $title');
    }
    expect(find.text('Nom, e-mail, photo...'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profil : cloche avec pastille 2 ouvre les notifications réelles',
    (tester) async {
      await _pumpScreen(tester);

      // La cloche (tooltip) et non l'entrée de menu du même nom.
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Commande acceptée'), findsOneWidget);
      expect(find.text('Commande livrée'), findsOneWidget);

      // Marquage lu : POST /me/notifications/{id}/read (404 muet en test).
      await tester.tap(find.text('Commande acceptée'));
      await tester.pumpAndSettle();

      expect(find.text('Commande acceptée'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profil : bouton déconnexion ouvre la confirmation', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await _scrollTo(tester, find.text('Se déconnecter'));

    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();

    expect(
      find.text('Voulez-vous vraiment vous déconnecter ?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Voulez-vous vraiment vous déconnecter ?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profil : QR de contact s’ouvre dans une feuille', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.qr_code));
    await tester.pumpAndSettle();

    expect(find.text('Ma carte de contact'), findsOneWidget);
    expect(
      find.text('Scannez ce code pour enregistrer mes coordonnées.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profil : le menu ouvre les sections dédiées', (tester) async {
    await _pumpScreen(tester);
    await _scrollTo(tester, find.text('Méthodes de paiement'));

    await tester.tap(find.text('Méthodes de paiement'));
    await tester.pumpAndSettle();
    expect(find.text('/client/payment-methods'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Informations personnelles'));
    await tester.tap(find.text('Informations personnelles'));
    await tester.pumpAndSettle();
    expect(find.text('/client/profile/edit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profil : statistiques tapables (commandes, favoris, coupons)', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Commandes'));
    await tester.pump();
    expect(_selectedTab, 3);

    await tester.tap(find.text('Favoris'));
    await tester.pumpAndSettle();
    expect(find.text('/client/favorites'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coupons'));
    await tester.pumpAndSettle();
    expect(find.text('/client/coupons'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portefeuille'));
    await tester.pumpAndSettle();
    expect(find.text('Portefeuille Béninfood'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
