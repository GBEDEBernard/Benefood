import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Écran de choix du type de compte, affiché juste après l'inscription.
///
/// Le compte de base est toujours client ; l'utilisateur peut cocher en plus
/// les espaces vendeur et/ou livreur. Les rôles sont attachés au compte puis
/// l'onboarding du premier espace choisi s'ouvre (obligatoire).
class ChooseAccountScreen extends StatefulWidget {
  const ChooseAccountScreen({super.key, required this.session});

  final SessionProvider session;

  @override
  State<ChooseAccountScreen> createState() => _ChooseAccountScreenState();
}

class _ChooseAccountScreenState extends State<ChooseAccountScreen> {
  bool _vendor = false;
  bool _driver = false;
  bool _loading = false;

  Future<void> _continue() async {
    final roles = <String>[
      AppContext.client,
      if (_vendor) AppContext.vendor,
      if (_driver) AppContext.driverRegistrationSlug,
    ];

    final primary = _vendor
        ? AppContext.vendor
        : (_driver ? AppContext.driver : AppContext.client);

    setState(() => _loading = true);
    try {
      await widget.session.requestRoles(roles);
      await widget.session.switchRole(primary);
      if (!mounted) {
        return;
      }
      context.go(switch (primary) {
        AppContext.vendor => '/vendor',
        AppContext.driver => '/driver',
        _ => '/client',
      });
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.session.user?.name.split(' ').first ?? '';

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Center(child: BrandLogo(size: 84, padding: 8)),
                        const SizedBox(height: 20),
                        Text(
                          name.isEmpty ? 'Bienvenue !' : 'Bienvenue $name !',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Que souhaitez-vous faire sur Béninfood ?\n'
                          'Vous pouvez choisir plusieurs espaces.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 28),
                        _AccountCard(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Compte client',
                          subtitle: 'Commander et envoyer des colis',
                          accent: AppColors.green,
                          selected: true,
                          locked: true,
                          onTap: null,
                        ),
                        const SizedBox(height: 14),
                        _AccountCard(
                          icon: Icons.storefront_outlined,
                          title: 'Espace vendeur',
                          subtitle: 'Vendre mes produits sur Béninfood',
                          accent: AppColors.gold,
                          selected: _vendor,
                          onTap: _loading
                              ? null
                              : () => setState(() => _vendor = !_vendor),
                        ),
                        const SizedBox(height: 14),
                        _AccountCard(
                          icon: Icons.delivery_dining_outlined,
                          title: 'Espace livreur',
                          subtitle: 'Livrer des commandes et des colis',
                          accent: const Color(0xFF3949AB),
                          selected: _driver,
                          onTap: _loading
                              ? null
                              : () => setState(() => _driver = !_driver),
                        ),
                        const SizedBox(height: 28),
                        AppButton(
                          label: 'Continuer',
                          icon: Icons.arrow_forward,
                          loading: _loading,
                          onPressed: _continue,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'L\'inscription de l\'espace choisi se poursuit '
                          'immédiatement (documents et informations requises).',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textFaint),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      color: selected ? accent.withValues(alpha: 0.07) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? accent : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? accent : AppColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
