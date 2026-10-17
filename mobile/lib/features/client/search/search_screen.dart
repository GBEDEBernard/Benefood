import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/vendor.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/city_area_picker.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/product_cards.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/vendor_cards.dart';

/// Onglets de recherche client.
enum _SearchTab {
  all('Tout', null),
  products('Plats', null),
  restaurants('Restaurants', VendorType.restaurant),
  boutiques('Boutiques', VendorType.boutique),
  maquis('Maquis', VendorType.maquis);

  const _SearchTab(this.label, this.vendorType);

  final String label;
  final VendorType? vendorType;

  bool get isProducts => this == _SearchTab.products;
  bool get needsVendors =>
      this == _SearchTab.all ||
      this == _SearchTab.restaurants ||
      this == _SearchTab.boutiques ||
      this == _SearchTab.maquis;
  bool get needsProducts => this == _SearchTab.all || this == _SearchTab.products;
}

/// Rayons de recherche « par km » proposés.
const List<double> _radiusOptions = [1, 2, 5, 10, 20, 50];

String _radiusLabel(double km) => '${km.toStringAsFixed(0)} km';

/// Recherche & exploration client (J149) : plats + boutiques, avec filtre par
/// ville/quartier et par distance (GPS ou centre du quartier).
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.marketplace,
    this.initialCategory,
  });

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

  _SearchTab _tab = _SearchTab.all;

  // Localisation et proximité.
  String? _city;
  String? _area;
  double? _latitude;
  double? _longitude;
  double _radiusKm = 10;
  bool _byDistance = false;
  bool _locating = false;

  late Future<SearchResults> _future;

  bool get _hasCoords => _latitude != null && _longitude != null;

  bool get _hasLocation =>
      _hasCoords ||
      (_city != null && _city!.isNotEmpty) ||
      (_area != null && _area!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategory ?? '';
    if (widget.initialCategory != null) {
      _tab = _SearchTab.products;
    }
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<SearchResults> _load() {
    final q = _query.isEmpty ? null : _query;
    final useDistance = _hasCoords;
    final sort = useDistance && _byDistance ? 'distance' : null;

    final vendorsNeeded = _tab.needsVendors;
    final productsNeeded = _tab.needsProducts;

    final vendorFuture = vendorsNeeded
        ? widget.marketplace.vendors(
            q: q,
            city: _city,
            area: _area,
            type: _tab == _SearchTab.all ? null : _tab.vendorType,
            latitude: useDistance ? _latitude : null,
            longitude: useDistance ? _longitude : null,
            radiusKm: useDistance ? _radiusKm : null,
            sort: sort,
            perPage: 50,
          )
        : Future.value(const <Vendor>[]);

    final productFuture = productsNeeded
        ? widget.marketplace.products(
            q: q,
            categoryId: _categoryId.isEmpty ? null : _categoryId,
            city: _city,
            area: _area,
            latitude: useDistance ? _latitude : null,
            longitude: useDistance ? _longitude : null,
            radiusKm: useDistance ? _radiusKm : null,
            sort: sort,
            perPage: 50,
          )
        : Future.value(const <Product>[]);

    return Future.wait<Object?>([vendorFuture, productFuture]).then((r) {
      final vendors = r[0] as List<Vendor>;
      final products = r[1] as List<Product>;
      return SearchResults(products: products, vendors: vendors);
    });
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _onChanged(String value) {
    setState(() {}); // Rafraîchit l'affichage du bouton d'effacement.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      _query = value.trim();
      _reload();
    });
  }

  Future<void> _pickLocation() async {
    final selection = await showCityAreaPicker(
      context,
      marketplace: widget.marketplace,
      initialCity: _city,
      initialArea: _area,
      includeGps: true,
    );
    if (selection == null || !mounted) {
      return;
    }
    setState(() {
      _city = selection.city;
      _area = selection.area;
      _latitude = selection.latitude;
      _longitude = selection.longitude;
      if (selection.latitude != null) {
        _byDistance = true;
      }
    });
    _reload();
  }

  Future<void> _useMyPosition() async {
    setState(() => _locating = true);
    final result = await LocationService.locate();
    if (!mounted) {
      return;
    }
    setState(() => _locating = false);
    final geo = result.geo;
    if (geo == null) {
      showToast(
        context,
        _locationFailureMessage(result.failure),
        isError: true,
      );
      return;
    }
    setState(() {
      _city = geo.city;
      _area = geo.area;
      _latitude = geo.latitude;
      _longitude = geo.longitude;
      _byDistance = true;
    });
    _reload();
  }

  static String _locationFailureMessage(LocationFailure? failure) =>
      switch (failure) {
        LocationFailure.serviceDisabled =>
          'Localisation indisponible : activez le GPS de votre appareil.',
        LocationFailure.permissionDenied =>
          'Localisation refusée : autorisez l\'accès à votre position dans les réglages.',
        _ => 'Position introuvable pour le moment.',
      };

  void _clearLocation() {
    setState(() {
      _city = null;
      _area = null;
      _latitude = null;
      _longitude = null;
      _byDistance = false;
    });
    _reload();
  }

  String get _locationLabel {
    final parts = [_area, _city].whereType<String>().where((p) => p.isNotEmpty);
    final place = parts.join(' · ');
    if (_hasCoords) {
      return place.isEmpty ? 'Autour de moi' : place;
    }
    if (place.isNotEmpty) {
      return place;
    }
    return 'Ville ou quartier…';
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
      body: Column(
        children: [
          BeninfoodAppBar(
            onMenu: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/client');
              }
            },
            api: widget.marketplace,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              4,
              AppDimens.pagePadding,
              8,
            ),
            child: AppSearchField(
              controller: _controller,
              autofocus: widget.initialCategory == null,
              hintText: 'Rechercher un plat, un restaurant, une boutique…',
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
          _buildTabs(),
          _buildLocationBar(),
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
                    onRetry: () {
                      final next = _load();
                      setState(() {
                        _future = next;
                      });
                    },
                  );
                }
                final results = snapshot.data!;
                if (results.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: _query.isEmpty
                        ? 'Recherchez sur Béninfood'
                        : 'Aucun résultat pour “$_query”',
                    subtitle: 'Essayez d’autres mots-clés ou élargissez la zone.',
                  );
                }
                return _buildResults(context, results);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
        itemCount: _SearchTab.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = _SearchTab.values[index];
          final selected = tab == _tab;
          return ChoiceChip(
            label: Text(tab.label),
            selected: selected,
            onSelected: (_) => setState(() {
              _tab = tab;
              _future = _load();
            }),
          );
        },
      ),
    );
  }

  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        8,
        AppDimens.pagePadding,
        4,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  onTap: _pickLocation,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                      suffixIcon: Icon(Icons.expand_more, size: 18),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      _locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: _hasLocation
                            ? AppColors.text
                            : AppColors.textFaint,
                        fontWeight: _hasLocation
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _roundIconBtn(
                icon: Icons.my_location,
                active: _hasCoords,
                loading: _locating,
                onTap: _locating ? null : _useMyPosition,
              ),
              if (_hasLocation) ...[
                const SizedBox(width: 6),
                _roundIconBtn(
                  icon: Icons.close,
                  onTap: _clearLocation,
                ),
              ],
            ],
          ),
          if (_hasCoords) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Rayon',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _radiusOptions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final km = _radiusOptions[index];
                        final selected = km == _radiusKm;
                        return ChoiceChip(
                          label: Text(
                            _radiusLabel(km),
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          selected: selected,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => setState(() {
                            _radiusKm = km;
                            _future = _load();
                          }),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _sortChip(
                  label: 'Pertinence',
                  selected: !_byDistance,
                  onTap: () => setState(() => _byDistance = false),
                ),
                const SizedBox(width: 6),
                _sortChip(
                  label: 'Proximité',
                  selected: _byDistance,
                  onTap: () => setState(() => _byDistance = true),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sortChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _roundIconBtn({
    required IconData icon,
    required VoidCallback? onTap,
    bool active = false,
    bool loading = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.orangeLight : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                icon,
                size: 18,
                color: active ? AppColors.orange : AppColors.textSecondary,
              ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, SearchResults results) {
    final showVendors = _tab != _SearchTab.products && results.vendors.isNotEmpty;
    final showProducts =
        _tab != _SearchTab.restaurants &&
        _tab != _SearchTab.boutiques &&
        _tab != _SearchTab.maquis &&
        results.products.isNotEmpty;

    final children = <Widget>[];

    if (showVendors) {
      children.add(
        _sectionHeader(_tab.vendorType?.label ?? 'Boutiques près de vous'),
      );
      for (final vendor in results.vendors) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VendorListCard(
              vendor: vendor,
              onTap: () => context.push('/client/shop/${vendor.id}'),
            ),
          ),
        );
      }
    }

    if (showProducts) {
      children.add(const _ResultsHeader(title: 'Plats et produits'));
      for (final product in results.products) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ProductListCard(
              product: product,
              onTap: () => context.push('/client/product/${product.id}'),
              onAdd: () => _addToCart(product),
            ),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        4,
        AppDimens.pagePadding,
        32,
      ),
      children: children,
    );
  }

  Widget _sectionHeader(String title) => _ResultsHeader(title: title);
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10, left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
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
