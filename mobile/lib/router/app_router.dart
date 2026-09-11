import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Routeur central.
///
/// Organisé par contexte (auth / client / vendor / driver) et dédié à
/// l'application unique multi-rôles. Les features sont chargées par contexte.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const _SplashPage(),
    ),
  ],
);

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Béninfood'),
      ),
    );
  }
}