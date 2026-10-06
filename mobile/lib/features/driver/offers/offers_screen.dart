import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/delivery.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Offres de livraison disponibles (J161).
class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key, required this.marketplace, this.onOfferAccepted});

  final MarketplaceApi marketplace;
  final VoidCallback? onOfferAccepted;

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  List<Delivery> _offers = [];
  bool _available = false;
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
      final status = await widget.marketplace.driverStatus();
      final offers = await widget.marketplace.availableOffers();
      final rawProfile = status['profile'];
      final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
      if (mounted) {
        setState(() {
          _available = profile?['available'] == true;
          _offers = offers;
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

  Future<void> _accept(Delivery delivery) async {
    setState(() => _actionId = delivery.id);
    try {
      await widget.marketplace.acceptOffers(delivery.id);
      if (mounted) {
        showToast(context, 'Mission acceptée.');
        widget.onOfferAccepted?.call();
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _actionId = null);
      }
    }
  }

  Future<void> _decline(Delivery delivery) async {
    final reason = await _askDeclineReason();
    if (reason == null || !mounted) {
      return;
    }
    setState(() => _actionId = delivery.id);
    try {
      await widget.marketplace.declineOffer(delivery.id, reason: reason);
      if (mounted) {
        showToast(context, 'Offre déclinée.');
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _actionId = null);
      }
    }
  }

  Future<String?> _askDeclineReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Décliner l\'offre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Raison (optionnel)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Décliner'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offres disponibles'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        children: [
          if (!_available) ...[
            Card(
              color: AppColors.orangeLight,
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.orange),
                title: const Text('Vous êtes indisponible', style: TextStyle(color: AppColors.orangeDark)),
                subtitle: Text(
                  'Activez votre disponibilité pour accepter des offres.',
                  style: TextStyle(color: AppColors.orangeDark.withValues(alpha: 0.8)),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.sm),
          ],
          if (_offers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.goldLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_offer_outlined, size: 44, color: AppColors.gold),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Aucune offre pour le moment',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Les nouvelles offres apparaîtront ici.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._offers.asMap().entries.map((entry) {
              final index = entry.key;
              final offer = entry.value;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + index * 100),
                curve: Curves.easeOutBack,
                builder: (context, value, child) => Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                ),
                child: _OfferCard(
                  offer: offer,
                  busy: _actionId == offer.id,
                  onAccept: () => _accept(offer),
                  onDecline: () => _decline(offer),
                ),
              );
            }),
          const SizedBox(height: AppDimens.lg),
        ],
      ),
    );
  }
}

class _OfferCard extends StatefulWidget {
  const _OfferCard({
    required this.offer,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final Delivery offer;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = widget.offer.order?.reference ?? 'Mission';
    final vendorName = widget.offer.vendor?.businessName ?? 'Vendeur';
    final vendorAddress = [
      widget.offer.vendor?.address ?? '',
      widget.offer.vendor?.city ?? '',
    ].where((e) => e.isNotEmpty).join(', ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: _hover ? AppColors.gold : AppColors.border),
          boxShadow: _hover ? AppTheme.softShadow() : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reference,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusBadge(
                    label: 'Disponible',
                    color: widget.busy ? AppColors.textSecondary : AppColors.gold,
                    small: true,
                    icon: widget.busy ? Icons.hourglass_empty : Icons.local_offer,
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sm),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.goldLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.storefront_outlined, size: 20, color: AppColors.gold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vendorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                  ),
                ],
              ),
              if (vendorAddress.isNotEmpty) ...[
                const SizedBox(height: AppDimens.xs),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 16, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        vendorAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
              // Aperçu cartographique de l'offre : le livreur voit la zone de
              // collecte et l'adresse de livraison avant d'accepter.
              if (widget.offer.pickupPoint != null || widget.offer.dropoffPoint != null) ...[
                const SizedBox(height: AppDimens.sm),
                AppMap(
                  target: widget.offer.pickupPoint,
                  secondary: widget.offer.dropoffPoint,
                  height: 130,
                  initialZoom: 12,
                  followOrigin: false,
                  showRoute: false,
                ),
              ],
              if (widget.offer.order?.address != null && widget.offer.order!.address!.isNotEmpty) ...[
                const SizedBox(height: AppDimens.xs),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.offer.order!.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppDimens.sm),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.orangeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payments_outlined, size: 20, color: AppColors.orange),
                  ),
                  const SizedBox(width: 8),
                  AmountText(widget.offer.fee, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
                  if (widget.offer.partnerAmount != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Votre part :',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 4),
                    AmountText(widget.offer.partnerAmount, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
              const SizedBox(height: AppDimens.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.busy ? null : widget.onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
                      ),
                      child: widget.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Décliner'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.busy ? null : widget.onAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
                      ),
                      child: widget.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Accepter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
