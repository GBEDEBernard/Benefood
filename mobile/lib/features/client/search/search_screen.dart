import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/vendor.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/product_cards.dart';
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
    return widget.marketplace
        .products(q: _query.isEmpty ? null : _query, categoryId: _categoryId.isEmpty ? null : _categoryId)
        .then((products) => SearchResults(products: products, vendors: const []));
  }

  void _onChanged(String value) {
    setState(() {}); // Rafraîchit l'affichage du bouton d'effacement.
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
      appBar: AppBar(title: const Text('Rechercher')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, 4, AppDimens.pagePadding, 12),
            child: AppSearchField(
              controller: _controller,
              autofocus: widget.initialCategory == null,
              hintText: 'Rechercher un produit…',
              onChanged: _onChanged,
              suffix: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
            ),
          ),
          Expanded(
            child: FutureBuilder<SearchResults>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const ListSkeleton();
                }
                if (snapshot.hasError) {
                  return ErrorState(
                    message: snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : 'Recherche impossible.',
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
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppDimens.pagePadding, 4, AppDimens.pagePadding, 32),
                  itemCount: results.products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = results.products[index];
                    return ProductListCard(
                      product: p,
                      onTap: () => context.push('/client/product/${p.id}'),
                      onAdd: () => _addToCart(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
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