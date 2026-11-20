import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/marketplace_api.dart';
import '../../core/errors/api_exception.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../models/geo_reference.dart';
import '../models/neighborhood.dart';

/// Lieu choisi : ville + quartier, éventuellement accompagnés de coordonnées
/// (position GPS ou centre du quartier) et de la référence officielle IGN.
class CityAreaSelection {
  const CityAreaSelection({
    this.city,
    this.area,
    this.latitude,
    this.longitude,
    this.geo,
  });

  final String? city;
  final String? area;
  final double? latitude;
  final double? longitude;

  /// Référentiel officiel (`/geo/*`) lorsque le choix vient de l'API geo.
  /// Reste `null` pour les anciens choix `GET /locations` ou GPS brut.
  final GeoReferenceSelection? geo;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get isGps => hasCoordinates && city == null;
}

/// Ouvre le sélecteur de lieu.
///
/// Le sélecteur utilise le référentiel hiérarchique `/geo/*` et retombe sur
/// `GET /locations` si celui-ci est indisponible. [includeGps] ajoute l'action
/// « Autour de moi ». Retourne `null` si l'utilisateur annule.
Future<CityAreaSelection?> showCityAreaPicker(
  BuildContext context, {
  required MarketplaceApi marketplace,
  String? initialCity,
  String? initialArea,
  bool includeGps = false,
}) {
  return showModalBottomSheet<CityAreaSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
    ),
    builder: (_) => _CityAreaPickerSheet(
      marketplace: marketplace,
      initialCity: initialCity,
      initialArea: initialArea,
      includeGps: includeGps,
    ),
  );
}

class _CityAreaPickerSheet extends StatefulWidget {
  const _CityAreaPickerSheet({
    required this.marketplace,
    required this.initialCity,
    required this.initialArea,
    required this.includeGps,
  });

  final MarketplaceApi marketplace;
  final String? initialCity;
  final String? initialArea;
  final bool includeGps;

  @override
  State<_CityAreaPickerSheet> createState() => _CityAreaPickerSheetState();
}

class _CityAreaPickerSheetState extends State<_CityAreaPickerSheet> {
  late Future<_PickerSource> _source;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _source = _loadSource();
  }

  Future<_PickerSource> _loadSource() async {
    try {
      final countries = await widget.marketplace.geoCountries();
      if (countries.isNotEmpty) {
        return _PickerSource(countries: countries);
      }
    } catch (_) {
      // Référentiel indisponible : repli sur l'ancien référentiel local.
    }

    try {
      final cities = await widget.marketplace.locations();
      return _PickerSource(cities: cities);
    } catch (error) {
      return _PickerSource(error: error);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _source = _loadSource();
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_failureMessage(result.failure)),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    // Le géocodage inverse officiel est tenté côté serveur : jamais de
    // localité inventée si le point est hors référentiel.
    GeoPlace? place;
    try {
      place = await widget.marketplace.geoReverse(
        geo.latitude,
        geo.longitude,
      );
    } catch (_) {
      // Les coordonnées brutes restent exploitables sans rattachement administratif.
    }
    if (!mounted) {
      return;
    }

    final path = place?.path ?? const [];
    final placeCountry = place?.components['country'];
    final countryCode = placeCountry == null
        ? null
        : (await _countryCode(placeCountry));
    if (!mounted) {
      return;
    }

    final isLocality = place?.isLocality == true;
    Navigator.of(context).pop(
      CityAreaSelection(
        city: isLocality && path.length > 1
            ? path[path.length - 2]
            : place?.name ?? geo.city,
        area: isLocality ? place?.name : geo.area,
        latitude: geo.latitude,
        longitude: geo.longitude,
        geo: place?.toSelection(countryCode, source: 'gps') ??
            GeoReferenceSelection(
              countryCode: countryCode,
              latitude: geo.latitude,
              longitude: geo.longitude,
              accuracyM: geo.accuracyM,
              source: 'gps',
              recordedAt: geo.recordedAt,
            ),
      ),
    );
  }

  Future<String?> _countryCode(String name) async {
    try {
      final countries = await widget.marketplace.geoCountries();
      for (final country in countries) {
        if (country.name.toLowerCase() == name.toLowerCase() ||
            (country.officialName ?? '').toLowerCase() == name.toLowerCase()) {
          return country.code;
        }
      }
    } catch (_) {
      // Code laissé vide : le serveur résout le pays depuis les coordonnées.
    }
    return null;
  }

  static String _failureMessage(LocationFailure? failure) => switch (failure) {
        LocationFailure.serviceDisabled =>
          'Localisation indisponible : activez le GPS de votre appareil.',
        LocationFailure.permissionDenied =>
          'Localisation refusée : autorisez l\'accès à votre position dans les réglages.',
        _ => 'Position introuvable pour le moment.',
      };

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Choisir un lieu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            if (widget.includeGps)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(context.tr('Autour de moi')),
                    onPressed: _locating ? null : _useMyPosition,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<_PickerSource>(
                future: _source,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final source = snapshot.data;
                  if (source == null || source.error != null) {
                    return _EmptyPicker(
                      message: 'Impossible de charger les lieux.',
                      onRetry: _retry,
                    );
                  }
                  if (source.countries.isNotEmpty) {
                    return _GeoHierarchyPicker(
                      countries: source.countries,
                      initialCity: widget.initialCity,
                      initialArea: widget.initialArea,
                      marketplace: widget.marketplace,
                      onSelected: (selection) =>
                          Navigator.of(context).pop(selection),
                    );
                  }
                  if (source.cities.isEmpty) {
                    return const _EmptyPicker(
                      message: 'Aucun lieu disponible pour le moment.',
                    );
                  }
                  return _LegacyPicker(
                    cities: source.cities,
                    initialCity: widget.initialCity,
                    initialArea: widget.initialArea,
                    onSelected: (selection) =>
                        Navigator.of(context).pop(selection),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerSource {
  const _PickerSource({this.countries = const [], this.cities = const [], this.error});

  final List<GeoCountry> countries;
  final List<LocationCity> cities;
  final Object? error;
}

class _EmptyPicker extends StatelessWidget {
  const _EmptyPicker({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr(message), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(context.tr('Réessayer')),
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sélecteur hiérarchique pays → niveaux administratifs → localité.
///
/// Chaque niveau est recherchable et paginé côté serveur. Les résultats sont
/// mis en cache dans la session du sélecteur pour éviter les allers-retours
/// lorsqu'on remonte d'un niveau.
class _GeoHierarchyPicker extends StatefulWidget {
  const _GeoHierarchyPicker({
    required this.countries,
    required this.initialCity,
    required this.initialArea,
    required this.marketplace,
    required this.onSelected,
  });

  final List<GeoCountry> countries;
  final String? initialCity;
  final String? initialArea;
  final MarketplaceApi marketplace;
  final ValueChanged<CityAreaSelection> onSelected;

  @override
  State<_GeoHierarchyPicker> createState() => _GeoHierarchyPickerState();
}

class _GeoHierarchyPickerState extends State<_GeoHierarchyPicker> {
  late GeoCountry _country;
  late final List<TextEditingController> _levelSearchControllers;
  final _globalSearch = TextEditingController();
  final _localitySearch = TextEditingController();
  Timer? _searchDebounce;

  final List<GeoDivision?> _selectedDivisions = [];
  final List<List<GeoDivision>> _divisionItems = [];
  final List<GeoPageMeta> _divisionMeta = [];
  final List<int> _divisionPage = [];
  final List<String> _divisionQuery = [];
  final List<bool> _divisionSearchOpen = [];
  final List<Future<List<GeoDivision>>?> _divisionFutures = [];
  final Map<String, Future<GeoPage<GeoDivision>>> _divisionCache = {};

  GeoLocality? _locality;
  List<GeoLocality> _localityItems = [];
  GeoPageMeta _localityMeta = const GeoPageMeta();
  int _localityPage = 1;
  bool _localitySearchOpen = false;
  Future<List<GeoLocality>>? _localityFuture;
  final Map<String, Future<GeoPage<GeoLocality>>> _localityCache = {};

  List<GeoPlace> _searchResults = const [];
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _country = _initialCountry();
    _levelSearchControllers = List.generate(
      _country.hierarchy.length,
      (_) => TextEditingController(),
    );
    _globalSearch.text = widget.initialArea ?? widget.initialCity ?? '';
    _resetHierarchy();
  }

  GeoCountry _initialCountry() {
    final hint = '${widget.initialCity ?? ''} ${widget.initialArea ?? ''}'.toLowerCase();
    for (final country in widget.countries) {
      if (hint.contains(country.name.toLowerCase())) {
        return country;
      }
    }
    for (final country in widget.countries) {
      if (country.code == 'BJ') {
        return country;
      }
    }
    return widget.countries.first;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _globalSearch.dispose();
    _localitySearch.dispose();
    for (final controller in _levelSearchControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  GeoDivision? get _deepestDivision {
    for (var index = _selectedDivisions.length - 1; index >= 0; index--) {
      final division = _selectedDivisions[index];
      if (division != null) {
        return division;
      }
    }
    return null;
  }

  bool get _localitiesReady =>
      _country.hierarchy.isEmpty ||
      (_selectedDivisions.isNotEmpty && _selectedDivisions.last != null);

  void _resetHierarchy() {
    final levels = _country.hierarchy.length;
    _selectedDivisions
      ..clear()
      ..addAll(List<GeoDivision?>.filled(levels, null));
    _divisionItems
      ..clear()
      ..addAll(List.generate(levels, (_) => <GeoDivision>[]));
    _divisionMeta
      ..clear()
      ..addAll(List.generate(levels, (_) => const GeoPageMeta()));
    _divisionPage
      ..clear()
      ..addAll(List<int>.filled(levels, 1));
    _divisionQuery
      ..clear()
      ..addAll(List<String>.filled(levels, ''));
    _divisionSearchOpen
      ..clear()
      ..addAll(List<bool>.filled(levels, false));
    _divisionFutures
      ..clear()
      ..addAll(List<Future<List<GeoDivision>>?>.filled(levels, null));
    for (final controller in _levelSearchControllers) {
      controller.clear();
    }
    _locality = null;
    _localityItems = const [];
    _localityMeta = const GeoPageMeta();
    _localityPage = 1;
    _localitySearch.clear();
    _searchResults = const [];
    _searchError = null;

    for (var index = 0; index < levels; index++) {
      _divisionFutures[index] = _loadDivisions(index);
    }
    _localityFuture = _localitiesReady ? _loadLocalities() : null;
  }

  Future<List<GeoDivision>> _loadDivisions(int index) async {
    final parentId = index == 0 ? null : _selectedDivisions[index - 1]?.id;
    if (index > 0 && parentId == null) {
      return const [];
    }

    final level = _country.hierarchy[index];
    final query = _divisionQuery[index];
    final page = _divisionPage[index];
    final key = '${_country.code}|${level.slug}|$parentId|$query|$page';
    final cached = _divisionCache.putIfAbsent(
      key,
      () => widget.marketplace.geoDivisions(
        country: _country.code,
        level: level.slug,
        parentId: parentId,
        q: query.isEmpty ? null : query,
        page: page,
      ),
    );

    try {
      final result = await cached;
      if (!mounted || index >= _divisionItems.length) {
        return const [];
      }
      if (page == 1) {
        _divisionItems[index] = result.items;
      } else {
        _divisionItems[index] = [..._divisionItems[index], ...result.items];
      }
      _divisionMeta[index] = result.meta;
      return List.unmodifiable(_divisionItems[index]);
    } catch (error) {
      _divisionCache.remove(key);
      rethrow;
    }
  }

  Future<List<GeoLocality>> _loadLocalities() async {
    final divisionId = _deepestDivision?.id;
    final query = _localitySearch.text.trim();
    final page = _localityPage;
    final key = '${_country.code}|$divisionId|$query|$page';
    final cached = _localityCache.putIfAbsent(
      key,
      () => widget.marketplace.geoLocalities(
        country: _country.code,
        divisionId: divisionId,
        q: query.isEmpty ? null : query,
        page: page,
      ),
    );

    try {
      final result = await cached;
      if (!mounted) {
        return const [];
      }
      if (page == 1) {
        _localityItems = result.items;
      } else {
        _localityItems = [..._localityItems, ...result.items];
      }
      _localityMeta = result.meta;
      return List.unmodifiable(_localityItems);
    } catch (error) {
      _localityCache.remove(key);
      rethrow;
    }
  }

  void _changeCountry(GeoCountry? country) {
    if (country == null || country.code == _country.code) {
      return;
    }
    setState(() {
      _country = country;
      for (var index = 0; index < _levelSearchControllers.length; index++) {
        _levelSearchControllers[index].clear();
      }
      _globalSearch.clear();
      _searchResults = const [];
      _resetHierarchy();
    });
  }

  void _selectDivision(int index, GeoDivision division) {
    setState(() {
      _selectedDivisions[index] = division;
      for (var lower = index + 1; lower < _selectedDivisions.length; lower++) {
        _selectedDivisions[lower] = null;
        _divisionItems[lower] = const [];
        _divisionPage[lower] = 1;
        _divisionQuery[lower] = '';
        _divisionSearchOpen[lower] = false;
        _levelSearchControllers[lower].clear();
        _divisionFutures[lower] = null;
      }
      _locality = null;
      _localityItems = const [];
      _localityPage = 1;
      _localitySearch.clear();

      for (var lower = index + 1; lower < _selectedDivisions.length; lower++) {
        _divisionFutures[lower] = _loadDivisions(lower);
      }
      _localityFuture = _localitiesReady ? _loadLocalities() : null;
    });
  }

  void _applyDivisionQuery(int index, String value) {
    final query = value.trim();
    if (query == _divisionQuery[index]) {
      return;
    }
    setState(() {
      _divisionQuery[index] = query;
      _divisionPage[index] = 1;
      _divisionItems[index] = const [];
      _divisionFutures[index] = _loadDivisions(index);
      for (var lower = index + 1; lower < _selectedDivisions.length; lower++) {
        _selectedDivisions[lower] = null;
        _divisionItems[lower] = const [];
        _divisionFutures[lower] = null;
      }
      _locality = null;
      _localityItems = const [];
      _localityFuture = _localitiesReady ? _loadLocalities() : null;
    });
  }

  void _applyLocalityQuery(String value) {
    final query = value.trim();
    if (query == _localitySearch.text.trim()) {
      return;
    }
    setState(() {
      _localitySearch.text = query;
      _localityPage = 1;
      _localityItems = const [];
      _locality = null;
      _localityFuture = _loadLocalities();
    });
  }

  void _nextDivisionPage(int index) {
    setState(() {
      _divisionPage[index]++;
      _divisionFutures[index] = _loadDivisions(index);
    });
  }

  void _nextLocalityPage() {
    setState(() {
      _localityPage++;
      _localityFuture = _loadLocalities();
    });
  }

  void _onGlobalSearchChanged(String value) {
    _searchDebounce?.cancel();
    final term = value.trim();
    if (term.length < 2) {
      setState(() {
        _searchResults = const [];
        _searchError = null;
        _searching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _runGlobalSearch(term);
    });
  }

  Future<void> _runGlobalSearch(String term) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await widget.marketplace.geoSearch(
        term,
        country: _country.code,
        divisionId: _deepestDivision?.id,
        limit: 20,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = const [];
        _searching = false;
        _searchError = error is ApiException
            ? error.message
            : 'Recherche indisponible pour le moment.';
      });
    }
  }

  CityAreaSelection _hierarchySelection({GeoLocality? locality}) {
    final division = _deepestDivision;
    final chosenLocality = locality;
    final label = chosenLocality != null ? division?.name : division?.name;
    final latitude = chosenLocality?.latitude ?? division?.latitude;
    final longitude = chosenLocality?.longitude ?? division?.longitude;

    return CityAreaSelection(
      city: label ?? _country.name,
      area: chosenLocality?.name,
      latitude: latitude,
      longitude: longitude,
      geo: GeoReferenceSelection(
        countryCode: _country.code,
        divisionId: chosenLocality?.divisionId ?? division?.id,
        localityId: chosenLocality?.id,
        latitude: latitude,
        longitude: longitude,
        source: 'manual',
      ),
    );
  }

  void _selectPlace(GeoPlace place) {
    final path = place.path;
    final selection = place.toSelection(_country.code, source: 'geocoded');
    widget.onSelected(
      CityAreaSelection(
        city: place.isLocality && path.length > 1
            ? path[path.length - 2]
            : place.name,
        area: place.isLocality ? place.name : null,
        latitude: place.latitude,
        longitude: place.longitude,
        geo: selection,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              const Icon(Icons.public, size: 20, color: AppColors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<GeoCountry>(
                  value: _country,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: widget.countries
                      .map(
                        (country) => DropdownMenuItem<GeoCountry>(
                          value: country,
                          child: Text(country.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _changeCountry,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            controller: _globalSearch,
            onChanged: _onGlobalSearchChanged,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search, size: 20),
              hintText: context.tr('Rechercher un lieu officiel…'),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _searchError!,
              style: const TextStyle(color: AppColors.red, fontSize: 12),
            ),
          ),
        if (_searchResults.isNotEmpty)
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _searchResults.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final place = _searchResults[index];
                return SizedBox(
                  width: 220,
                  child: Card(
                    child: ListTile(
                      title: Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        place.display,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => _selectPlace(place),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: Text('Tout ${_country.name}'),
                onTap: () => widget.onSelected(
                  CityAreaSelection(
                    city: _country.name,
                    geo: GeoReferenceSelection(countryCode: _country.code),
                  ),
                ),
              ),
              for (var index = 0; index < _country.hierarchy.length; index++)
                _divisionLevel(index, _country.hierarchy[index]),
              if (_localitiesReady) _localitySection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divisionLevel(int index, GeoLevel level) {
    final selected = _selectedDivisions[index];
    final title = level.plural ?? level.label;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    selected == null ? title : '${level.label} : ${selected.name}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  tooltip: context.tr('Rechercher'),
                  onPressed: () => setState(() {
                    _divisionSearchOpen[index] = !_divisionSearchOpen[index];
                  }),
                ),
              ],
            ),
            if (_divisionSearchOpen[index] == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _levelSearchControllers[index],
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _applyDivisionQuery(index, value),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '${context.tr('Rechercher')} ${title.toLowerCase()}…',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            FutureBuilder<List<GeoDivision>>(
              future: _divisionFutures[index],
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _InlineError(
                    onRetry: () => setState(() {
                      _divisionFutures[index] = _loadDivisions(index);
                    }),
                  );
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(context.tr('Aucun résultat.')),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final division in items)
                          ChoiceChip(
                            label: Text(division.name),
                            selected: division.id == selected?.id,
                            onSelected: (_) => _selectDivision(index, division),
                          ),
                      ],
                    ),
                    if (_divisionMeta[index].hasMore)
                      TextButton.icon(
                        icon: const Icon(Icons.expand_more, size: 18),
                        label: Text(context.tr('Afficher plus')),
                        onPressed: () => _nextDivisionPage(index),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _localitySection() {
    final division = _deepestDivision;
    final label = _country.localityLabel ?? 'Village / quartier';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _locality == null ? label : '$label : ${_locality!.name}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  tooltip: context.tr('Rechercher'),
                  onPressed: () => setState(() {
                    _localitySearchOpen = !_localitySearchOpen;
                  }),
                ),
              ],
            ),
            if (_localitySearchOpen)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _localitySearch,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _applyLocalityQuery,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '${context.tr('Rechercher')} ${label.toLowerCase()}…',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(
                division == null
                    ? 'Sans localité précise'
                    : 'Sarrêter à ${division.name}',
              ),
              onTap: () => widget.onSelected(_hierarchySelection()),
            ),
            FutureBuilder<List<GeoLocality>>(
              future: _localityFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _InlineError(
                    onRetry: () => setState(() {
                      _localityFuture = _loadLocalities();
                    }),
                  );
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(context.tr('Aucune localité référencée.')),
                  );
                }
                return Column(
                  children: [
                    for (final locality in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.place_outlined, size: 20),
                        title: Text(locality.display),
                        subtitle: locality.kind == null
                            ? null
                            : Text(locality.kind!, style: const TextStyle(fontSize: 11)),
                        selected: locality.id == _locality?.id,
                        onTap: () {
                          setState(() => _locality = locality);
                          widget.onSelected(_hierarchySelection(locality: locality));
                        },
                      ),
                    if (_localityMeta.hasMore)
                      TextButton.icon(
                        icon: const Icon(Icons.expand_more, size: 18),
                        label: Text(context.tr('Afficher plus')),
                        onPressed: _nextLocalityPage,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr('Chargement impossible.'),
              style: const TextStyle(color: AppColors.red, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(context.tr('Réessayer'))),
        ],
      ),
    );
  }
}

/// Ancien sélecteur `GET /locations`, conservé en repli.
class _LegacyPicker extends StatefulWidget {
  const _LegacyPicker({
    required this.cities,
    required this.initialCity,
    required this.initialArea,
    required this.onSelected,
  });

  final List<LocationCity> cities;
  final String? initialCity;
  final String? initialArea;
  final ValueChanged<CityAreaSelection> onSelected;

  @override
  State<_LegacyPicker> createState() => _LegacyPickerState();
}

class _LegacyPickerState extends State<_LegacyPicker> {
  final _search = TextEditingController();
  String? _city;

  @override
  void initState() {
    super.initState();
    _city = widget.initialCity;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCity() ?? widget.cities.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.cities.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final city = widget.cities[index];
              return ChoiceChip(
                label: Text(city.city),
                selected: city.city == selected.city,
                onSelected: (_) => setState(() => _city = city.city),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 20),
              hintText: 'Rechercher un quartier…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _neighborhoodList(selected)),
      ],
    );
  }

  Widget _neighborhoodList(LocationCity city) {
    final filter = _search.text.trim().toLowerCase();
    final neighborhoods = filter.isEmpty
        ? city.neighborhoods
        : city.neighborhoods
            .where((n) => n.name.toLowerCase().contains(filter))
            .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ListTile(
          leading: const Icon(Icons.map_outlined, color: AppColors.textSecondary),
          title: Text('Toute la ville de ${city.city}'),
          onTap: () => widget.onSelected(CityAreaSelection(city: city.city)),
        ),
        const Divider(height: 1),
        if (neighborhoods.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(context.tr('Aucun quartier ne correspond.')),
          ),
        for (final neighborhood in neighborhoods)
          ListTile(
            leading: const Icon(Icons.place_outlined, size: 20),
            title: Text(neighborhood.name),
            selected: neighborhood.name == widget.initialArea,
            onTap: () => widget.onSelected(
              CityAreaSelection(
                city: city.city,
                area: neighborhood.name,
                latitude: neighborhood.latitude,
                longitude: neighborhood.longitude,
              ),
            ),
          ),
      ],
    );
  }

  LocationCity? _selectedCity() {
    for (final city in widget.cities) {
      if (city.city == _city) {
        return city;
      }
    }
    return null;
  }
}

/// Champ de formulaire (tap) affichant la ville et le quartier sélectionnés.
///
/// Écrit la sélection dans [cityController] et [areaController] afin de
/// s'intégrer aux formulaires existants. [onChanged] reçoit désormais la
/// référence officielle lorsque le sélecteur a pu la résoudre.
class CityAreaPickerField extends StatelessWidget {
  const CityAreaPickerField({
    super.key,
    required this.marketplace,
    required this.cityController,
    required this.areaController,
    this.label = 'Ville et quartier',
    this.icon = Icons.location_city_outlined,
    this.enabled = true,
    this.includeGps = false,
    this.onChanged,
  });

  final MarketplaceApi marketplace;
  final TextEditingController cityController;
  final TextEditingController areaController;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool includeGps;

  final ValueChanged<CityAreaSelection>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([cityController, areaController]),
      builder: (context, _) {
        final city = cityController.text.trim();
        final area = areaController.text.trim();
        final value = [area, city].where((p) => p.isNotEmpty).join(' · ');
        final hasValue = value.isNotEmpty;

        return InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          onTap: enabled
              ? () async {
                  final selection = await showCityAreaPicker(
                    context,
                    marketplace: marketplace,
                    initialCity: city.isEmpty ? null : city,
                    initialArea: area.isEmpty ? null : area,
                    includeGps: includeGps,
                  );
                  if (selection == null) {
                    return;
                  }
                  cityController.text = selection.city ?? '';
                  areaController.text = selection.area ?? '';
                  onChanged?.call(selection);
                }
              : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, size: 20),
              suffixIcon: const Icon(Icons.expand_more, size: 20),
              border: const OutlineInputBorder(),
            ),
            child: Text(
              hasValue ? value : context.tr('Choisir un quartier…'),
              style: TextStyle(
                color: hasValue ? AppColors.text : AppColors.textFaint,
              ),
            ),
          ),
        );
      },
    );
  }
}
