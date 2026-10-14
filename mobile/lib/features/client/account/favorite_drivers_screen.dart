import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/models/favorite_driver.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/call_button.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/state_widgets.dart';

/// « Mes livreurs » : favoris d'un client ou d'un vendeur.
///
/// L'ajout envoie une demande au livreur, qui doit l'accepter. Une fois
/// accepté, il peut être visé en priorité pour une commande ou un colis.
class FavoriteDriversScreen extends StatefulWidget {
  const FavoriteDriversScreen({
    super.key,
    required this.marketplace,
    this.audience = NotificationAudience.client,
  });

  final MarketplaceApi marketplace;
  final NotificationAudience audience;

  @override
  State<FavoriteDriversScreen> createState() => _FavoriteDriversScreenState();
}

class _FavoriteDriversScreenState extends State<FavoriteDriversScreen> {
  List<FavoriteDriver> _favorites = const [];
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
          _favorites = favorites.where((f) => f.driver != null).toList();
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

  Future<void> _openAdd() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddFavoriteSheet(marketplace: widget.marketplace),
    );
    if (added == true && mounted) {
      showToast(context, 'Demande envoyée au livreur');
      _load();
    }
  }

  Future<void> _remove(FavoriteDriver favorite) async {
    try {
      await widget.marketplace.removeFavoriteDriver(favorite.driver!.id);
      if (mounted) {
        setState(() => _favorites = _favorites.where((f) => f.id != favorite.id).toList());
        showToast(context, 'Livreur retiré de vos favoris');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BeninfoodPageScaffold(
      title: 'Mes livreurs',
      api: widget.marketplace,
      audience: widget.audience,
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Ajouter'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_favorites.isEmpty) {
      return EmptyState(
        icon: Icons.delivery_dining_outlined,
        title: 'Aucun livreur favori',
        subtitle: 'Ajoutez les livreurs qui vous ont déjà livré. Ils recevront une demande.',
        actionLabel: 'Ajouter un livreur',
        onAction: _openAdd,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        itemCount: _favorites.length,
        itemBuilder: (context, index) => _FavoriteDriverCard(
          favorite: _favorites[index],
          onRemove: () => _remove(_favorites[index]),
        ),
      ),
    );
  }
}

class _FavoriteDriverCard extends StatelessWidget {
  const _FavoriteDriverCard({required this.favorite, required this.onRemove});

  final FavoriteDriver favorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final driver = favorite.driver!;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        side: BorderSide(
          color: favorite.isAccepted ? AppColors.green.withValues(alpha: 0.5) : AppColors.border,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: favorite.isAccepted ? AppColors.greenLight : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: Icon(
                    Icons.delivery_dining_outlined,
                    color: favorite.isAccepted ? AppColors.green : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(driver),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _StatusChip(favorite: favorite),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (favorite.isAccepted)
                  CallButton(label: 'Appeler', phone: driver.phone, compact: true),
                const Spacer(),
                IconButton(
                  tooltip: 'Retirer',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, color: AppColors.red),
                ),
              ],
            ),
          ],
        ),
      ),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.favorite});

  final FavoriteDriver favorite;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (favorite.status) {
      'accepted' => ('Accepté', AppColors.greenLight, AppColors.green),
      'declined' => ('Refusé', AppColors.redLight, AppColors.red),
      _ => ('En attente', AppColors.goldLight, AppColors.gold),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppDimens.radiusPill)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Feuille d'ajout : liste des livreurs ayant déjà livré le demandeur.
class _AddFavoriteSheet extends StatefulWidget {
  const _AddFavoriteSheet({required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<_AddFavoriteSheet> createState() => _AddFavoriteSheetState();
}

class _AddFavoriteSheetState extends State<_AddFavoriteSheet> {
  List<DriverSummary> _candidates = const [];
  bool _loading = true;
  String? _error;
  String? _addingId;

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
      final candidates = await widget.marketplace.favoriteDriverCandidates();
      if (mounted) {
        setState(() {
          _candidates = candidates;
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

  Future<void> _add(DriverSummary driver) async {
    setState(() => _addingId = driver.id);
    try {
      await widget.marketplace.addFavoriteDriver(driver.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _addingId = null);
        showToast(context, e.message, isError: true);
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                const Icon(Icons.person_add_alt, color: AppColors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Ajouter un livreur', style: Theme.of(context).textTheme.titleLarge),
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
      return Padding(padding: const EdgeInsets.all(8), child: ErrorState(message: _error!, onRetry: _load));
    }
    if (_candidates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: EmptyState(
          icon: Icons.delivery_dining_outlined,
          title: 'Aucun livreur éligible',
          subtitle: 'Seuls les livreurs ayant déjà effectué une livraison pour vous peuvent être ajoutés.',
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _candidates.length,
      itemBuilder: (context, index) {
        final driver = _candidates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            side: const BorderSide(color: AppColors.border),
          ),
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: const Icon(Icons.delivery_dining_outlined, color: AppColors.textSecondary),
            ),
            title: Text(driver.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              [driver.vehicle, driver.phone].whereType<String>().where((p) => p.trim().isNotEmpty).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _addingId == driver.id
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_circle_outline, color: AppColors.orange),
            onTap: _addingId == null ? () => _add(driver) : null,
          ),
        );
      },
    );
  }
}
