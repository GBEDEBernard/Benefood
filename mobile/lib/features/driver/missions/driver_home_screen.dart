import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/models/delivery.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';
import 'mission_detail_screen.dart';

/// Missions livreur (J161) : disponibilité et livraisons en cours.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  List<Delivery> _deliveries = [];
  bool _available = false;
  bool _loading = true;
  bool _toggling = false;
  String? _error;

  static const _activeStatuses = {'assigned', 'picked_up', 'in_delivery'};

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
      final deliveries = await widget.marketplace.myDeliveries();
      final rawProfile = status['profile'];
      final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
      if (mounted) {
        setState(() {
          _available = profile?['available'] == true;
          _deliveries = deliveries;
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
        showToast(context, value ? 'Vous êtes disponible.' : 'Vous êtes indisponible.');
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

  Future<void> _reportIncident(Delivery delivery) async {
    final message = await _askIncidentMessage();
    if (message == null || !mounted) {
      return;
    }
    try {
      await widget.marketplace.reportIncident(delivery.id, message);
      await _load();
      if (mounted) {
        showToast(context, 'Incident signalé.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<String?> _askIncidentMessage() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signaler un incident'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Décrivez l\'incident *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 3) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes missions')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final active = _deliveries.where((d) => _activeStatuses.contains(d.status)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              value: _available,
              onChanged: _toggling ? null : _toggleAvailability,
              secondary: Icon(
                _available ? Icons.check_circle : Icons.pause_circle_outline,
                color: _available ? Colors.green : Theme.of(context).colorScheme.outline,
              ),
              title: const Text('Disponible pour les livraisons'),
              subtitle: Text(_available ? 'Vous recevez des offres.' : 'Vous ne recevez pas d\'offres.'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Missions en cours', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (active.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(
                icon: Icons.delivery_dining_outlined,
                title: 'Aucune mission en cours',
                subtitle: 'Activez votre disponibilité pour recevoir des offres.',
              ),
            )
          else
            for (final delivery in active)
              _MissionCard(
                delivery: delivery,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => MissionDetailScreen(
                      marketplace: widget.marketplace,
                      deliveryId: delivery.id,
                      initialDelivery: delivery,
                    ),
                  ),
                ),
                onIncident: () => _reportIncident(delivery),
              ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.delivery, required this.onTap, required this.onIncident});

  final Delivery delivery;
  final VoidCallback onTap;
  final VoidCallback onIncident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = BadgePalette.delivery(delivery.status);
    final reference = delivery.order?.reference ?? 'Mission';
    final vendorName = delivery.vendor?.businessName ?? 'Vendeur';
    final clientAddress = delivery.order?.address;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(reference, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (palette != null)
                    StatusBadge(label: palette.$1, color: palette.$2, small: true),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.storefront_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(vendorName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              if (clientAddress != null && clientAddress.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        clientAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 16),
                  const SizedBox(width: 6),
                  AmountText(delivery.fee, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: onIncident,
                    child: const Text('Signaler un incident'),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: onTap,
                  child: Text(_actionLabel(delivery.status)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _actionLabel(String status) => switch (status) {
        'assigned' => 'J\'ai récupéré la commande',
        'picked_up' => 'Démarrer la livraison',
        'in_delivery' => 'Livrer',
        _ => 'Voir la mission',
      };
}
