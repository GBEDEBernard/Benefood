import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/client/onboarding/client_onboarding_screen.dart';

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

    if (path.endsWith('/client/me/status')) {
      return http.Response(
        jsonEncode({
          'message': 'Aucun profil client associé à ce compte.',
          'errors': [
            {'code': 'client.not_onboarded', 'message': 'Pas encore inscrit.'},
          ],
        }),
        404,
        headers: headers,
      );
    }
    if (path.endsWith('/client/me/onboarding')) {
      return http.Response(
        jsonEncode({'data': {'id': 'cp-1', 'status': 'pending'}}),
        201,
        headers: headers,
      );
    }
    if (path.endsWith('/client/me/documents')) {
      return http.Response(
        jsonEncode({'data': {'status': 'submitted'}}),
        201,
        headers: headers,
      );
    }
    return http.Response(jsonEncode({'message': 'Not found'}), 404, headers: headers);
  });
}

Future<void> _pumpFlow(WidgetTester tester, List<String> log) async {
  final api = ApiClient(
    tokenStore: _NoopTokenStore(),
    httpClient: _mockBackend(log),
    baseUrl: 'http://api.test',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: ClientOnboardingScreen(
        marketplace: MarketplaceApi(api),
        user: null,
        imagePicker: (_) async => _pngBytes,
        onCompleted: () {},
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
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
  await tester.ensureVisible(find.text('Prendre une photo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Prendre une photo'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('accueil client : logo, promesses et bouton Commencer', (tester) async {
    final log = <String>[];
    await _pumpFlow(tester, log);
    expect(tester.takeException(), isNull);

    expect(
      find.text('Bienvenue chez Béninfood', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Commandez auprès des meilleurs vendeurs'), findsOneWidget);
    expect(find.text('Faites-vous livrer à domicile'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('les informations puis les documents activent le compte', (tester) async {
    final log = <String>[];
    await _pumpFlow(tester, log);

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(find.text('Vos informations'), findsOneWidget);

    // Sans informations, l'enregistrement n'appelle pas l'API.
    await tester.tap(find.text('Enregistrer mes informations'));
    await tester.pumpAndSettle();
    expect(log.where((e) => e.endsWith('/client/me/onboarding')), isEmpty);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Awa Sossou');
    await tester.enterText(fields.at(1), '+229 97 00 00 50');
    await tester.enterText(fields.at(2), 'Cotonou');
    await tester.enterText(fields.at(3), 'Rue 12, Cadjèhoun');

    await tester.tap(find.text('Enregistrer mes informations'));
    await tester.pumpAndSettle();
    expect(log.where((e) => e.endsWith('/client/me/onboarding')), hasLength(1));
    expect(find.text('Informations enregistrées.'), findsOneWidget);

    await _uploadDocument(tester, 'Carte CIP ou biométrique');
    await _uploadDocument(tester, 'Justificatif de domicile');
    expect(
      log.where((e) => e.endsWith('/client/me/documents')),
      hasLength(2),
    );

    expect(find.text('Activer mon compte'), findsOneWidget);
    await tester.tap(find.text('Activer mon compte'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
