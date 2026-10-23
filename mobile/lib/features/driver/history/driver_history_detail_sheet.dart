import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/delivery.dart';
import '../../../shared/widgets/amount_widgets.dart';
import '../../../shared/widgets/call_button.dart';
import '../../../shared/widgets/package_item_tile.dart';
import '../../../shared/widgets/status_badge.dart';

/// Feuille « Détail de la mission » ouverte depuis l'historique livreur.
///
/// Affiche tout le contenu de la mission terminée : avancement, montants,
/// point de collecte, adresse de livraison, client et contenu du colis.
void showDriverHistoryDetails(BuildContext context, Delivery delivery) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
    ),
    builder: (context) => _DriverHistoryDetails(delivery: delivery),
  );
}

class _DriverHistoryDetails extends StatelessWidget {
  const _DriverHistoryDetails({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final order = delivery.order;
    final vendor = delivery.vendor;
    final palette = BadgePalette.delivery(delivery.status);
    final reference = order?.reference ?? 'Mission';

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimens.sm),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding,
                  AppDimens.lg,
                  AppDimens.pagePadding,
                  AppDimens.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête : référence + statut.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Détail de la mission',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reference,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (palette != null)
                          StatusBadge(label: palette.$1, color: palette.$2),
                      ],
                    ),
                    const SizedBox(height: AppDimens.lg),

                    _Section(
                      title: 'Avancement',
                      icon: Icons.timeline,
                      children: [
                        _TimelineRow(
                          label: 'Mission créée',
                          date: delivery.createdAt,
                          icon: Icons.fiber_manual_record,
                          color: AppColors.textSecondary,
                        ),
                        _TimelineRow(
                          label: 'Affectée au livreur',
                          date: delivery.assignedAt,
                          icon: Icons.motorcycle,
                          color: AppColors.orange,
                        ),
                        _TimelineRow(
                          label: 'Commande collectée',
                          date: delivery.pickedUpAt,
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.goldDark,
                        ),
                        _TimelineRow(
                          label: 'Livraison terminée',
                          date: delivery.deliveredAt,
                          icon: Icons.check_circle_outline,
                          color: AppColors.green,
                          last: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.md),

                    _Section(
                      title: 'Montants',
                      icon: Icons.payments_outlined,
                      children: [
                        _AmountRow(
                          label: 'Frais de livraison client',
                          amount: delivery.fee,
                          accent: AppColors.orange,
                        ),
                        _AmountRow(
                          label: 'Votre gain',
                          amount: delivery.netEarnings,
                          accent: AppColors.green,
                        ),
                        if (order?.total != null)
                          _AmountRow(
                            label: 'Total de la commande',
                            amount: order!.total,
                            accent: AppColors.text,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.md),

                    _Section(
                      title: 'Collecte',
                      icon: Icons.storefront_outlined,
                      children: [
                        _InfoLine(
                          label: vendor?.businessName ?? 'Boutique',
                          value: [
                            vendor?.address ?? '',
                            vendor?.city ?? '',
                          ].where((e) => e.isNotEmpty).join(', '),
                          icon: Icons.storefront_outlined,
                          accent: AppColors.goldDark,
                        ),
                        if (vendor?.phone?.trim().isNotEmpty ?? false)
                          _ActionLine(
                            label: 'Appeler la boutique',
                            phone: vendor!.phone,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.md),

                    _Section(
                      title: 'Livraison',
                      icon: Icons.location_on_outlined,
                      children: [
                        _InfoLine(
                          label: 'Adresse de livraison',
                          value: order?.address ?? '—',
                          icon: Icons.location_on_outlined,
                          accent: AppColors.green,
                        ),
                        _InfoLine(
                          label: order?.client?.name ?? 'Client',
                          value: order?.client?.phone ?? '',
                          icon: Icons.person_outline,
                          accent: AppColors.orange,
                        ),
                        if (order?.client?.phone?.trim().isNotEmpty ?? false)
                          _ActionLine(
                            label: 'Appeler le client',
                            phone: order!.client!.phone,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.md),

                    if (order?.items.isNotEmpty ?? false) ...[
                      PackageContentCard(
                        children: [
                          for (final item in order!.items)
                            PackageItemTile(
                              name: item.name,
                              quantity: item.quantity,
                              imageUrl: item.imageUrl,
                              dense: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.md),
                    ],

                    if (delivery.proofCode?.trim().isNotEmpty ?? false) ...[
                      _Section(
                        title: 'Preuve de livraison',
                        icon: Icons.verified_outlined,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.greenLight,
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusSm + 2,
                                  ),
                                ),
                                child: Text(
                                  delivery.proofCode!.trim(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: AppColors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.md),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, AppDimens.buttonHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusMd,
                            ),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Fermer',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte de section (titre + contenu).
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          ...children,
        ],
      ),
    );
  }
}

/// Étape de l'avancement : libellé + horodatage.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.date,
    required this.icon,
    required this.color,
    this.last = false,
  });

  final String label;
  final String? date;
  final IconData icon;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final done = (date ?? '').trim().isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: done
                      ? color.withValues(alpha: 0.14)
                      : AppColors.textFaint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: done ? color : AppColors.textFaint,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : AppDimens.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: done ? AppColors.text : AppColors.textFaint,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    done
                        ? formatDateTime(date, fallback: '—')
                        : 'Non effectué',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne « libellé + montant ».
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    required this.accent,
  });

  final String label;
  final int? amount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          AmountText(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne d'information (icône + libellé + valeur).
class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                if (value.trim().isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne d'action (appeler le client ou la boutique).
class _ActionLine extends StatelessWidget {
  const _ActionLine({required this.label, required this.phone});

  final String label;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SizedBox(
        width: double.infinity,
        child: CallButton(label: label, phone: phone),
      ),
    );
  }
}
