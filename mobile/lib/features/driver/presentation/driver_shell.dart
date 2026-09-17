import 'package:flutter/material.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../account/driver_account_screen.dart';
import '../history/driver_history_screen.dart';
import '../missions/driver_home_screen.dart';
import '../offers/offers_screen.dart';

/// Espace Livreur (J160) : missions, offres, historique, compte.
///
/// Le premier onglet vérifie le statut d'onboarding livreur : si le profil
/// n'est pas `active`, un panneau d'inscription et d'envoi de documents est
/// affiché à la place des missions.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key, required this.session, required this.marketplace});

  final SessionProvider session;
  final MarketplaceApi marketplace;

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  Map<String, dynamic>? _status;
  bool _statusLoading = true;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _statusLoading = true;
      _statusError = null;
    });
    try {
      final status = await widget.marketplace.driverStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _statusLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.isNotFound) {
          // Aucun profil livreur : l'utilisateur doit s'inscrire.
          setState(() {
            _status = null;
            _statusError = null;
            _statusLoading = false;
          });
        } else {
          setState(() {
            _statusError = e.message;
            _statusLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _buildFirstTab(),
          OffersScreen(marketplace: widget.marketplace),
          DriverHistoryScreen(marketplace: widget.marketplace),
          DriverAccountScreen(session: widget.session, marketplace: widget.marketplace),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), selectedIcon: Icon(Icons.delivery_dining), label: 'Missions'),
          NavigationDestination(icon: Icon(Icons.local_offer_outlined), selectedIcon: Icon(Icons.local_offer), label: 'Offres'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Historique'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Compte'),
        ],
      ),
    );
  }

  Widget _buildFirstTab() {
    if (_statusLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_statusError != null) {
      return ErrorState(message: _statusError!, onRetry: _loadStatus);
    }

    final rawProfile = _status?['profile'];
    final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
    final rawDocuments = _status?['documents'];
    final documents = rawDocuments is List
        ? rawDocuments.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    if (profile?['status'] == 'active') {
      return DriverHomeScreen(marketplace: widget.marketplace);
    }

    return _DriverOnboarding(
      marketplace: widget.marketplace,
      profile: profile,
      documents: documents,
      onRefresh: _loadStatus,
    );
  }
}

/// Panneau d'inscription livreur affiché tant que le profil n'est pas actif.
class _DriverOnboarding extends StatefulWidget {
  const _DriverOnboarding({
    required this.marketplace,
    required this.profile,
    required this.documents,
    required this.onRefresh,
  });

  final MarketplaceApi marketplace;
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> documents;
  final Future<void> Function() onRefresh;

  @override
  State<_DriverOnboarding> createState() => _DriverOnboardingState();
}

class _DriverOnboardingState extends State<_DriverOnboarding> {
  static const _docTypes = <(String, String)>[
    ('id_card', 'Pièce d\'identité'),
    ('driver_license', 'Permis de conduire'),
    ('vehicle_registration', 'Carte grise'),
    ('insurance', 'Assurance'),
    ('photo', 'Photo du livreur'),
  ];

  final _vehicle = TextEditingController();
  bool _submitting = false;
  String? _uploadingType;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.profile?['vehicle'];
    if (vehicle is String) {
      _vehicle.text = vehicle;
    }
  }

  @override
  void dispose() {
    _vehicle.dispose();
    super.dispose();
  }

  List<int> _placeholderPdf() {
    const header = <int>[
      0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A, 0x25,
      0xE2, 0xE3, 0xCF, 0xD3, 0x0A,
    ];
    return [...header, ...List<int>.filled(100 - header.length, 0x20)];
  }

  Future<void> _submitVehicle() async {
    if (_vehicle.text.trim().isEmpty) {
      showToast(context, 'Renseignez votre véhicule.', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      try {
        await widget.marketplace.driverOnboarding(vehicle: _vehicle.text.trim());
      } on ApiException catch (e) {
        if (!e.isConflict) {
          rethrow;
        }
      }
      await widget.onRefresh();
      if (mounted) {
        showToast(context, 'Inscription enregistrée.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _uploadDocument(String type, String label) async {
    if (_uploadingType != null) {
      return;
    }
    setState(() => _uploadingType = type);
    try {
      await widget.marketplace.uploadDriverDocument(type, _placeholderPdf(), fileName: '$type.pdf');
      await widget.onRefresh();
      if (mounted) {
        showToast(context, '$label envoyé (démo).');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingType = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.profile;
    final hasProfile = profile != null;
    final rawStatus = profile?['status'];
    final status = rawStatus is String ? rawStatus : null;
    final palette = BadgePalette.driver(status);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.delivery_dining, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Espace livreur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        if (palette != null)
                          StatusBadge(label: palette.$1, color: palette.$2)
                        else
                          const StatusBadge(label: 'Inscription à compléter', color: Colors.blueGrey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Inscription livreur', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Renseignez votre véhicule et fournissez vos documents justificatifs '
            'pour être validé comme livreur Béninfood.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _vehicle,
            label: 'Véhicule',
            hint: 'Ex : Moto, voiture…',
            icon: Icons.two_wheeler_outlined,
            enabled: !hasProfile,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: hasProfile ? 'Inscription enregistrée' : 'Enregistrer mon inscription',
            icon: Icons.person_add_alt,
            enabled: !hasProfile,
            onPressed: _submitVehicle,
            loading: _submitting,
          ),
          const SizedBox(height: 24),
          Text('Documents justificatifs', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            hasProfile
                ? 'Démo : un document PDF d\'exemple est généré automatiquement.'
                : 'Enregistrez d\'abord votre inscription pour envoyer vos documents.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final (type, label) in _docTypes) ...[
            _documentTile(type, label, hasProfile),
            const SizedBox(height: 8),
          ],
          if (widget.documents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Documents transmis', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: widget.documents.map((doc) {
                  final docStatus = doc['status'];
                  final reason = doc['reason'];
                  return ListTile(
                    leading: Icon(_statusIcon(docStatus), color: _statusColor(docStatus)),
                    title: Text(_documentTypeLabel(doc['type'] is String ? doc['type'] as String : '')),
                    subtitle: Text([
                      _documentStatusLabel(docStatus),
                      if (reason is String && reason.isNotEmpty) ' · $reason',
                    ].join()),
                    trailing: Text(
                      formatDate(doc['created_at'] is String ? doc['created_at'] as String : null, fallback: ''),
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'Rafraîchir',
            variant: AppButtonVariant.outline,
            icon: Icons.refresh,
            onPressed: () => widget.onRefresh(),
          ),
        ],
      ),
    );
  }

  Widget _documentTile(String type, String label, bool enabled) {
    final theme = Theme.of(context);
    final uploading = _uploadingType == type;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              color: enabled ? theme.colorScheme.primary : theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    enabled ? 'Support PDF, JPG ou PNG' : 'Disponible après inscription',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (uploading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            else
              TextButton(
                onPressed: enabled ? () => _uploadDocument(type, label) : null,
                child: const Text('Ajouter'),
              ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(dynamic status) => switch (status) {
        'valid' => Icons.check_circle,
        'invalid' => Icons.cancel,
        _ => Icons.schedule,
      };

  Color _statusColor(dynamic status) => switch (status) {
        'valid' => Colors.green,
        'invalid' => Colors.red,
        _ => Colors.grey,
      };

  String _documentStatusLabel(dynamic status) => switch (status) {
        'valid' => 'Validé',
        'invalid' => 'Rejeté',
        _ => 'En vérification',
      };

  String _documentTypeLabel(String type) => switch (type) {
        'id_card' => 'Pièce d\'identité',
        'driver_license' => 'Permis de conduire',
        'vehicle_registration' => 'Carte grise',
        'insurance' => 'Assurance',
        'photo' => 'Photo du livreur',
        _ => type,
      };
}
