import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/vendor.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Recherche & exploration client (J149) : produits + boutiques.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.marketplace, this.initialCategory});

  final MarketplaceApi marketplace;
  final String? initialCategory;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _categoryId = '';
  String _query = '';
  Timer? _debounce;

  late Future<SearchResults> _future;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategory ?? '';
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<SearchResults> _load() {
    final results = widget.marketplace.products(q: _query.isEmpty ? null : _query, categoryId: _categoryId.isEmpty ? null : _categoryId);
    return results.then((products) => SearchResults(products: products, vendors: const []));
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _query = value.trim();
        _future = _load();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.initialCategory == null,
          decoration: const InputDecoration(hintText: 'Rechercher un produit…', border: InputBorder.none),
          onChanged: _onChanged,
        ),
      ),
      body: FutureBuilder<SearchResults>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ListSkeleton();
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Recherche impossible.',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final results = snapshot.data!;
          if (results.products.isEmpty) {
            return EmptyState(
              icon: Icons.search_off,
              title: _query.isEmpty ? 'Recherchez sur Béninfood' : 'Aucun résultat pour “$_query”',
              subtitle: 'Essayez d’autres mots-clés.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: results.products.length,
            itemBuilder: (context, index) {
              final p = results.products[index];
              return ListTile(
                onTap: () => context.push('/client/product/${p.id}'),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 52, height: 52, child: AppNetworkImage(url: p.imageUrl)),
                ),
                title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${p.vendorName ?? ''} · ${formatAmount(p.price)}'),
              );
            },
          );
        },
      ),
    );
  }
}

class SearchResults {
  const SearchResults({required this.products, this.vendors = const []});

  final List<Product> products;
  final List<Vendor> vendors;

  bool get isEmpty => products.isEmpty && vendors.isEmpty;
}