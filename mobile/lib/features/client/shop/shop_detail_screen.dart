import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/vendor.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/product_cards.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/status_badge.dart';

/// Fiche boutique (J149) : couverture, infos, horaires, produits.
class ShopDetailScreen extends StatefulWidget {
  const ShopDetailScreen({
    super.key,
    required this.marketplace,
    required this.vendorId,
  });

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

  Future<void> _addToCart(Product product) async {
    try {
      await widget.marketplace.addToCart(product.id);
      if (!mounted) {
        return;
      }
      showToast(context, 'Ajouté au panier');
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      showToast(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boutique')),
      body: FutureBuilder<ShopDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ListSkeleton();
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : 'Boutique introuvable.',
              onRetry: () {
                final next = widget.marketplace.vendor(widget.vendorId);
                setState(() {
                  _future = next;
                });
              },
            );
          }
          final detail = snapshot.data!;
          final vendor = detail.vendor;
          final products = detail.products.where((p) => p.isOrderable).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _ShopHeader(vendor: vendor),
              if (vendor.description != null && vendor.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    vendor.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              if (detail.hours.isNotEmpty) ...[
                const SectionHeader(title: 'Horaires'),
                _HoursList(hours: detail.hours),
              ],
              const SectionHeader(title: 'Produits'),
              if (detail.products.isEmpty)
                const EmptyState(
                  icon: Icons.fastfood_outlined,
                  title: 'Aucun produit pour le moment',
                )
              else if (products.isEmpty)
                const EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Boutique momentanément indisponible',
                )
              else
                ProductGrid(
                  products: products,
                  shrinkWrap: true,
                  onTap: (p) => context.push('/client/product/${p.id}'),
                  onAdd: _addToCart,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.vendor});

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          SizedBox(
            height: 170,
            width: double.infinity,
            child: AppNetworkImage(
              url: vendor.coverUrl,
              icon: Icons.storefront,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: AppNetworkImage(
                          url: vendor.logoUrl,
                          icon: Icons.storefront,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          vendor.businessName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (vendor.isOpen != null) ...[
                          const SizedBox(height: 4),
                          StatusBadge(
                            label: vendor.isOpenResolved
                                ? 'Ouvert maintenant'
                                : 'Fermé actuellement',
                            color: vendor.isOpenResolved
                                ? AppColors.green
                                : Colors.grey,
                            small: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursList extends StatelessWidget {
  const _HoursList({required this.hours});

  final List<OpeningHour> hours;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: hours.map((h) {
            final isToday = _isToday(h.dayOfWeek);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    _dayName(h.dayOfWeek),
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday ? AppColors.green : AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    h.isClosed
                        ? 'Fermé'
                        : '${h.opensAt ?? ''} – ${h.closesAt ?? ''}',
                    style: TextStyle(
                      color: h.isClosed
                          ? AppColors.textSecondary
                          : (isToday ? AppColors.green : AppColors.text),
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _isToday(int dayOfWeek) {
    final today = DateTime.now().weekday; // 1 = lundi
    const mapping = [1, 2, 3, 4, 5, 6, 7]; // lundi..dimanche
    return mapping[(today - 1 + 7) % 7] == dayOfWeek;
  }

  String _dayName(int day) {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    return days[day.clamp(0, 6)];
  }
}
