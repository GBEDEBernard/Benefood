import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/data/marketplace_api.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/vendor/onboarding/steps/legal_info_step.dart';
import 'package:beninfood/features/vendor/onboarding/steps/shop_config_step.dart';
import 'package:beninfood/features/vendor/onboarding/vendor_onboarding_screen.dart';
import 'package:beninfood/features/vendor/onboarding/widgets/step_dots.dart';

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

/// Petit PNG 1×1 : octets renvoyés par le sélecteur d'images de test.
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// Backend de test : aucun dossier existant (404), catégories réelles,
/// enregistrements des documents et PATCH de configuration acceptés.
MockClient _mockBackend(List<String> log) {
  const categories = [
    {
      'id': 'cat-snacks',
      'name': 'Snacks et restauration',
      'slug': 'snacks-et-restauration',
      'is_active': true,
    },
    {'id': 'cat-epicerie', 'name': 'Épicerie', 'slug': 'epicerie', 'is_active': true},
  ];

  return MockClient((request) async {
    final headers = {'content-type': 'application/json'};
    final path = request.url.path;
    log.add('${request.method} $path');

    if (path.endsWith('/vendors/me/status')) {
      return http.Response(
        jsonEncode({
          'message': 'Aucun profil vendeur associé à ce compte.',
          'errors': [
            {'code': 'vendor.not_onboarded', 'message': 'Pas encore inscrit.'},
          ],
        }),
        404,
        headers: headers,
      );
    }
    if (path.endsWith('/categories')) {
      return http.Response(jsonEncode({'data': categories}), 200, headers: headers);
    }
    if (path.endsWith('/vendors/me/onboarding')) {
      return http.Response(
        jsonEncode({'data': {'status': 'registered'}}),
        201,
        headers: headers,
      );
    }
    if (path.endsWith('/vendors/me/documents')) {
      return http.Response(
        jsonEncode({'data': {'status': 'submitted'}}),
        201,
        headers: headers,
      );
    }
    if (request.method == 'PATCH' && path.endsWith('/vendors/me')) {
      return http.Response(
        jsonEncode({'data': {'status': 'pending_verification'}}),
        200,
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
      home: VendorOnboardingScreen(
        marketplace: MarketplaceApi(api),
        imagePicker: (_) async => _pngBytes,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

/// Envoie un document depuis l'étape 2 (feuille source → caméra).
/// Le toast de confirmation est laissé s'écouler : il recouvrirait
/// sinon le bouton « Suivant » du test suivant.
Future<void> _uploadDocument(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Prendre une photo'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('accueil : titre, avantages, points d’étape et actions', (tester) async {
    final log = <String>[];
    await _pumpFlow(tester, log);
    expect(tester.takeException(), isNull);

    expect(
      find.text('Bienvenue chez BÉNINFOOD', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Développez votre activité'), findsOneWidget);
    expect(find.text('Suivez vos ventes en temps réel'), findsOneWidget);
    expect(find.text('Augmentez vos revenus'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
    expect(find.byType(StepDots), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('étape 1 : les champs obligatoires bloquent l’envoi', (tester) async {
    final log = <String>[];
    await _pumpFlow(tester, log);

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(find.text('Informations légales'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    expect(find.text('Indiquez la raison sociale'), findsOneWidget);
    expect(find.text('Indiquez le numéro IFU'), findsOneWidget);
    expect(find.text('Indiquez le numéro de téléphone'), findsOneWidget);
    expect(find.text('Indiquez l\u2019adresse email'), findsOneWidget);
    expect(find.text('Indiquez l\u2019adresse de la boutique'), findsOneWidget);
    expect(log.where((entry) => entry.endsWith('/onboarding')), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('parcours complet : 5 écrans jusqu’à la confirmation', (tester) async {
    final log = <String>[];
    await _pumpFlow(tester, log);

    // --- Étape 1 : informations légales ---
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    final legalFields = find.descendant(
      of: find.byType(LegalInfoStep),
      matching: find.byType(TextFormField),
    );
    expect(legalFields, findsNWidgets(5));
    await tester.enterText(legalFields.at(0), 'Le Délice Fast-Food');
    await tester.enterText(legalFields.at(1), '4202012345678');
    await tester.enterText(legalFields.at(2), '+229 97 12 34 56');
    await tester.enterText(legalFields.at(3), 'contact@ledelice.com');
    await tester.enterText(legalFields.at(4), 'Cadjèhoun, Cotonou, Bénin');

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Documents requis'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
    expect(
      log.where((entry) => entry.endsWith('/vendors/me/onboarding')),
      hasLength(1),
    );

    // --- Étape 2 : trois documents envoyés ---
    await _uploadDocument(tester, 'Pièce d\u2019identité');
    await _uploadDocument(tester, 'Registre de commerce');
    await _uploadDocument(tester, 'Photo de la boutique');
    expect(find.text('Document transmis'), findsNWidgets(3));
    expect(
      log.where((entry) => entry.endsWith('/vendors/me/documents')),
      hasLength(3),
    );

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Configuration de la boutique'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);

    // --- Étape 3 : configuration boutique ---
    final shopFields = find.descendant(
      of: find.byType(ShopConfigStep),
      matching: find.byType(TextFormField),
    );
    expect(shopFields, findsNWidgets(2));
    await tester.enterText(shopFields.at(0), 'Le Délice');
    await tester.enterText(
      shopFields.at(1),
      'Cuisine béninoise à Cotonou.',
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Snacks et restauration'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Ajouter le logo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ajouter le logo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir dans la galerie'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Ajouter la couverture'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ajouter la couverture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir dans la galerie'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(log.where((entry) => entry == 'PATCH /vendors/me').length, 2);

    // --- Étape finale : confirmation ---
    expect(find.text('D\u2019demande soumise !'), findsOneWidget);
    expect(find.text('Votre compte est en attente de vérification.'), findsOneWidget);
    expect(find.text('En attente de vérification'), findsOneWidget);
    expect(find.text('Informations soumises'), findsOneWidget);
    expect(find.text('Documents reçus'), findsOneWidget);
    expect(find.text('En cours de vérification'), findsOneWidget);
    expect(find.text('Compte à activer'), findsOneWidget);

    await tester.ensureVisible(find.text('Aller au tableau de bord'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aller au tableau de bord'));
    await tester.pumpAndSettle();
    expect(find.byType(VendorOnboardingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
