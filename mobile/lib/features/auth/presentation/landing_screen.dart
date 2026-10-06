import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';

/// Écran d'accueil avant connexion (J19 §2.2) — identité de marque Béninfood.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key, required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Héro de marque.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.orange, AppColors.gold],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      tooltip: 'Réglages du serveur',
                      onPressed: () => context.go('/server'),
                      icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/Logo.jpeg',
                      width: 112,
                      height: 112,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.storefront, size: 80, color: AppColors.orange),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Béninfood',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Commandez, payez, recevez.\nLe goût du Bénin livré chez vous.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                // Panneau d'actions.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(
                        label: 'Se connecter',
                        icon: Icons.login,
                        onPressed: () => context.go('/login'),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Créer un compte',
                        variant: AppButtonVariant.outline,
                        icon: Icons.person_add_outlined,
                        onPressed: () => context.go('/register'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => context.go('/reset-password'),
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}