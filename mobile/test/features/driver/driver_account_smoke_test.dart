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
import 'package:beninfood/features/driver/account/driver_account_screen.dart';

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

/// Backend de test : profil livreur actif et disponible, 3 missions
/// (2 livrées → gains, note 4,7), cloche avec 2 non lues.
MockClient _mockBackend() {
  const status = {
    'profile': {
      'status': 'active',
      'available': true,
      'vehicle': 'Moto TVN-4521',
      'rating': 4.7,
    },
    'documents': [],
  };
  const deliveries = [
    {'id': 'd1', 'status': 'delivered', 'fee': 500, 'partner_amount': 400},
    {'id': 'd2', 'status': 'delivered', 'fee': 300},
    {'id': 'd3', 'status': 'assigned', 'fee': 200},
  ];
  const stats = {'orders_count': 23, 'unread_notifications': 2};
  const notifications = [
    {
      'id': 'n1',
      'type': 'delivery.assigned',
      'title': 'Nouvelle mission',
      'body': 'Une livraison vous est proposée.',
      'read_at': null,
      'created_at': '2026-10-06T10:00:00Z',
    },
  ];

  return MockClient((request) async {
    final json = {'content-type': 'application/json'};
    final path = request.url.path;
    if (path.endsWith('/driver/me/status')) {
      return http.Response(jsonEncode({'data': status}), 200, headers: json);
    }
    if (path.endsWith('/driver/me/deliveries')) {
      return http.Response(
        jsonEncode({'data': deliveries}),
        200,
        headers: json,
      );
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
    '/driver/profile/edit',
    '/driver/notifications',
    '/driver/security',
    '/driver/complaints',
    '/driver/wallet',
  ];
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => DriverAccountScreen(
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
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compte livreur : carte verte, stats missions et menu', (
    tester,
  ) async {
    await _pumpScreen(tester);
    expect(tester.takeException(), isNull);

    // Carte verte : identité, badges.
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Utilisateur'), findsOneWidget);
    expect(find.text('Espace livreur'), findsOneWidget);
    expect(find.text('Actif'), findsNWidgets(2)); // pastille + badge carte

    // Statistiques dynamiques (status + livraisons).
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Missions'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2)); // livrées + pastille cloche
    expect(find.text('Livrées'), findsOneWidget);
    expect(
      find.text(
        '${formatAmount(700, showSymbol: false).trim()} FCFA',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Gains'), findsOneWidget);
    expect(find.text('4,7'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);

    // Bloc profil livreur conservé (véhicule, statut, disponibilité).
    expect(find.text('Mon profil livreur'), findsOneWidget);
    await _scrollTo(tester, find.text('Disponible pour les livraisons'));
    expect(find.text('Moto TVN-4521'), findsOneWidget);
    expect(find.text('Note : 4.7'), findsOneWidget);

    // Menu « Mon compte » : 4 entrées communes.
    await _scrollTo(tester, find.text('Se déconnecter'));
    const titles = [
      'Mes gains & retraits',
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

  testWidgets('compte livreur : statistiques tapables (onglets)', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Missions'));
    await tester.pump();
    expect(_selectedTab, 2);

    await tester.tap(find.text('Livrées'));
    await tester.pump();
    expect(_selectedTab, 2);

    await tester.tap(find.text('Gains'));
    await tester.pump();
    expect(_selectedTab, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compte livreur : le menu ouvre les sections dédiées', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await _scrollTo(tester, find.text('Informations personnelles'));

    await tester.tap(find.text('Informations personnelles'));
    await tester.pumpAndSettle();
    expect(find.text('/driver/profile/edit'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Aide et support'));
    await tester.tap(find.text('Aide et support'));
    await tester.pumpAndSettle();
    expect(find.text('/driver/complaints'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compte livreur : cloche ouvre les notifications réelles', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle mission'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compte livreur : QR de contact s’ouvre dans une feuille', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.qr_code));
    await tester.pumpAndSettle();
    expect(find.text('Ma carte de contact'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compte livreur : bouton déconnexion ouvre la confirmation', (
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
