import 'package:flutter/material.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../account/vendor_account_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../onboarding/vendor_onboarding_screen.dart';
import '../orders/vendor_orders_screen.dart';
import '../products/products_screen.dart';

/// Espace Vendeur (J154) : tableau de bord, produits, commandes, compte.
///
/// Le premier onglet vérifie le statut d'onboarding vendeur : si le compte n'est
/// pas `active`, un écran de soumission du dossier est affiché à la place.
class VendorShell extends StatefulWidget {
  const VendorShell({super.key, required this.session, required this.marketplace});

  final SessionProvider session;
  final MarketplaceApi marketplace;

  @override
  State<VendorShell> createState() => _VendorShellState();
}

class _VendorShellState extends State<VendorShell> {
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
      final status = await widget.marketplace.vendorStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _statusLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          // Pas encore de profil vendeur : on laisse l'onboarding s'afficher.
          if (e.code == 'vendor.not_onboarded') {
            _status = null;
          } else {
            _statusError = e.message;
          }
          _statusLoading = false;
        });
      }
    }
  }

  Future<void> _openOnboarding() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => VendorOnboardingScreen(marketplace: widget.marketplace),
      ),
    );
    if (changed == true) {
      await _loadStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _buildFirstTab(),
          ProductsScreen(marketplace: widget.marketplace),
          VendorOrdersScreen(marketplace: widget.marketplace),
          VendorAccountScreen(session: widget.session, marketplace: widget.marketplace),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Tableau de bord'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Produits'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Commandes'),
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

    final rawVendor = _status?['vendor'];
    final vendor = rawVendor is Map<String, dynamic> ? rawVendor : null;
    final rawDocuments = _status?['documents'];
    final documents = rawDocuments is List
        ? rawDocuments.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    final status = vendor?['status'];
    if (status == 'active') {
      return DashboardScreen(
        marketplace: widget.marketplace,
        onGoToTab: (i) => setState(() => _index = i),
      );
    }

    return _OnboardingGate(
      vendor: vendor,
      documents: documents,
      onRefresh: _loadStatus,
      onStartOnboarding: _openOnboarding,
    );
  }
}

/// Panneau affiché tant que le profil vendeur n'est pas actif.
class _OnboardingGate extends StatelessWidget {
  const _OnboardingGate({
    required this.vendor,
    required this.documents,
    required this.onRefresh,
    required this.onStartOnboarding,
  });

  final Map<String, dynamic>? vendor;
  final List<Map<String, dynamic>> documents;
  final Future<void> Function() onRefresh;
  final VoidCallback onStartOnboarding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _stringOrNull(vendor?['status']);
    final palette = BadgePalette.vendor(status);
    final businessName = _stringOrNull(vendor?['business_name']) ?? 'Ma boutique';
    final pendingDocs = documents
        .where((d) {
          final s = d['status'];
          return s == 'submitted' || s == 'pending';
        })
        .toList();
    final rejectedDocs = documents
        .where((d) => d['status'] == 'invalid')
        .toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
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
                    child: Icon(Icons.storefront_outlined, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(businessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        if (palette != null) StatusBadge(label: palette.$1, color: palette.$2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Vérification de votre dossier', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Renseignez les informations de votre boutique et fournissez vos documents '
            'pour être validé comme vendeur Béninfood.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: documents.isEmpty
                  ? const ListTile(
                      leading: Icon(Icons.folder_off_outlined),
                      title: Text('Aucun document fourni'),
                      subtitle: Text('IFU et registre de commerce attendus.'),
                    )
                  : Column(
                      children: documents.map((doc) {
                        return ListTile(
                          leading: Icon(_statusIcon(doc['status']), color: _statusColor(doc['status'])),
                          title: Text(_documentTypeLabel(doc['type'] is String ? doc['type'] as String : '')),
                          subtitle: Text([
                            _documentStatusLabel(doc['status']),
                            if (doc['reason'] is String && (doc['reason'] as String).isNotEmpty)
                              ' · ${doc['reason']}',
                          ].join()),
                          trailing: Text(
                            formatDate(doc['created_at'] is String ? doc['created_at'] as String : null, fallback: ''),
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
          if (pendingDocs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('En vérification', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'Votre dossier est en cours de vérification par nos équipes. '
                            'Vous pourrez gérer vos produits dès validation.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (rejectedDocs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Documents à corriger', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'Certains documents ont été rejetés. Merci de les renvoyer.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: documents.isEmpty ? 'Commencer l\'inscription' : 'Compléter mon dossier',
            icon: Icons.fact_check_outlined,
            onPressed: onStartOnboarding,
          ),
        ],
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
        'ifu' => 'IFU (Identifiant Fiscal Unique)',
        'business_registration' => 'Registre de commerce / Patente',
        'id_card' => 'Pièce d\'identité',
        'store_photo' => 'Photo de la boutique',
        _ => type,
      };
}

String? _stringOrNull(dynamic value) => value is String ? value : null;