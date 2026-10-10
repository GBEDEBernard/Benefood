import 'package:flutter/material.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../restaurant_palette.dart';

/// Zone desservie sélectionnable.
class _ZoneOption {
  const _ZoneOption({required this.id, required this.name, required this.city});

  final String id;
  final String name;
  final String? city;

  String get label => city == null || city!.trim().isEmpty ? name : '$name · $city';
}

/// Édition des zones de livraison desservies par la boutique (J21 §3.2).
class ShopZonesEditScreen extends StatefulWidget {
  const ShopZonesEditScreen({super.key, this.marketplace});

  final MarketplaceApi? marketplace;

  @override
  State<ShopZonesEditScreen> createState() => _ShopZonesEditScreenState();
}

class _ShopZonesEditScreenState extends State<ShopZonesEditScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<_ZoneOption> _options = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = widget.marketplace;
    if (api == null) {
      setState(() {
        _options = const [
          _ZoneOption(id: 'z1', name: 'Cadjèhoun', city: 'Cotonou'),
          _ZoneOption(id: 'z2', name: 'Akpakpa', city: 'Cotonou'),
          _ZoneOption(id: 'z3', name: 'Fidjrossè', city: 'Cotonou'),
        ];
        _selected.add('z1');
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final zones = await api.deliveryZones();
      final mine = await api.vendorZones();
      if (!mounted) return;
      setState(() {
        _options = zones
            .map((z) => _ZoneOption(
                  id: '${z['id']}',
                  name: '${z['name'] ?? ''}',
                  city: z['city'] as String?,
                ))
            .toList();
        _selected
          ..clear()
          ..addAll(mine.map((z) => '${z['id']}'));
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final api = widget.marketplace;
    if (api == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _saving = true);
    try {
      await api.syncVendorZones(_selected.toList());
      if (!mounted) return;
      showToast(context, 'Zones desservies mises à jour.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RestaurantPalette.background,
      appBar: AppBar(
        backgroundColor: RestaurantPalette.white,
        foregroundColor: RestaurantPalette.darkText,
        title: const Text(
          'Zones desservies',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _options.isEmpty || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: RestaurantPalette.orange,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_options.isEmpty) {
      return const Center(
        child: Text(
          'Aucune zone de livraison disponible.',
          style: TextStyle(color: RestaurantPalette.grayText),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Sélectionnez les zones où votre boutique livre ses commandes.',
          style: TextStyle(color: RestaurantPalette.grayText, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: RestaurantPalette.cardDecoration,
          child: Column(
            children: [
              for (var i = 0; i < _options.length; i++) ...[
                CheckboxListTile(
                  value: _selected.contains(_options[i].id),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selected.add(_options[i].id);
                    } else {
                      _selected.remove(_options[i].id);
                    }
                  }),
                  activeColor: RestaurantPalette.orange,
                  title: Text(
                    _options[i].label,
                    style: const TextStyle(
                      color: RestaurantPalette.darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (i != _options.length - 1)
                  const Divider(height: 1, indent: 16, color: RestaurantPalette.borderColor),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
