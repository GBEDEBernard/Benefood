import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:beninfood/core/auth/session_provider.dart';
import 'package:beninfood/core/http/api_client.dart';
import 'package:beninfood/features/auth/presentation/login_screen.dart';
import 'package:beninfood/features/auth/presentation/register_screen.dart';
import 'package:beninfood/features/auth/presentation/reset_password_screen.dart';

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

GoRouter _router({required bool login, required bool reset}) => GoRouter(
  initialLocation: reset
      ? '/reset-password'
      : login
      ? '/login'
      : '/register',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(session: _session()),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => RegisterScreen(session: _session()),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => ResetPasswordScreen(session: _session()),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: Text('ACCUEIL')),
    ),
  ],
);

/// Les deux écrans sont des pages fixes : ils doivent tenir et ne lever
/// aucune exception, y compris sur un petit écran.
Future<void> _pump(
  WidgetTester tester, {
  required bool login,
  bool reset = false,
  Size size = const Size(1170, 2532),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: _router(login: login, reset: reset),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('connexion : rendu fixe sans débordement', (tester) async {
    await _pump(tester, login: true);

    expect(find.text('Bon retour !'), findsOneWidget);
    expect(find.text('Téléphone ou email'), findsOneWidget);
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inscription : rendu fixe sans débordement', (tester) async {
    await _pump(tester, login: false);

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Nom complet'), findsOneWidget);
    expect(find.text('Créer mon compte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inscription : email obligatoire et valide', (tester) async {
    await _pump(tester, login: false);

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Email (facultatif)'), findsNothing);

    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();

    expect(find.text('Indiquez votre email'), findsOneWidget);
  });

  testWidgets('connexion : aucun débordement sur un écran de petite taille', (
    tester,
  ) async {
    await _pump(
      tester,
      login: true,
      size: const Size(960, 1704),
    ); // 320 × 568 logiques

    expect(find.text('Bon retour !'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inscription : aucun débordement sur un écran de petite taille', (
    tester,
  ) async {
    await _pump(
      tester,
      login: false,
      size: const Size(960, 1704),
    ); // 320 × 568 logiques

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Créer mon compte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mot de passe oublié : rendu fixe sans débordement', (
    tester,
  ) async {
    await _pump(tester, login: false, reset: true);

    expect(find.text('Mot de passe oublié'), findsOneWidget);
    expect(find.text('Envoyer le code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mot de passe oublié : aucun débordement sur un petit écran', (
    tester,
  ) async {
    await _pump(tester, login: false, reset: true, size: const Size(960, 1704));

    expect(find.text('Mot de passe oublié'), findsOneWidget);
    expect(find.text('Envoyer le code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
