import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/parcel.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/profile_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Mes colis — expéditions de l'espace courant (cahier v1.0, phase 3).
///
/// Liste des envois avec statut, trajet A → B et frais ; accès à la création
/// d'une nouvelle expédition et au suivi détaillé. Partagée par le client et
/// la boutique vendeuse, qui peuvent tous deux envoyer des colis.
class ParcelsScreen extends StatefulWidget {
  const ParcelsScreen({
    super.key,
    required this.marketplace,
    this.audience = NotificationAudience.client,
  });

  final MarketplaceApi marketplace;
  final NotificationAudience audience;

  @override
  State<ParcelsScreen> createState() => _ParcelsScreenState();
}

class _ParcelsScreenState extends State<ParcelsScreen> {
  List<Parcel> _parcels = [];
  bool _loading = true;
  String? _error;

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
      final parcels = await widget.marketplace.myParcels();
      if (mounted) {
        setState(() {
          _parcels = parcels;
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

  /// Base des routes colis de l'espace courant.
  String get _basePath => widget.audience == NotificationAudience.vendor
      ? '/vendor/parcels'
      : '/client/parcels';

  Future<void> _openDetail(Parcel parcel) async {
    await context.push('$_basePath/${parcel.id}');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'parcel-new',
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () async {
          await context.push('$_basePath/new');
          await _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Envoyer un colis'),
      ),
      body: Column(
        children: [
          BeninfoodAppBar(
            onMenu: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/${widget.audience.name}');
              }
            },
            api: widget.marketplace,
            audience: widget.audience,
          ),
          const ProfilePageTitle('Mes colis'),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_parcels.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: 96 + AppDimens.xxl),
          children: const [
            EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Aucun colis envoyé',
              subtitle: 'Vos expéditions apparaîtront ici.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          AppDimens.sm,
          AppDimens.pagePadding,
          96 + AppDimens.xxl,
        ),
        itemCount: _parcels.length,
        itemBuilder: (context, index) => _ParcelCard(
          parcel: _parcels[index],
          onTap: () => _openDetail(_parcels[index]),
        ),
      ),
    );
  }
}

class _ParcelCard extends StatelessWidget {
  const _ParcelCard({required this.parcel, required this.onTap});

  final Parcel parcel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = BadgePalette.parcel(parcel.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      parcel.reference,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                  ),
                  if (palette != null)
                    StatusBadge(label: palette.$1, color: palette.$2, small: true),
                ],
              ),
              const SizedBox(height: AppDimens.sm),
              _AddressRow(
                icon: Icons.trip_origin,
                color: AppColors.green,
                text: parcel.pickup?.display ?? '—',
              ),
              const SizedBox(height: 6),
              _AddressRow(
                icon: Icons.place,
                color: AppColors.orange,
                text: parcel.dropoff?.display ?? '—',
              ),
              const SizedBox(height: AppDimens.md),
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      formatDateTime(parcel.createdAt, fallback: '—'),
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  AmountText(parcel.deliveryFee, style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              if (parcel.isAwaitingPayment) ...[
                const SizedBox(height: AppDimens.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: const Text(
                    'Paiement requis pour qu\'un livreur puisse prendre ce colis.',
                    style: TextStyle(fontSize: 12, color: AppColors.orangeDark, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}