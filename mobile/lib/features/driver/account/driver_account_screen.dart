import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Compte livreur (J165) : profil, statut, disponibilité, espaces et déconnexion.
class DriverAccountScreen extends StatefulWidget {
  const DriverAccountScreen({super.key, required this.session, required this.marketplace});

  final SessionProvider session;
  final MarketplaceApi marketplace;

  @override
  State<DriverAccountScreen> createState() => _DriverAccountScreenState();
}

class _DriverAccountScreenState extends State<DriverAccountScreen> {
  Map<String, dynamic>? _status;
  bool _loading = true;
  String? _error;
  bool _available = false;
  bool _toggling = false;
  bool _switching = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await widget.marketplace.driverStatus();
      final rawProfile = status['profile'];
      final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
      if (mounted) {
        setState(() {
          _status = status;
          _available = profile?['available'] == true;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    final previous = _available;
    setState(() {
      _available = value;
      _toggling = true;
    });
    try {
      await widget.marketplace.setAvailability(value);
      if (mounted) {
        setState(() => _toggling = false);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _available = previous;
          _toggling = false;
        });
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _switchToClient() async {
    setState(() => _switching = true);
    try {
      await widget.session.switchRole('client');
      if (mounted) {
        context.go('/client');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _switching = false);
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Déconnexion',
      message: 'Voulez-vous vraiment vous déconnecter ?',
      confirmLabel: 'Déconnecter',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _loggingOut = true);
    await widget.session.logout();
    if (mounted) {
      context.go('/landing');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final theme = Theme.of(context);

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
                    backgroundColor: theme.colorScheme.primaryContainer,
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
                        if (user != null) Text(user.phone, style: theme.textTheme.bodySmall),
                        if (user?.email != null) Text(user!.email!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Mon profil livreur', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else
            _buildDriverCard(),
          const SizedBox(height: 16),
          AppButton(
            label: 'Rafraîchir',
            variant: AppButtonVariant.outline,
            icon: Icons.refresh,
            onPressed: _load,
          ),
          if (user?.hasRoleClient ?? false) ...[
            const SizedBox(height: 12),
            AppButton(
              label: 'Retour à l\'espace client',
              icon: Icons.shopping_bag_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: _switching ? null : _switchToClient,
              loading: _switching,
            ),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: 'Se déconnecter',
            icon: Icons.logout,
            variant: AppButtonVariant.danger,
            onPressed: _loggingOut ? null : _confirmLogout,
            loading: _loggingOut,
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
    final theme = Theme.of(context);
    final rawProfile = _status?['profile'];
    final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
    final rawStatus = profile?['status'];
    final status = rawStatus is String ? rawStatus : null;
    final palette = BadgePalette.driver(status);
    final rawVehicle = profile?['vehicle'];
    final vehicle = rawVehicle is String ? rawVehicle : null;
    final rating = profile?['rating'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delivery_dining, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vehicle == null || vehicle.isEmpty ? 'Livreur Béninfood' : vehicle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (palette != null) StatusBadge(label: palette.$1, color: palette.$2, small: true),
              ],
            ),
            if (rating != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.star_rate, size: 18, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text('Note : $rating', style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _available,
              onChanged: _toggling ? null : _toggleAvailability,
              title: const Text('Disponible pour les livraisons'),
            ),
          ],
        ),
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
