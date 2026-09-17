import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Sélection du contexte actif pour les utilisateurs multi-rôles (J19 §2.6,
/// J51-J53). `POST /me/active-role` définit uniquement l'expérience.
class ContextSelectorScreen extends StatefulWidget {
  const ContextSelectorScreen({super.key, required this.session});

  final SessionProvider session;

  @override
  State<ContextSelectorScreen> createState() => _ContextSelectorScreenState();
}

class _ContextSelectorScreenState extends State<ContextSelectorScreen> {
  bool _loading = false;

  Future<void> _select(String role) async {
    setState(() => _loading = true);
    try {
      await widget.session.switchRole(role);
      if (mounted) {
        context.go(switch (role) {
          'vendor' => '/vendor',
          'driver' => '/driver',
          _ => '/client',
        });
      }
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
    final user = widget.session.user;
    final slugs = user?.roleSlugs ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Choisir un espace')),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 8),
                const Text('Quel espace voulez-vous ouvrir ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Bonjour ${user?.name ?? ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (slugs.contains('client'))
                  _ContextCard(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Client',
                    subtitle: 'Commander chez les vendeurs Béninfood',
                    onTap: _loading ? null : () => _select('client'),
                  ),
                if (slugs.contains('vendor'))
                  _ContextCard(
                    icon: Icons.storefront_outlined,
                    title: 'Vendeur',
                    subtitle: 'Gérer ma boutique, mes produits et mes commandes',
                    onTap: _loading ? null : () => _select('vendor'),
                  ),
                if (slugs.contains('driver'))
                  _ContextCard(
                    icon: Icons.delivery_dining_outlined,
                    title: 'Livreur',
                    subtitle: 'Recevoir des missions et livrer',
                    onTap: _loading ? null : () => _select('driver'),
                  ),
                const SizedBox(height: 40),
                OutlinedButton.icon(
                  onPressed: _loading ? null : () async {
                    await widget.session.logout();
                    if (mounted) {
                      context.go('/landing');
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x22000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}