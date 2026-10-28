import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/drivers/driver_selection_screen.dart';
import 'package:beninfood/shared/models/driver_selection.dart';

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

Map<String, dynamic> _driver({
  required String id,
  required String name,
  required double distanceKm,
  required int etaToPickupSeconds,
  required double toClientKm,
  required int toClientSeconds,
  int ageSeconds = 12,
  double rating = 4.8,
  int deliveries = 245,
}) {
  return {
    'id': id,
    'name': name,
    'avatar_url': null,
    'vehicle': 'Moto',
    'rating': rating,
    'completed_deliveries': deliveries,
    'distance_to_pickup_km': distanceKm,
    'eta_to_pickup_s': etaToPickupSeconds,
    'pickup_to_dropoff_km': toClientKm,
    'eta_to_dropoff_s': toClientSeconds,
    'distance_to_dropoff_km': distanceKm + toClientKm,
    'eta_total_s': etaToPickupSeconds + toClientSeconds,
    'position': {
      'latitude': 6.366,
      'longitude': 2.391,
      'heading': 90,
      'last_location_at': '2026-10-26T10:00:00+00:00',
      'age_seconds': ageSeconds,
    },
  };
}

Map<String, dynamic> _page({
  List<Map<String, dynamic>> drivers = const [],
  Map<String, dynamic>? diagnostics,
}) {
  return {
    'pickup': {
      'name': 'Primeur du Golfe',
      'latitude': 6.365,
      'longitude': 2.39,
      'address': 'Godomey',
      'city': 'Abomey-Calavi',
    },
    'dropoff': {
      'name': 'Godomey, après école',
      'latitude': 6.37,
      'longitude': 2.391,
      'address': 'Abomey-Calavi',
      'city': 'Abomey-Calavi',
    },
    'trip': {'distance_km': 2.8, 'duration_s': 660},
    'radius_km': drivers.isEmpty ? 15 : 3,
    'requested_radius_km': 3,
    'max_radius_km': 15,
    'expanded': drivers.isEmpty,
    'drivers': drivers,
    'diagnostics':
        diagnostics ??
        {
          'online_drivers': drivers.length,
          'with_position': drivers.length,
          'fresh_position': drivers.length,
          'stale_position': 0,
          'without_position': 0,
          'within_max_radius': drivers.length,
          'max_radius_km': 15,
          'location_max_age_s': 300,
        },
    'request': null,
  };
}

MarketplaceApi _api(http.Client client) {
  return MarketplaceApi(
    ApiClient(
      tokenStore: _NoopTokenStore(),
      httpClient: client,
      baseUrl: 'http://api.test',
    ),
  );
}

Future<void> _pump(WidgetTester tester, MarketplaceApi api) async {
  // Écran haut : toute la liste est construite d'un coup, sans défilement.
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: DriverSelectionScreen(
        marketplace: api,
        targetId: 'ord-1',
        reference: 'BEN-261023-VIQABP',
        isParcel: false,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('affiche la carte, les livreurs et l’affectation automatique', (
    tester,
  ) async {
    final api = _api(
      MockClient((request) async {
        if (request.url.path.endsWith('/nearby-drivers')) {
          return http.Response(
            jsonEncode({
              'data': _page(
                drivers: [
                  _driver(
                    id: 'd1',
                    name: 'Bernard A.',
                    distanceKm: 1.5,
                    etaToPickupSeconds: 360,
                    toClientKm: 2.8,
                    toClientSeconds: 660,
                  ),
                  _driver(
                    id: 'd2',
                    name: 'Comlan K.',
                    distanceKm: 2.1,
                    etaToPickupSeconds: 480,
                    toClientKm: 3.6,
                    toClientSeconds: 780,
                    ageSeconds: 150,
                    rating: 4.6,
                    deliveries: 182,
                  ),
                ],
              ),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    await _pump(tester, api);
    expect(tester.takeException(), isNull);

    expect(find.text('Choisir mon livreur'), findsOneWidget);
    expect(find.text('Commande #BEN-261023-VIQABP'), findsOneWidget);
    expect(find.text('Primeur du Golfe'), findsOneWidget);
    expect(find.text('2 livreurs disponibles autour de vous'), findsOneWidget);
    expect(find.text('Bernard A.'), findsOneWidget);
    expect(find.textContaining('position à jour'), findsOneWidget);
    expect(find.text('Comlan K.'), findsOneWidget);
    expect(find.text('Demander ce livreur'), findsNWidgets(2));
    expect(find.text('du point de collecte'), findsNWidgets(2));
    expect(find.text('de votre adresse'), findsNWidgets(2));
    expect(find.textContaining('position il y a 2 min'), findsOneWidget);
    expect(find.text('Assigner automatiquement'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });

  testWidgets(
    'mode checkout : carte et distances avant paiement, retourne le livreur choisi',
    (tester) async {
      final api = _api(
        MockClient((request) async {
          if (request.url.path.endsWith('/orders/checkout-drivers')) {
            return http.Response(
              jsonEncode({
                'data': _page(
                  drivers: [
                    _driver(
                      id: 'd1',
                      name: 'Bernard A.',
                      distanceKm: 1.5,
                      etaToPickupSeconds: 360,
                      toClientKm: 2.8,
                      toClientSeconds: 660,
                    ),
                  ],
                ),
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );

      tester.view.physicalSize = const Size(420, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      CheckoutDriverChoice? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    chosen = await showCheckoutDriverSelection(
                      context,
                      api,
                      addressId: 'a1',
                      addressLabel: 'Maison',
                    );
                  },
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Choisir mon livreur'), findsOneWidget);
      expect(find.text('Livraison à Maison'), findsOneWidget);
      expect(find.text('Bernard A.'), findsOneWidget);
      expect(find.text('du point de collecte'), findsOneWidget);
      expect(find.text('Choisir ce livreur'), findsOneWidget);
      expect(
        find.text('Demander ce livreur'),
        findsNothing,
        reason: 'la demande au livreur reste réservée à l’après-paiement',
      );
      expect(find.text('Assigner automatiquement'), findsNothing);

      await tester.tap(find.text('Choisir ce livreur'));
      await tester.pumpAndSettle();

      expect(chosen?.driver?.id, 'd1');
      expect(find.text('Choisir mon livreur'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('après paiement : retourne le livreur sans envoyer la demande', (
    tester,
  ) async {
    final api = _api(
      MockClient((request) async {
        if (request.url.path.endsWith('/orders/ord-1/nearby-drivers')) {
          return http.Response(
            jsonEncode({
              'data': _page(
                drivers: [
                  _driver(
                    id: 'd1',
                    name: 'Bernard A.',
                    distanceKm: 1.5,
                    etaToPickupSeconds: 360,
                    toClientKm: 2.8,
                    toClientSeconds: 660,
                  ),
                ],
              ),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    NearbyDriver? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  chosen = await showApproachDriverSelection(
                    context,
                    api,
                    targetId: 'ord-1',
                    reference: 'BEN-261023-VIQABP',
                  );
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Choisir ce livreur'), findsOneWidget);
    expect(find.text('Demander ce livreur'), findsNothing);
    expect(find.text('Assigner automatiquement'), findsNothing);
    expect(find.text('Continuer sans livreur'), findsNothing);

    await tester.tap(find.text('Choisir ce livreur'));
    await tester.pumpAndSettle();

    expect(chosen?.id, 'd1');
    expect(find.text('Choisir mon livreur'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mode checkout : permet de continuer sans livreur', (
    tester,
  ) async {
    final api = _api(
      MockClient((request) async {
        if (request.url.path.endsWith('/orders/checkout-drivers')) {
          return http.Response(
            jsonEncode({
              'data': _page(
                drivers: [
                  _driver(
                    id: 'd1',
                    name: 'Bernard A.',
                    distanceKm: 1.5,
                    etaToPickupSeconds: 360,
                    toClientKm: 2.8,
                    toClientSeconds: 660,
                  ),
                ],
              ),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CheckoutDriverChoice? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  chosen = await showCheckoutDriverSelection(
                    context,
                    api,
                    addressId: 'a1',
                    addressLabel: 'Maison',
                  );
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Continuer sans livreur'), findsOneWidget);
    await tester.tap(find.text('Continuer sans livreur'));
    await tester.pumpAndSettle();

    expect(chosen, isNotNull);
    expect(chosen!.hasDriver, isFalse);
    expect(chosen!.driver, isNull);
    expect(find.text('Choisir mon livreur'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explique un manque de positions GPS au lieu d’un écran vide', (
    tester,
  ) async {
    final api = _api(
      MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': _page(
              diagnostics: {
                'online_drivers': 2,
                'with_position': 2,
                'fresh_position': 0,
                'stale_position': 2,
                'without_position': 0,
                'within_max_radius': 0,
                'max_radius_km': 15,
                'location_max_age_s': 300,
              },
            ),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await _pump(tester, api);
    expect(tester.takeException(), isNull);

    expect(find.text('Positions GPS en cours de mise à jour'), findsOneWidget);
    expect(
      find.textContaining('position GPS n’est plus à jour'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Assigner automatiquement'), findsOneWidget);
    expect(
      find.text('2 en ligne · 2 position(s) à rafraîchir'),
      findsOneWidget,
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });
}
