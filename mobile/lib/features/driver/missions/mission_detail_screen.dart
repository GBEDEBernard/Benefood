import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/delivery.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Détail d'une mission (J162) : informations et actions de progression.
class MissionDetailScreen extends StatefulWidget {
  const MissionDetailScreen({
    super.key,
    required this.marketplace,
    required this.deliveryId,
    this.initialDelivery,
  });

  final MarketplaceApi marketplace;
  final String deliveryId;
  final Delivery? initialDelivery;

  @override
  State<MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends State<MissionDetailScreen> {
  static const _locationInterval = Duration(seconds: 30);

  Delivery? _delivery;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  Timer? _locationTimer;
  bool _sendingLocation = false;
  LocationFailure? _reportedFailure;

  static const _activeStatuses = {'assigned', 'picked_up', 'in_delivery'};

  @override
  void initState() {
    super.initState();
    _delivery = widget.initialDelivery;
    _load();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  bool get _shouldReportLocation => _delivery != null && _activeStatuses.contains(_delivery!.status);

  void _syncLocationReporting() {
    _locationTimer?.cancel();
    _locationTimer = null;
    if (!_shouldReportLocation) {
      return;
    }
    _sendLocation();
    _locationTimer = Timer.periodic(_locationInterval, (_) => _sendLocation());
  }

  Future<void> _sendLocation() async {
    if (_sendingLocation) {
      return;
    }
    _sendingLocation = true;
    try {
      final result = await LocationService.locate();
      if (result.isSuccess) {
        final geo = result.geo!;
        _reportedFailure = null;
        if (mounted && _shouldReportLocation) {
          await widget.marketplace.updateDriverLocation(geo.latitude, geo.longitude);
        }
        return;
      }
      if (mounted && _shouldReportLocation && _reportedFailure != result.failure) {
        _reportedFailure = result.failure;
        showToast(context, _locationFailureMessage(result.failure), isError: true);
      }
    } catch (_) {
      // Position indisponible : on réessaiera au prochain tick.
    } finally {
      _sendingLocation = false;
    }
  }

  static String _locationFailureMessage(LocationFailure? failure) => switch (failure) {
        LocationFailure.serviceDisabled => 'Suivi interrompu : activez le GPS pour être localisé.',
        LocationFailure.permissionDenied => 'Suivi interrompu : autorisez la localisation dans les réglages pour le client.',
        _ => 'Position introuvable : votre position sera retransmise dès que possible.',
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deliveries = await widget.marketplace.myDeliveries();
      Delivery? match;
      for (final delivery in deliveries) {
        if (delivery.id == widget.deliveryId) {
          match = delivery;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _delivery = match ?? _delivery;
          _loading = false;
        });
        _syncLocationReporting();
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

  Future<void> _run(Future<Delivery> Function() action, String successMessage) async {
    setState(() => _actionLoading = true);
    try {
      final updated = await action();
      if (mounted) {
        setState(() {
          _delivery = updated;
          _actionLoading = false;
        });
        _syncLocationReporting();
        showToast(context, successMessage);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  Future<void> _pickup() => _run(
        () => widget.marketplace.markPickedUp(widget.deliveryId),
        'Commande récupérée.',
      );

  Future<void> _start() => _run(
        () => widget.marketplace.markInDelivery(widget.deliveryId),
        'Livraison démarrée.',
      );

  Future<void> _deliver() async {
    final proofCode = await _askProofCode();
    if (!mounted) {
      return;
    }
    await _run(
      () => widget.marketplace.markDelivered(widget.deliveryId, proofCode: proofCode),
      'Commande livrée.',
    );
  }

  Future<void> _incident() async {
    final message = await _askIncidentMessage();
    if (message == null || !mounted) {
      return;
    }
    await _run(
      () => widget.marketplace.reportIncident(widget.deliveryId, message),
      'Incident signalé.',
    );
  }

  Future<String?> _askProofCode() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preuve de livraison'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Code de confirmation',
            hintText: 'Optionnel',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
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
      appBar: AppBar(title: const Text('Détail de la mission')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _delivery == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _delivery == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final delivery = _delivery;
    if (delivery == null) {
      return const EmptyState(icon: Icons.search_off, title: 'Mission introuvable');
    }

    final theme = Theme.of(context);
    final palette = BadgePalette.delivery(delivery.status);
    final order = delivery.order;
    final vendor = delivery.vendor;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order?.reference ?? 'Mission',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (palette != null) StatusBadge(label: palette.$1, color: palette.$2),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Collecte'),
                  subtitle: Text([
                    vendor?.businessName ?? 'Vendeur',
                    vendor?.address ?? '',
                    vendor?.city ?? '',
                  ].where((e) => e.isNotEmpty).join('\n')),
                ),
                if (vendor != null && (vendor.address != null || vendor.city != null))
                  const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(order?.client?.name ?? 'Client'),
                  subtitle: order?.client?.phone != null ? Text(order!.client!.phone!) : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Adresse de livraison'),
                  subtitle: Text(order?.address ?? '—'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('Frais de livraison', style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      AmountText(delivery.fee, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (delivery.partnerAmount != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Votre part', style: theme.textTheme.bodyMedium),
                        const Spacer(),
                        AmountText(delivery.partnerAmount, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chronologie', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._timelineRows(delivery),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (delivery.status == 'assigned')
            AppButton(
              label: 'J\'ai récupéré la commande',
              icon: Icons.inventory_2_outlined,
              onPressed: _actionLoading ? null : _pickup,
              loading: _actionLoading,
            ),
          if (delivery.status == 'picked_up')
            AppButton(
              label: 'Démarrer la livraison',
              icon: Icons.directions_bike,
              onPressed: _actionLoading ? null : _start,
              loading: _actionLoading,
            ),
          if (delivery.status == 'in_delivery')
            AppButton(
              label: 'Livrer',
              icon: Icons.check_circle_outline,
              onPressed: _actionLoading ? null : _deliver,
              loading: _actionLoading,
            ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Signaler un incident',
            variant: AppButtonVariant.outline,
            icon: Icons.report_problem_outlined,
            onPressed: _actionLoading ? null : _incident,
          ),
        ],
      ),
    );
  }

  List<Widget> _timelineRows(Delivery delivery) {
    final entries = <(String, String?)>[
      ('Créée', delivery.createdAt),
      ('Affectée', delivery.assignedAt),
      ('Collectée', delivery.pickedUpAt),
      ('Livrée', delivery.deliveredAt),
    ];

    final theme = Theme.of(context);
    return entries
        .where((entry) => entry.$2 != null && entry.$2!.isNotEmpty)
        .map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.radio_button_checked, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        formatDateTime(entry.$2, fallback: ''),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}
