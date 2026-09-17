import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Fiche boutique (J149) : infos, horaires, produits.
class ShopDetailScreen extends StatefulWidget {
  const ShopDetailScreen({super.key, required this.marketplace, required this.vendorId});

  final MarketplaceApi marketplace;
  final String vendorId;

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  late Future<ShopDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.marketplace.vendor(widget.vendorId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boutique')),
      body: FutureBuilder<ShopDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Boutique introuvable.',
              onRetry: () => setState(() => _future = widget.marketplace.vendor(widget.vendorId)),
            );
          }
          final detail = snapshot.data!;
          final vendor = detail.vendor;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Container(
                height: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(url: vendor.coverUrl, icon: Icons.storefront),
                    Positioned(
                      bottom: 12,
                      left: 16,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(width: 64, height: 64, child: AppNetworkImage(url: vendor.logoUrl, icon: Icons.storefront)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(vendor.businessName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              if (vendor.city != null)
                                Text(vendor.city!, style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    if (vendor.isOpenResolved)
                      StatusBadge(label: vendor.isOpenResolved ? 'Ouvert' : 'Fermé', color: vendor.isOpenResolved ? Colors.green : Colors.grey),
                    if (vendor.description != null && vendor.description!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(vendor.description!, style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ],
                ),
              ),
              if (vendor.address != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(vendor.address!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              if (vendor.phone != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(vendor.phone!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              if (detail.hours.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                  child: Text('Horaires', style: Theme.of(context).textTheme.titleSmall),
                ),
                ...detail.hours.map(
                  (h) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(width: 90, child: Text(_dayName(h.dayOfWeek))),
                        Expanded(
                          child: h.isClosed
                              ? const Text('Fermé', style: TextStyle(color: Colors.grey))
                              : Text('${h.opensAt ?? ''} – ${h.closesAt ?? ''}'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text('Produits', style: Theme.of(context).textTheme.titleSmall),
              ),
              if (detail.products.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Aucun produit pour le moment', textAlign: TextAlign.center),
                ),
              ...detail.products.map(
                (p) => ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 52, height: 52, child: AppNetworkImage(url: p.imageUrl)),
                  ),
                  title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(formatAmount(p.price)),
                  trailing: p.isOrderable ? const Icon(Icons.add_circle_outline) : const Icon(Icons.cancel, color: Colors.grey),
                  onTap: p.isOrderable ? () => context.push('/client/product/${p.id}') : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _dayName(int day) {
    const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    return days[day.clamp(0, 6)];
  }
}