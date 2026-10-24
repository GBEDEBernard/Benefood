import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/auth/session_provider.dart';
import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/driver/presentation/driver_shell.dart';
import 'package:beninfood/features/driver/widgets/driver_drawer.dart';

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

/// Backend de test : profil livreur actif, disponible, note 4,7.
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
    {
      'id': 'd1',
      'status': 'delivered',
      'fee': 500,
      'partner_amount': 400,
      'order': {
        'id': 'o1',
        'reference': 'CMD-4821',
        'status': 'delivered',
        'total': 2500,
        'delivery_fee': 500,
        'address': 'Cocody, Abidjan',
      },
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
    if (path.endsWith('/driver/me/parcels')) {
      return http.Response(jsonEncode({'data': []}), 200, headers: json);
    }
    if (path.endsWith('/driver/me/wallet')) {
      return http.Response(
        jsonEncode({
          'data': {'available_balance': 700, 'pending_balance': 0},
        }),
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

Future<void> _pumpShell(WidgetTester tester) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(),
    baseUrl: 'http://api.test',
  );
  final session = SessionProvider(api: api);
  final router = GoRouter(
    initialLocation: '/driver',
    routes: [
      GoRoute(
        path: '/driver',
        builder: (context, state) => DriverShell(
          session: session,
          marketplace: MarketplaceApi(api),
        ),
      ),
      for (final path in [
        '/driver/stats',
        '/driver/wallet',
        '/driver/favorite-clients',
      ])
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

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Ouvre le tiroir latéral et laisse l'animation d'entrée se terminer.
Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ouvrir le menu'));
  // Deux pumps : le premier amorce l'animation du tiroir, le second l'achève.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Fait défiler le tiroir jusqu'à ce que le texte soit visible.
Future<void> _scrollDrawerTo(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    _drawerText(label),
    120,
    scrollable: find.descendant(
      of: find.byType(DriverDrawer),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Recherche un texte à l'intérieur du tiroir uniquement (évite les collisions
/// avec la barre d'onglets du bas).
Finder _drawerText(String label) => find.descendant(
  of: find.byType(DriverDrawer),
  matching: find.text(label),
);

void main() {
  testWidgets('tiroir livreur : identité, navigation et accès rapides', (
    tester,
  ) async {
    await _pumpShell(tester);
    expect(tester.takeException(), isNull);

    await _openDrawer(tester);
    expect(tester.takeException(), isNull);

    // Carte d'identité.
    expect(find.text('ESPACE LIVREUR'), findsOneWidget);
    expect(find.text('EN LIGNE'), findsOneWidget);
    expect(find.text('Livreur Béninfood'), findsOneWidget);

    // Navigation.
    expect(_drawerText('Mes missions'), findsOneWidget);
    expect(_drawerText('Offres disponibles'), findsOneWidget);
    expect(_drawerText('Mes colis'), findsOneWidget);
    await _scrollDrawerTo(tester, 'Historique');
    expect(_drawerText('Historique'), findsOneWidget);
    await _scrollDrawerTo(tester, 'Mon compte');
    expect(_drawerText('Mon compte'), findsOneWidget);

    // Accès rapides + déconnexion.
    await _scrollDrawerTo(tester, 'Portefeuille');
    expect(_drawerText('ACCÈS RAPIDES'), findsOneWidget);
    expect(_drawerText('Statistiques'), findsOneWidget);
    expect(_drawerText('Portefeuille'), findsOneWidget);
    expect(_drawerText('Mes clients'), findsOneWidget);
    expect(_drawerText('Se déconnecter'), findsOneWidget);
  });

  testWidgets('tiroir livreur : la navigation change d’onglet', (
    tester,
  ) async {
    await _pumpShell(tester);

    await _openDrawer(tester);

    await _scrollDrawerTo(tester, 'Historique');
    await tester.tap(_drawerText('Historique'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    // L'onglet historique est affiché (carte de mission CMD-4821).
    expect(find.text('CMD-4821'), findsOneWidget);
  });

  testWidgets('tiroir livreur : un accès rapide ouvre sa section', (
    tester,
  ) async {
    await _pumpShell(tester);

    await _openDrawer(tester);

    await _scrollDrawerTo(tester, 'Portefeuille');
    await tester.tap(_drawerText('Portefeuille'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('/driver/wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tiroir livreur : la déconnexion demande confirmation', (
    tester,
  ) async {
    await _pumpShell(tester);

    await _openDrawer(tester);

    await tester.tap(_drawerText('Se déconnecter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Boîte de confirmation de la déconnexion.
    expect(find.text('Déconnexion'), findsOneWidget);
    expect(
      find.text('Voulez-vous vraiment vous déconnecter ?'),
      findsOneWidget,
    );

    // Annulation : on reste dans l'application.
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Déconnexion'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
