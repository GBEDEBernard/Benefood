import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';

/// Compte client (J153) : profil, choix de rôle, commandes rapides, déconnexion.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    final user = session.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      _initials(user?.name ?? '?'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (user?.phone != null) Text(user!.phone, style: Theme.of(context).textTheme.bodySmall),
                        if (user?.email != null) Text(user!.email ?? '', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if ((user?.roleSlugs.length ?? 0) > 1) ...[
            Text('Espaces accessibles', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  if (user!.hasRoleVendor)
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: const Text('Espace vendeur'),
                      subtitle: const Text('Produits, commandes, statistiques'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        session.switchRole('vendor');
                        context.go('/vendor');
                      },
                    ),
                  if (user.hasRoleDriver)
                    ListTile(
                      leading: const Icon(Icons.delivery_dining_outlined),
                      title: const Text('Espace livreur'),
                      subtitle: const Text('Missions, disponibilité, gains'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        session.switchRole('driver');
                        context.go('/driver');
                      },
                    ),
                  if (user.hasRoleClient)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Espace client'),
                      subtitle: const Text('Achats, panier, suivi'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        session.switchRole('client');
                        context.go('/client');
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('Mes informations', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Mes adresses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/client/addresses'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: const Text('Mes réclamations'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/client/complaints'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: Text('Se déconnecter', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await session.logout();
      if (context.mounted) {
        context.go('/landing');
      }
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty && parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}