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

/// « Mes clients » : demandes de favori reçues par un livreur.
///
/// Le livreur accepte (il pourra être visé en priorité) ou refuse chaque
/// demande. Les clients acceptés restent contactables depuis cet écran.
class FavoriteClientsScreen extends StatefulWidget {
  const FavoriteClientsScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<FavoriteClientsScreen> createState() => _FavoriteClientsScreenState();
}

class _FavoriteClientsScreenState extends State<FavoriteClientsScreen> {
  List<FavoriteDriver> _requests = const [];
  bool _loading = true;
  String? _error;
  String? _actionId;

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
      final requests = await widget.marketplace.favoriteClients();
      if (mounted) {
        setState(() {
          _requests = requests.where((r) => r.owner != null).toList();
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

  Future<void> _respond(FavoriteDriver favorite, {required bool accept}) async {
    setState(() => _actionId = favorite.id);
    try {
      final updated = accept
          ? await widget.marketplace.acceptFavoriteClient(favorite.id)
          : await widget.marketplace.declineFavoriteClient(favorite.id);
      if (mounted) {
        setState(() {
          _requests = _requests.map((r) => r.id == favorite.id ? updated : r).toList();
          _actionId = null;
        });
        showToast(context, accept ? 'Client ajouté à vos favoris' : 'Demande refusée');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _actionId = null);
        showToast(context, e.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BeninfoodPageScaffold(
      title: 'Mes clients',
      api: widget.marketplace,
      audience: NotificationAudience.driver,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_requests.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'Aucune demande',
        subtitle: 'Les clients et boutiques qui vous demandent en favori apparaîtront ici.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        itemCount: _requests.length,
        itemBuilder: (context, index) => _FavoriteClientCard(
          favorite: _requests[index],
          busy: _actionId == _requests[index].id,
          onAccept: () => _respond(_requests[index], accept: true),
          onDecline: () => _respond(_requests[index], accept: false),
        ),
      ),
    );
  }
}

class _FavoriteClientCard extends StatelessWidget {
  const _FavoriteClientCard({
    required this.favorite,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final FavoriteDriver favorite;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final owner = favorite.owner!;

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
                    owner.role == 'vendor' ? Icons.storefront_outlined : Icons.person_outline,
                    color: favorite.isAccepted ? AppColors.green : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(owner.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        [owner.displayRole, owner.phone].whereType<String>().where((p) => p.trim().isNotEmpty).join(' · '),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _FavoriteClientStatusChip(favorite: favorite),
              ],
            ),
            const SizedBox(height: 10),
            if (favorite.isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onDecline,
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : onAccept,
                      child: busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Accepter'),
                    ),
                  ),
                ],
              )
            else if (favorite.isAccepted)
              Align(
                alignment: Alignment.centerLeft,
                child: CallButton(label: 'Appeler', phone: owner.phone, compact: true),
              ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteClientStatusChip extends StatelessWidget {
  const _FavoriteClientStatusChip({required this.favorite});

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
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
