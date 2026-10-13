import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/auth/session_provider.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/auth/presentation/landing_screen.dart';

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

SessionProvider _session() => SessionProvider(
      api: ApiClient(
        tokenStore: _NoopTokenStore(),
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({'data': null}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
        baseUrl: 'http://api.test',
      ),
    );

GoRouter _router() => GoRouter(
      initialLocation: '/landing',
      routes: [
        GoRoute(
          path: '/landing',
          builder: (context, state) => LandingScreen(session: _session()),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('ECRAN LOGIN')),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const Scaffold(body: Text('ECRAN REGISTER')),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => const Scaffold(body: Text('ECRAN RESET')),
        ),
        GoRoute(
          path: '/server',
          builder: (context, state) => const Scaffold(body: Text('ECRAN SERVER')),
        ),
      ],
    );

/// Surface d'un téléphone courant : l'écran doit tenir sans barre de navigation.
Future<void> _pumpLanding(
  WidgetTester tester, {
  Size size = const Size(1170, 2532),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('accueil : carte de marque avec logo, accroches et actions', (tester) async {
    await _pumpLanding(tester);

    expect(find.text('Béninfood'), findsOneWidget);
    expect(
      find.text('Commandez, payez, recevez.\nLe goût du Bénin livré chez vous.'),
      findsOneWidget,
    );

    // Logo dans la carte blanche (marque visuelle).
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/Logo.jpeg',
      ),
      findsOneWidget,
    );

    // Réglages serveur en haut à droite.
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    // Actions du panneau bas.
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('accueil : dégradé orange, panneau arrondi et boutons arrondis',
      (tester) async {
    await _pumpLanding(tester);

    // Dégradé de la maquette : #FA9409 → #E24B02, en diagonale haute-droite.
    final gradient = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.gradient)
        .whereType<LinearGradient>()
        .first;
    expect(gradient.colors, const [Color(0xFFFA9409), Color(0xFFF96A04), Color(0xFFE24B02)]);
    expect(gradient.begin, Alignment.topRight);
    expect(gradient.end, Alignment.bottomLeft);

    // Panneau bas : coins supérieurs arrondis, bas droits.
    final panelRadii = tester
        .widgetList<ClipRRect>(find.byType(ClipRRect))
        .map((clip) => clip.borderRadius)
        .whereType<BorderRadius>()
        .toList();
    expect(
      panelRadii.any((radius) =>
          radius.topLeft == radius.topRight &&
          radius.topLeft.x > 0 &&
          radius.bottomLeft == Radius.zero &&
          radius.bottomRight == Radius.zero),
      isTrue,
      reason: 'panneau aux coins supérieurs arrondis manquant',
    );

    // Les deux actions du panneau sont des boutons remplis arrondis (pas « pilule »).
    final shapes = tester
        .widgetList<FilledButton>(find.bySubtype<FilledButton>())
        .map((button) => button.style?.shape?.resolve(const <WidgetState>{}))
        .toList();
    expect(shapes.whereType<StadiumBorder>(), isEmpty);
    expect(shapes.whereType<RoundedRectangleBorder>().length, 2);

    expect(find.byIcon(Icons.login), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accueil : aucun débordement sur un écran de petite taille',
      (tester) async {
    await _pumpLanding(tester, size: const Size(960, 1704)); // 320 × 568 logiques

    expect(find.text('Béninfood'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accueil : les actions mènent connexion, inscription, réinitialisation et réglages',
      (tester) async {
    await _pumpLanding(tester);
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('ECRAN LOGIN'), findsOneWidget);

    await _pumpLanding(tester);
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(find.text('ECRAN REGISTER'), findsOneWidget);

    await _pumpLanding(tester);
    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();
    expect(find.text('ECRAN RESET'), findsOneWidget);

    await _pumpLanding(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('ECRAN SERVER'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
