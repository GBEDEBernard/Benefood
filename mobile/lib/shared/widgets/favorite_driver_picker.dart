import 'package:flutter/material.dart';

import '../../core/data/marketplace_api.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../models/favorite_driver.dart';
import 'state_widgets.dart';

/// Choix renvoyé par [showFavoriteDriverPicker] :
/// - `driverId == null` → « aucun » (offre laissée ouverte) ;
/// - `driverId` renseigné → le livreur favori choisi.
class FavoriteDriverChoice {
  const FavoriteDriverChoice({this.driverId, this.driver});

  const FavoriteDriverChoice.none()
      : driverId = null,
        driver = null;

  final String? driverId;
  final DriverSummary? driver;

  bool get isNone => driverId == null;

  String get label => driver?.displayName ?? 'Aucun livreur';
}

/// Ouvre un sélecteur de livreur favori (accepté) et renvoie :
/// - `null` si le sélecteur est fermé sans choix ;
/// - une [FavoriteDriverChoice] (éventuellement « aucun »), sinon.
Future<FavoriteDriverChoice?> showFavoriteDriverPicker(
  BuildContext context,
  MarketplaceApi marketplace, {
  String title = 'Choisir un livreur',
  bool allowNone = true,
  String? selectedId,
}) {
  return showModalBottomSheet<FavoriteDriverChoice>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _FavoriteDriverPickerSheet(
      marketplace: marketplace,
      title: title,
      allowNone: allowNone,
      selectedId: selectedId,
    ),
  );
}

class _FavoriteDriverPickerSheet extends StatefulWidget {
  const _FavoriteDriverPickerSheet({
    required this.marketplace,
    required this.title,
    required this.allowNone,
    this.selectedId,
  });

  final MarketplaceApi marketplace;
  final String title;
  final bool allowNone;
  final String? selectedId;

  @override
  State<_FavoriteDriverPickerSheet> createState() => _FavoriteDriverPickerSheetState();
}

class _FavoriteDriverPickerSheetState extends State<_FavoriteDriverPickerSheet> {
  List<FavoriteDriver> _drivers = const [];
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
      final favorites = await widget.marketplace.favoriteDrivers();
      if (mounted) {
        setState(() {
          _drivers = favorites.where((f) => f.isAccepted && f.driver != null).toList();
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

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.delivery_dining_outlined, color: AppColors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
          ),
          Flexible(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: ErrorState(message: _error!, onRetry: _load),
      );
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (widget.allowNone)
          _DriverOption(
            icon: Icons.public,
            title: 'Aucun livreur',
            subtitle: 'L\'offre sera visible par tous les livreurs disponibles.',
            selected: widget.selectedId == null,
            onTap: () => Navigator.of(context).pop(const FavoriteDriverChoice.none()),
          ),
        if (_drivers.isEmpty && !widget.allowNone)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(
              icon: Icons.delivery_dining_outlined,
              title: 'Aucun livreur favori',
              subtitle: 'Ajoutez des livreurs depuis « Mes livreurs » pour les retrouver ici.',
            ),
          ),
        for (final favorite in _drivers)
          _DriverOption(
            icon: Icons.delivery_dining_outlined,
            title: favorite.driver!.displayName,
            subtitle: _subtitle(favorite.driver!),
            selected: favorite.driver!.id == widget.selectedId,
            onTap: () => Navigator.of(context).pop(
              FavoriteDriverChoice(driverId: favorite.driver!.id, driver: favorite.driver),
            ),
          ),
      ],
    );
  }

  String _subtitle(DriverSummary driver) {
    final parts = [
      if (driver.vehicle != null && driver.vehicle!.trim().isNotEmpty) driver.vehicle!.trim(),
      if (driver.rating != null && driver.rating! > 0) '★ ${driver.rating!.toStringAsFixed(1)}',
      if (driver.phone != null && driver.phone!.trim().isNotEmpty) driver.phone!.trim(),
    ];
    return parts.isEmpty ? 'Livreur Béninfood' : parts.join(' · ');
  }
}

class _DriverOption extends StatelessWidget {
  const _DriverOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        side: BorderSide(
          color: selected ? AppColors.green : AppColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusLg)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: selected ? AppColors.greenLight : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          child: Icon(icon, color: selected ? AppColors.green : AppColors.textSecondary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: selected ? const Icon(Icons.check_circle, color: AppColors.green) : null,
      ),
    );
  }
}
