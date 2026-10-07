import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/auth/session_provider.dart';
import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/core/utils/formatters.dart';
import 'package:beninfood/features/vendor/account/vendor_account_screen.dart';

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

/// Backend de test : statut boutique actif, 3 produits, 2 commandes
/// (1 livrée → revenus, 1 payée → en attente), cloche avec 2 non lues.
MockClient _mockBackend() {
  const status = {
    'vendor': {
      'status': 'active',
      'business_name': 'Chez Awalou',
      'city': 'Lomé',
      'phone': '+228 90 00 00 00',
    },
    'documents': [],
  };
  const products = [
    {'id': 'p1', 'name': 'Riz parfumé', 'price': 1500},
    {'id': 'p2', 'name': 'Huile', 'price': 900},
    {'id': 'p3', 'name': 'Sucre', 'price': 700},
  ];
  const orders = [
    {
      'id': 'o1',
      'reference': 'CMD-1',
      'status': 'delivered',
      'payment_status': 'paid',
      'subtotal': 1500,
      'delivery_fee': 0,
      'total': 1500,
      'items': [],
    },
    {
      'id': 'o2',
      'reference': 'CMD-2',
      'status': 'paid',
      'payment_status': 'paid',
      'subtotal': 500,
      'delivery_fee': 0,
      'total': 500,
      'items': [],
    },
  ];
  const stats = {'orders_count': 23, 'unread_notifications': 2};
  const notifications = [
    {
      'id': 'n1',
      'type': 'order.paid',
      'title': 'Commande payée',
      'body': 'CMD-2 est en attente de validation.',
      'read_at': null,
      'created_at': '2026-10-06T10:00:00Z',
    },
  ];

  return MockClient((request) async {
    final json = {'content-type': 'application/json'};
    final path = request.url.path;
    if (path.endsWith('/vendors/me/status')) {
      return http.Response(jsonEncode({'data': status}), 200, headers: json);
    }
    if (path.endsWith('/vendors/me/products')) {
      return http.Response(jsonEncode({'data': products}), 200, headers: json);
    }
    if (path.endsWith('/vendors/me/orders')) {
      return http.Response(jsonEncode({'data': orders}), 200, headers: json);
    }
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
    '/vendor/profile/edit',
    '/vendor/notifications',
    '/vendor/security',
    '/vendor/complaints',
  ];
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => VendorAccountScreen(
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

Future<void> _pumpScreen(WidgetTester tester, {MockClient? client}) async {
  final httpClient = client ?? _mockBackend();
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: httpClient,
    baseUrl: 'http://api.test',
  );
  final session = SessionProvider(api: api);
  final router = _router(session, MarketplaceApi(api));
  _selectedTab = -1;
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

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
  testWidgets('compte vendeur : carte verte, stats boutique et menu', (
    tester,
  ) async {
    await _pumpScreen(tester);
    expect(tester.takeException(), isNull);

    // Carte verte : identité, badges, boutique.
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Utilisateur'), findsOneWidget);
    expect(find.text('Espace vendeur'), findsOneWidget);
    expect(
      find.text('Active'),
      findsNWidgets(2), // pastille verte + badge de la carte boutique
    );

    // Statistiques dynamiques (status + produits + commandes).
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Produits'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2)); // commandes + pastille cloche
    expect(find.text('Commandes'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(
      find.text(
        '${formatAmount(1500, showSymbol: false).trim()} FCFA',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Revenus'), findsOneWidget);

    // Bloc boutique (sections conservées).
    await _scrollTo(tester, find.text('Ma boutique'));
    expect(find.text('Ma boutique'), findsOneWidget);
    expect(find.text('Chez Awalou'), findsOneWidget);
    await _scrollTo(tester, find.text('Couverture'));
    expect(find.text('Photo de la boutique'), findsOneWidget);
    expect(find.text('Logo'), findsOneWidget);
    expect(find.text('Couverture'), findsOneWidget);

    // Menu « Mon compte » : 4 entrées communes.
    await _scrollTo(tester, find.text('Se déconnecter'));
    const titles = [
      'Informations personnelles',
      'Notifications',
      'Sécurité',
      'Aide et support',
    ];
    for (final title in titles) {
      expect(find.text(title), findsOneWidget, reason: 'entrée $title');
    }
    expect(find.text('Se déconnecter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compte vendeur : statistiques tapables (onglets)', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Produits'));
    await tester.pump();
    expect(_selectedTab, 1);

    await tester.tap(find.text('Commandes'));
    await tester.pump();
    expect(_selectedTab, 2);

    await tester.tap(find.text('En attente'));
    await tester.pump();
    expect(_selectedTab, 2);

    await tester.tap(find.text('Revenus'));
    await tester.pump();
    expect(_selectedTab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compte vendeur : le menu ouvre les sections dédiées', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await _scrollTo(tester, find.text('Informations personnelles'));

    await tester.tap(find.text('Informations personnelles'));
    await tester.pumpAndSettle();
    expect(find.text('/vendor/profile/edit'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Aide et support'));
    await tester.tap(find.text('Aide et support'));
    await tester.pumpAndSettle();
    expect(find.text('/vendor/complaints'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compte vendeur : cloche ouvre les notifications réelles', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Commande payée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compte vendeur : QR de contact s’ouvre dans une feuille', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.qr_code));
    await tester.pumpAndSettle();
    expect(find.text('Ma carte de contact'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compte vendeur : bouton déconnexion ouvre la confirmation', (
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
}
