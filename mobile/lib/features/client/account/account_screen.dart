import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';

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
          _ProfileHeader(user: user),
          const SizedBox(height: 16),
          if ((user?.roleSlugs.length ?? 0) > 1) ...[
            const _SectionLabel(icon: Icons.swap_horiz, title: 'Espaces accessibles'),
            const SizedBox(height: 8),
            for (final (role, icon, title, subtitle) in _AvailableSpaces.items) ...[
              if (user!.contexts.contains(role)) ...[
                _SettingTile(
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  onTap: () {
                    session.switchRole(role);
                    if (role == AppContext.vendor) {
                      context.go('/vendor');
                    } else if (role == AppContext.driver) {
                      context.go('/driver');
                    } else {
                      context.go('/client');
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 8),
          ],
          const _SectionLabel(icon: Icons.receipt_long_outlined, title: 'Commandes'),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.receipt_long_outlined,
            title: 'Mes commandes',
            subtitle: 'Historique et suivi de vos achats',
            onTap: () => context.push('/client/orders'),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.shopping_bag_outlined,
            title: 'Mon panier',
            subtitle: 'Produits en attente de commande',
            onTap: () => context.push('/client/cart'),
          ),
          const SizedBox(height: 16),
          const _SectionLabel(icon: Icons.person_outline, title: 'Mes informations'),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.location_on_outlined,
            title: 'Mes adresses',
            subtitle: 'Gérer vos adresses de livraison',
            onTap: () => context.push('/client/addresses'),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.support_agent,
            title: 'Mes réclamations',
            subtitle: 'Suivre et ouvrir des réclamations',
            onTap: () => context.push('/client/complaints'),
          ),
          const SizedBox(height: 16),
          const _SectionLabel(icon: Icons.settings_outlined, title: 'Réglages'),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.dns_outlined,
            title: 'Réglages du serveur',
            subtitle: 'Adresse de l’API (appareil physique)',
            onTap: () => context.go('/server'),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: BorderSide(color: AppColors.red.withValues(alpha: 0.4)),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
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
}

class _AvailableSpaces {
  static const items = <(String, IconData, String, String)>[
    (AppContext.vendor, Icons.storefront_outlined, 'Espace vendeur', 'Produits, commandes, statistiques'),
    (AppContext.driver, Icons.delivery_dining_outlined, 'Espace livreur', 'Missions, disponibilité, gains'),
    (AppContext.client, Icons.person_outline, 'Espace client', 'Achats, panier, suivi'),
  ];
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'Utilisateur';
    final phone = user?.phone;
    final email = user?.email;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.orange, AppColors.orangeDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                if (phone != null)
                  _HeaderLine(text: phone),
                if (email != null) ...[
                  const SizedBox(height: 2),
                  _HeaderLine(text: email),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Client',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty && parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check, size: 13, color: Colors.white70),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.green),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AppColors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}