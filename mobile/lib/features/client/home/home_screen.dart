import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Accueil client (J148) : catégories, produits en avant, boutiques.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.marketplace, required this.session});

  final MarketplaceApi marketplace;
  final SessionProvider session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.marketplace.home();
  }

  void _reload() {
    setState(() {
      _future = widget.marketplace.home();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/Logo.jpeg', width: 28, height: 28, errorBuilder: (_, __, ___) => const Icon(Icons.storefront)),
            const SizedBox(width: 8),
            const Text('Béninfood'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/client/search'),
            icon: const Icon(Icons.search),
            tooltip: 'Rechercher',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: FutureBuilder<HomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ListSkeleton();
            }
            if (snapshot.hasError) {
              if (snapshot.error is Object) {
                // ignore
              }
              return ErrorState(
                message: snapshot.error is ApiException
                    ? (snapshot.error as ApiException).message
                    : 'Impossible de charger l’accueil.',
                onRetry: _reload,
              );
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _CategoryStrip(categories: data.categories, onSelect: (id) {
                  if (id.isNotEmpty) {
                    context.push('/client/search', extra: {'category': id});
                  }
                }),
                if (data.vendors.isNotEmpty) ...[
                  const _SectionHeader(title: 'Boutiques'),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: data.vendors.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final v = data.vendors[index];
                        return _VendorTile(vendor: v, onTap: () => context.push('/client/shop/${v.id}'));
                      },
                    ),
                  ),
                ],
                if (data.featuredProducts.isNotEmpty) ...[
                  const _SectionHeader(title: 'Produits en avant'),
                  ...data.featuredProducts.map(
                    (p) => _ProductRow(
                      product: p,
                      onTap: () => context.push('/client/product/${p.id}'),
                      onAdd: () async {
                        try {
                          await widget.marketplace.addToCart(p.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ajouté au panier'), behavior: SnackBarBehavior.floating),
                            );
                          }
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
                if (data.vendors.isEmpty && data.featuredProducts.isEmpty)
                  const EmptyState(icon: Icons.shopping_bag_outlined, title: 'Aucune boutique pour le moment'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.categories, required this.onSelect});

  final List<dynamic> categories;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final c = categories[index] as dynamic;
          final name = _stringOf(c['name']);
          final id = _stringOf(c['id']);
          return InkWell(
            onTap: () => onSelect(id),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 88,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, color: Theme.of(context).colorScheme.primary, size: 26),
                  const SizedBox(height: 6),
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

String _stringOf(dynamic value, [String fallback = '']) => value is String ? value : fallback;

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
    );
  }
}

class _VendorTile extends StatelessWidget {
  const _VendorTile({required this.vendor, required this.onTap});

  final HomeVendor vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: AppNetworkImage(url: vendor.logoUrl, icon: Icons.storefront),
                  ),
                ),
                const SizedBox(width: 8),
                if (vendor.isOpen != null)
                  StatusBadge(label: vendor.isOpen! ? 'Ouvert' : 'Fermé', color: vendor.isOpen! ? Colors.green : Colors.grey, small: true),
              ],
            ),
            const Spacer(),
            Text(vendor.businessName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (vendor.city != null)
              Text(vendor.city!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap, required this.onAdd});

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 64, height: 64, child: AppNetworkImage(url: product.imageUrl)),
        ),
        title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(formatAmount(product.price), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        trailing: IconButton(
          onPressed: product.isOrderable ? onAdd : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ),
    );
  }
}