import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../shared/widgets/app_button.dart';

/// Écran d'accueil avant connexion (J19 §2.2).
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key, required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Image.asset(
                'assets/Logo.jpeg',
                width: 140,
                height: 140,
                errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 120),
              ),
              const SizedBox(height: 24),
              Text(
                'Béninfood',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Bienvenue sur Béninfood',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 40),
              AppButton(label: 'Se connecter', onPressed: () => context.go('/login')),
              const SizedBox(height: 12),
              AppButton(
                label: 'Créer un compte',
                variant: AppButtonVariant.outline,
                onPressed: () => context.go('/register'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/reset-password'),
                child: const Text('Mot de passe oublié ?'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}