import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/brand_logo.dart';

/// Écran d'accueil avant connexion (J19 §2.2) — identité de marque Béninfood.
///
/// Mise en page responsive : le contenu est centré et borné en largeur, la
/// colonne défile si l'écran est petit.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key, required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gold, AppColors.orange, AppColors.orangeDark],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
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
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Spacer(flex: 2),
                              const Center(child: BrandLogo(size: 128)),
                              const SizedBox(height: 22),
                              const _BrandTitle(),
                              const SizedBox(height: 10),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'Commandez, payez, recevez.\nLe goût du Bénin livré chez vous.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Spacer(flex: 3),
                              const _ActionsPanel(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        children: const [
          TextSpan(text: 'Bénin', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'food', style: TextStyle(color: Color(0xFFFFF1D6))),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _ActionsPanel extends StatelessWidget {
  const _ActionsPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
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
    );
  }
}
