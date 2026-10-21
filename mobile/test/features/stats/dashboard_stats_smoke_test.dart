import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/driver/stats/driver_statistics_screen.dart';
import 'package:beninfood/features/vendor/restaurant/screens/vendor_statistics_screen.dart';

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

MarketplaceApi _api(MockClient client) => MarketplaceApi(
  ApiClient(
    httpClient: client,
    tokenStore: _NoopTokenStore(),
    baseUrl: 'https://test.local/api/v1',
  ),
);

void main() {
  testWidgets('statistiques vendeur : KPI, meilleurs produits et période', (
    tester,
  ) async {
    final requests = <Uri>[];
    int? selectedTab;
    final client = MockClient((request) async {
      requests.add(request.url);
      const stats = {
        'period': {
          'key': '30d',
          'from': '2026-09-22',
          'to': '2026-10-21',
          'granularity': 'day',
        },
        'currency': 'XOF',
        'kpis': {
          'revenue': 25000,
          'net_revenue': 21000,
          'commission': 4000,
          'orders_total': 8,
          'orders_delivered': 6,
          'orders_cancelled': 2,
          'average_basket': 4166,
          'items_sold': 17,
          'unique_clients': 5,
          'pending_orders': 2,
          'cancellation_rate': 25.0,
          'rating': {'average': 4.5, 'count': 3},
        },
        'comparison': {'revenue_pct': 12.5, 'orders_pct': 20.0},
        'series': [
          {'label': '2026-10-19', 'revenue': 10000, 'orders': 2},
          {'label': '2026-10-20', 'revenue': 5000, 'orders': 1},
          {'label': '2026-10-21', 'revenue': 10000, 'orders': 3},
        ],
        'status_breakdown': [
          {'status': 'delivered', 'count': 6},
          {'status': 'cancelled', 'count': 2},
        ],
        'top_products': [
          {
            'id': 'p1',
            'name': 'Poulet braisé',
            'quantity': 9,
            'revenue': 18000,
          },
          {'id': 'p2', 'name': 'Jus de bissap', 'quantity': 4, 'revenue': 4000},
        ],
      };

      if (request.url.path.endsWith('/vendors/me/stats')) {
        return http.Response(
          jsonEncode({'data': stats}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/me/notifications')) {
        return http.Response(
          jsonEncode({'data': <dynamic>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'data': <String, dynamic>{}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: VendorStatisticsScreen(
          marketplace: _api(client),
          onSelectShellTab: (index) => selectedTab = index,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Statistiques'), findsOneWidget);
    expect(find.text('Chiffre d\'affaires'), findsOneWidget);
    expect(find.text('25 000 FCFA'), findsOneWidget);
    expect(find.text('21 000 FCFA'), findsOneWidget);
    expect(find.text('4 000 FCFA'), findsOneWidget);
    expect(find.text('+12,5 %'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Livrées'), 200);
    expect(find.text('Livrées'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Commandes par statut'), 300);
    expect(find.text('Commandes par statut'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Poulet braisé'), 300);
    expect(find.text('Poulet braisé'), findsOneWidget);

    int statsCalls() =>
        requests.where((uri) => uri.path.endsWith('/vendors/me/stats')).length;

    expect(statsCalls(), 1);

    await tester.tap(find.text('7 j'));
    await tester.pumpAndSettle();

    expect(statsCalls(), 2);
    expect(
      requests.any(
        (uri) =>
            uri.path.endsWith('/vendors/me/stats') &&
            uri.queryParameters['period'] == '7d',
      ),
      isTrue,
    );

    // Rafraîchissement manuel (bouton à côté de « Actualisé à … »).
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();
    expect(statsCalls(), 3);

    // Rafraîchissement automatique sans action de l'utilisateur.
    await tester.pump(const Duration(seconds: 46));
    await tester.pumpAndSettle();
    expect(statsCalls(), 4);

    // Footer vendeur : barre d'actions rapides vers les sections du shell.
    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Produits'), findsOneWidget);
    expect(find.text('Commandes'), findsOneWidget);
    expect(find.text('Revenus'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await tester.tap(find.text('Commandes'));
    await tester.pumpAndSettle();
    expect(selectedTab, 3);

    await tester.tap(find.text('Revenus'));
    await tester.pumpAndSettle();
    expect(selectedTab, 4);

    // Démonte l'écran pour annuler le minuteur de polling.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'statistiques livreur : gains, répartition et dernières missions',
    (tester) async {
      int? selectedTab;
      final client = MockClient((request) async {
        const stats = {
          'period': {
            'key': '30d',
            'from': '2026-09-22',
            'to': '2026-10-21',
            'granularity': 'day',
          },
          'currency': 'XOF',
          'kpis': {
            'missions_completed': 12,
            'orders_delivered': 8,
            'parcels_delivered': 4,
            'missions_cancelled': 1,
            'completion_rate': 92.3,
            'earnings': 12000,
            'orders_earnings': 8000,
            'parcels_earnings': 4000,
            'average_per_mission': 1000,
            'distance_km': 14.5,
            'rating': {'average': 4.8, 'count': 9},
          },
          'comparison': {'earnings_pct': 8.0, 'missions_pct': 10.0},
          'series': [
            {'label': '2026-10-20', 'earnings': 6000, 'missions': 6},
            {'label': '2026-10-21', 'earnings': 6000, 'missions': 6},
          ],
          'breakdown': [
            {'type': 'orders', 'count': 8, 'earnings': 8000},
            {'type': 'parcels', 'count': 4, 'earnings': 4000},
          ],
          'recent': [
            {
              'id': 'd1',
              'type': 'order',
              'label': 'Commande #BF1042',
              'delivered_at': '2026-10-21T12:30:00+01:00',
              'earnings': 800,
            },
            {
              'id': 'p1',
              'type': 'parcel',
              'label': 'Colis COL-9',
              'delivered_at': '2026-10-21T10:00:00+01:00',
              'earnings': 400,
            },
          ],
        };

        if (request.url.path.endsWith('/driver/me/stats')) {
          return http.Response(
            jsonEncode({'data': stats}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/me/notifications')) {
          return http.Response(
            jsonEncode({'data': <dynamic>[]}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'data': <String, dynamic>{}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DriverStatisticsScreen(
            marketplace: _api(client),
            onSelectShellTab: (index) => selectedTab = index,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gains sur la période'), findsOneWidget);
      expect(find.text('12 000 FCFA'), findsOneWidget);
      expect(find.text('8 000 FCFA'), findsWidgets);
      expect(find.text('4 000 FCFA'), findsWidgets);

      await tester.scrollUntilVisible(find.text('14,5 km'), 200);
      expect(find.text('14,5 km'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Répartition des missions'),
        300,
      );
      expect(find.text('Répartition des missions'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Commande #BF1042'), 300);
      expect(find.text('Commande #BF1042'), findsOneWidget);
      expect(find.text('Colis COL-9'), findsOneWidget);

      // Footer livreur : barre d'actions rapides vers les sections du shell.
      expect(find.text('Missions'), findsOneWidget);
      expect(find.text('Offres'), findsOneWidget);
      expect(find.text('Historique'), findsOneWidget);
      expect(find.text('Compte'), findsOneWidget);

      await tester.tap(find.text('Offres'));
      await tester.pumpAndSettle();
      expect(selectedTab, 1);

      await tester.tap(find.text('Missions'));
      await tester.pumpAndSettle();
      expect(selectedTab, 0);

      // Démonte l'écran pour annuler le minuteur de polling.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
