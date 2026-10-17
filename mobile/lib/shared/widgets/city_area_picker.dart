import 'package:flutter/material.dart';

import '../../core/data/marketplace_api.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../models/neighborhood.dart';

/// Lieu choisi : ville + quartier, éventuellement accompagnés de coordonnées
/// (position GPS ou centre du quartier).
class CityAreaSelection {
  const CityAreaSelection({
    this.city,
    this.area,
    this.latitude,
    this.longitude,
  });

  final String? city;
  final String? area;
  final double? latitude;
  final double? longitude;

  bool get isGps => latitude != null && longitude != null && city == null;
}

/// Ouvre le sélecteur ville/quartier (référentiel GET /locations).
///
/// [includeGps] ajoute l'action « Autour de moi » qui renvoie la position de
/// l'appareil. Retourne `null` si l'utilisateur annule.
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
  late Future<List<LocationCity>> _future;
  final _search = TextEditingController();
  String? _city;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _city = widget.initialCity;
    _future = widget.marketplace.locations();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
    Navigator.of(context).pop(
      CityAreaSelection(
        city: geo.city,
        area: geo.area,
        latitude: geo.latitude,
        longitude: geo.longitude,
      ),
    );
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
                    label: const Text('Autour de moi'),
                    onPressed: _locating ? null : _useMyPosition,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<LocationCity>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final cities = snapshot.data ?? const [];
                  if (cities.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Aucun lieu disponible pour le moment.'),
                      ),
                    );
                  }

                  final selected = _selectedCity(cities) ?? cities.first;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (snapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            snapshot.error is ApiException
                                ? (snapshot.error as ApiException).message
                                : 'Impossible de charger les lieux.',
                            style: const TextStyle(color: AppColors.red),
                          ),
                        ),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: cities.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final city = cities[index];
                            final isSelected = city.city == selected.city;
                            return ChoiceChip(
                              label: Text(city.city),
                              selected: isSelected,
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
                      Expanded(
                        child: _neighborhoodList(selected),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
          onTap: () => Navigator.of(context).pop(
            CityAreaSelection(city: city.city),
          ),
        ),
        const Divider(height: 1),
        if (neighborhoods.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Aucun quartier ne correspond.'),
          ),
        for (final neighborhood in neighborhoods)
          ListTile(
            leading: const Icon(Icons.place_outlined, size: 20),
            title: Text(neighborhood.name),
            selected: neighborhood.name == widget.initialArea,
            onTap: () => Navigator.of(context).pop(
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

  LocationCity? _selectedCity(List<LocationCity> cities) {
    for (final city in cities) {
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
/// s'intégrer aux formulaires existants.
class CityAreaPickerField extends StatelessWidget {
  const CityAreaPickerField({
    super.key,
    required this.marketplace,
    required this.cityController,
    required this.areaController,
    this.label = 'Ville et quartier',
    this.icon = Icons.location_city_outlined,
  });

  final MarketplaceApi marketplace;
  final TextEditingController cityController;
  final TextEditingController areaController;
  final String label;
  final IconData icon;

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
          onTap: () async {
            final selection = await showCityAreaPicker(
              context,
              marketplace: marketplace,
              initialCity: city.isEmpty ? null : city,
              initialArea: area.isEmpty ? null : area,
            );
            if (selection == null) {
              return;
            }
            cityController.text = selection.city ?? '';
            areaController.text = selection.area ?? '';
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, size: 20),
              suffixIcon: const Icon(Icons.expand_more, size: 20),
              border: const OutlineInputBorder(),
            ),
            child: Text(
              hasValue ? value : 'Choisir un quartier…',
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
