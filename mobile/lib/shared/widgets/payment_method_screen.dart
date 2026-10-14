import 'package:flutter/material.dart';

import '../../core/data/marketplace_api.dart';
import '../../core/navigation/notification_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'amount_widgets.dart';
import 'beninfood_header.dart';

/// Choix du moyen de paiement (page dédiée) : paiement en ligne sécurisé via
/// Kkiapay (mobile money / carte) ou espèces à la livraison. Renvoie
/// `'online'` ou `'cash'` (ou `null` si l'utilisateur revient en arrière).
class ParcelPaymentMethodScreen extends StatefulWidget {
  const ParcelPaymentMethodScreen({
    super.key,
    required this.marketplace,
    required this.amount,
    this.audience = NotificationAudience.client,
  });

  final MarketplaceApi marketplace;
  final int amount;
  final NotificationAudience audience;

  @override
  State<ParcelPaymentMethodScreen> createState() =>
      _ParcelPaymentMethodScreenState();
}

class _ParcelPaymentMethodScreenState extends State<ParcelPaymentMethodScreen> {
  String? _selected;

  void _validate() {
    final selected = _selected;
    if (selected == null) {
      return;
    }
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BeninfoodAppBar(
            onMenu: () => Navigator.of(context).maybePop(),
            api: widget.marketplace,
            audience: widget.audience,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.pagePadding),
              children: [
                const Text(
                  'Moyen de paiement',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choisissez comment régler les frais de livraison.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppDimens.xl),
                Container(
                  padding: const EdgeInsets.all(AppDimens.lg),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Montant à régler',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      AmountText(
                        widget.amount,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.xl),
                _PaymentOption(
                  icon: Icons.smartphone,
                  title: 'Mobile money / Carte',
                  subtitle: 'Paiement en ligne sécurisé via Kkiapay.',
                  selected: _selected == 'online',
                  onTap: () => setState(() => _selected = 'online'),
                ),
                const SizedBox(height: AppDimens.md),
                _PaymentOption(
                  icon: Icons.payments_outlined,
                  title: 'Espèces à la livraison',
                  subtitle: 'Vous remettez les frais au livreur à la réception.',
                  selected: _selected == 'cash',
                  onTap: () => setState(() => _selected = 'cash'),
                ),
                const SizedBox(height: AppDimens.xxl),
                FilledButton.icon(
                  onPressed: _selected == null ? null : _validate,
                  icon: const Icon(Icons.check_circle_outline),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  label: const Text('Valider'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(
            color: selected ? AppColors.green : AppColors.border,
            width: selected ? 1.6 : 1.2,
          ),
          color: selected ? AppColors.greenLight.withValues(alpha: 0.4) : AppColors.surface,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? AppColors.greenLight : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.green : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? AppColors.green : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
