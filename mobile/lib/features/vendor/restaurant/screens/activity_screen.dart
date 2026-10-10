import 'package:flutter/material.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../restaurant_palette.dart';
import '../screens/order_details_screen.dart';
import '../widgets/vendor_screen_header.dart';

/// Historique des activités (J21 §10) : chronologie des événements du compte,
/// des documents, des commandes et des produits.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, this.marketplace, this.onOpenDrawer});

  final MarketplaceApi? marketplace;
  final VoidCallback? onOpenDrawer;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  bool get _demoMode => widget.marketplace == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_demoMode) {
      setState(() {
        _events = _demoEvents();
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.marketplace!.vendorActivity();
      if (mounted) {
        setState(() {
          _events = events;
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

  /// Ouvre le détail d'une commande depuis l'historique (clic sur événement).
  Future<void> _openEvent(_ActivityEvent event) async {
    final api = widget.marketplace!;
    if (event.orderId != null) {
      try {
        final order = await api.order(event.orderId!);
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OrderDetailsScreen(
              order: order,
              onAccept: (o) async {
                try { await api.vendorAccept(o.id); return true; } catch (_) { return false; }
              },
              onRefuse: (o) async {
                try { await api.vendorRefuse(o.id, reason: 'Refusé par le vendeur'); return true; } catch (_) { return false; }
              },
              onPrepare: (o) async {
                try { await api.vendorPreparing(o.id); return true; } catch (_) { return false; }
              },
              onReady: (o) async {
                try { await api.vendorReady(o.id); return true; } catch (_) { return false; }
              },
            ),
          ),
        );
      } on ApiException {
        if (mounted) showToastSimple(context);
      }
    } else if (event.productId != null) {
      // Les produits sont listés sous leur nom : rien à ouvrir directement.
    }
  }

  void showToastSimple(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossible d\'ouvrir cette activité.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RestaurantPalette.background,
      child: Column(
        children: [
          VendorScreenHeader(title: 'HISTORIQUE', onOpenDrawer: widget.onOpenDrawer),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && !_demoMode) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_events.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'Aucune activité',
        subtitle: 'Les événements de votre boutique apparaîtront ici.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _ActivityEvent.fromJson(_events[index]);
          return _ActivityTile(
            event: event,
            last: index == _events.length - 1,
            onTap: event.isClickable && widget.marketplace != null
                ? () => _openEvent(event)
                : null,
          );
        },
      ),
    );
  }
}

class _ActivityEvent {
  const _ActivityEvent({
    required this.type,
    required this.label,
    this.description,
    this.createdAt,
    this.orderId,
    this.productId,
  });

  final String type;
  final String label;
  final String? description;
  final String? createdAt;

  /// Identifiants pour rendre l'historique cliquable : un événement de
  /// commande ouvre son détail, un événement produit ouvre le formulaire.
  final String? orderId;
  final String? productId;

  factory _ActivityEvent.fromJson(Map<String, dynamic> json) => _ActivityEvent(
        type: json['type'] as String? ?? 'account',
        label: json['label'] as String? ?? '',
        description: json['description'] as String?,
        createdAt: json['created_at'] as String?,
        orderId: json['order_id'] is String ? json['order_id'] as String : null,
        productId: json['product_id'] is String ? json['product_id'] as String : null,
      );

  bool get isClickable => orderId != null || productId != null;

  IconData get icon => switch (type) {
        'document' => Icons.folder_outlined,
        'order' => Icons.receipt_long_outlined,
        'product' => Icons.inventory_2_outlined,
        _ => Icons.verified_user_outlined,
      };

  Color get color => switch (type) {
        'document' => RestaurantPalette.ready,
        'order' => RestaurantPalette.orange,
        'product' => RestaurantPalette.success,
        _ => RestaurantPalette.forest,
      };
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.event, required this.last, this.onTap});

  final _ActivityEvent event;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: event.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(event.icon, size: 19, color: event.color),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: RestaurantPalette.borderColor,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: RestaurantPalette.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: RestaurantPalette.darkText,
                              ),
                            ),
                          ),
                          Text(
                            formatDateTime(event.createdAt),
                            style: const TextStyle(fontSize: 11, color: RestaurantPalette.grayText),
                          ),
                        ],
                      ),
                      if (event.description != null && event.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.description!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: RestaurantPalette.grayText,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _demoEvents() {
  final now = DateTime.now();
  return [
    {'type': 'order', 'label': 'Commande livrée', 'description': '#BF1250', 'created_at': now.subtract(const Duration(hours: 1)).toIso8601String()},
    {'type': 'order', 'label': 'Commande prête', 'description': '#BF1251', 'created_at': now.subtract(const Duration(hours: 3)).toIso8601String()},
    {'type': 'product', 'label': 'Produit ajouté', 'description': 'Jus de bissap', 'created_at': now.subtract(const Duration(days: 1)).toIso8601String()},
    {'type': 'document', 'label': 'Document accepté', 'description': 'Registre de commerce / Patente', 'created_at': now.subtract(const Duration(days: 2)).toIso8601String()},
    {'type': 'document', 'label': 'Document rejeté', 'description': 'Photo de la boutique · Image floue', 'created_at': now.subtract(const Duration(days: 3)).toIso8601String()},
    {'type': 'account', 'label': 'Compte activé', 'description': null, 'created_at': now.subtract(const Duration(days: 10)).toIso8601String()},
  ];
}
