import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/driver/onboarding/driver_onboarding_screen.dart';

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

final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

MockClient _mockBackend(List<String> log) {
  return MockClient((request) async {
    final headers = {'content-type': 'application/json'};
    final path = request.url.path;
    log.add('${request.method} $path');

    if (path.endsWith('/locations')) {
      return http.Response(
        jsonEncode({
          'data': [
            {
              'city': 'Cotonou',
              'neighborhoods': [
                {'id': 'n-1', 'name': 'Akpakpa', 'latitude': 6.36, 'longitude': 2.44},
              ],
            },
          ],
        }),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/driver/me/onboarding')) {
      return http.Response(
        jsonEncode({'data': {'id': 'dp-1', 'status': 'candidate'}}),
        201,
        headers: headers,
      );
    }
    if (path.endsWith('/driver/me/documents')) {
      return http.Response(
        jsonEncode({'data': {'status': 'submitted'}}),
        201,
        headers: headers,
      );
    }
    return http.Response(jsonEncode({'message': 'Not found'}), 404, headers: headers);
  });
}

/// Harness : après la première actualisation, simule le profil créé côté BDD
/// pour activer l'envoi des documents (comme le ferait `DriverShell`).
class _Harness extends StatefulWidget {
  const _Harness({required this.api});

  final ApiClient api;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  Map<String, dynamic>? profile;
  int _refreshes = 0;

  Future<void> _refresh() async {
    _refreshes++;
    if (_refreshes == 1) {
      setState(() {
        profile = {'status': 'pending_validation', 'vehicle': 'Moto'};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: DriverOnboardingScreen(
          marketplace: MarketplaceApi(widget.api),
          profile: profile,
          documents: const [],
          onRefresh: _refresh,
          imagePicker: (_) async => _pngBytes,
        ),
      ),
    );
  }
}

Future<void> _uploadDocument(WidgetTester tester, String title) async {
  final tile = find.ancestor(
    of: find.text(title),
    matching: find.byType(Card),
  );
  final addButton = find.descendant(of: tile, matching: find.text('Ajouter'));
  await tester.ensureVisible(addButton);
  await tester.pumpAndSettle();
  await tester.tap(addButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Prendre une photo'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bienvenue livreur : logo, promesses et bouton Commencer', (tester) async {
    final log = <String>[];
    final api = ApiClient(
      tokenStore: _NoopTokenStore(),
      httpClient: _mockBackend(log),
      baseUrl: 'http://api.test',
    );
    await tester.pumpWidget(_Harness(api: api));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);

    expect(
      find.text('Bienvenue chez Béninfood', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Recevez des missions près de chez vous'), findsOneWidget);
    expect(find.text('Gagnez selon vos disponibilités'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('véhicule puis documents complètent la candidature', (tester) async {
    final log = <String>[];
    final api = ApiClient(
      tokenStore: _NoopTokenStore(),
      httpClient: _mockBackend(log),
      baseUrl: 'http://api.test',
    );
    await tester.pumpWidget(_Harness(api: api));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(find.text('Inscription livreur'), findsOneWidget);

    // Sans véhicule, aucune requête n'est envoyée.
    await tester.tap(find.text('Enregistrer mon inscription'));
    await tester.pumpAndSettle();
    expect(log.where((e) => e.endsWith('/driver/me/onboarding')), isEmpty);

    final field = find.widgetWithText(TextFormField, 'Véhicule');
    await tester.enterText(field, 'Moto Bajaj Boxer');

    // Zone d'activité du livreur (ville + quartier via le sélecteur).
    await tester.ensureVisible(find.text('Choisir un quartier…'));
    await tester.tap(find.text('Choisir un quartier…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akpakpa'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer mon inscription'));
    await tester.pumpAndSettle();
    expect(log.where((e) => e.endsWith('/driver/me/onboarding')), hasLength(1));
    // On reste sur la page des documents (jamais de retour à la bienvenue).
    expect(find.text('Bienvenue chez Béninfood', findRichText: true), findsNothing);

    await _uploadDocument(tester, 'Pièce d\'identité');
    await _uploadDocument(tester, 'Permis de conduire');
    expect(
      log.where((e) => e.endsWith('/driver/me/documents')),
      hasLength(2),
    );
    expect(find.text('Document transmis'), findsNWidgets(2));
    expect(find.text('Bienvenue chez Béninfood', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dossier déjà commencé : reprise directe sur les documents', (tester) async {
    final api = ApiClient(
      tokenStore: _NoopTokenStore(),
      httpClient: _mockBackend(<String>[]),
      baseUrl: 'http://api.test',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOnboardingScreen(
            marketplace: MarketplaceApi(api),
            profile: const {'status': 'pending_validation', 'vehicle': 'Moto'},
            documents: const [
              {'id': 'd1', 'type': 'id_card', 'status': 'submitted'},
            ],
            onRefresh: () async {},
            imagePicker: (_) async => _pngBytes,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Bienvenue chez Béninfood', findRichText: true), findsNothing);
    expect(find.text('Inscription livreur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}