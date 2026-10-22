import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart';

/// Demande de retrait saisie par l'utilisateur.
class PayoutRequest {
  const PayoutRequest({
    required this.amount,
    required this.method,
    required this.destination,
  });

  final int amount;
  final String method;
  final String destination;
}

/// Ouvre la feuille de retrait Mobile Money.
///
/// Utilisée directement depuis le portefeuille vendeur (sans page
/// intermédiaire) et depuis le wallet livreur. Renvoie `null` si l'utilisateur
/// ferme la feuille.
Future<PayoutRequest?> showPayoutRequestSheet(
  BuildContext context, {
  required int available,
  required int minPayout,
  String? phone,
}) {
  return showModalBottomSheet<PayoutRequest>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => PayoutRequestSheet(
      available: available,
      minPayout: minPayout,
      phone: phone,
    ),
  );
}

/// Formulaire de retrait : montant, réseau Mobile Money et numéro bénéficiaire.
class PayoutRequestSheet extends StatefulWidget {
  const PayoutRequestSheet({
    super.key,
    required this.available,
    required this.minPayout,
    this.phone,
  });

  final int available;
  final int minPayout;
  final String? phone;

  static const Key amountFieldKey = Key('payout-amount-field');
  static const Key phoneFieldKey = Key('payout-phone-field');

  @override
  State<PayoutRequestSheet> createState() => _PayoutRequestSheetState();
}

class _PayoutRequestSheetState extends State<PayoutRequestSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.available.toString(),
  );
  late final TextEditingController _destination = TextEditingController(
    text: widget.phone ?? '',
  );
  String _method = 'mtn_open';
  String? _amountError;
  String? _phoneError;

  @override
  void dispose() {
    _amount.dispose();
    _destination.dispose();
    super.dispose();
  }

  void _withdrawAll() {
    _amount.text = widget.available.toString();
    setState(() => _amountError = null);
  }

  void _submit() {
    final value = int.tryParse(_amount.text.trim());
    final phone = _destination.text.trim();

    setState(() {
      _amountError = null;
      _phoneError = null;
    });

    if (value == null || value < widget.minPayout) {
      setState(
        () => _amountError =
            'Le minimum est de ${formatAmount(widget.minPayout)}.',
      );
      return;
    }
    if (value > widget.available) {
      setState(() => _amountError = 'Montant supérieur au solde disponible.');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _phoneError = 'Numéro Mobile Money requis.');
      return;
    }

    HapticFeedback.selectionClick();
    Navigator.of(
      context,
    ).pop(PayoutRequest(amount: value, method: _method, destination: phone));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 21,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Retirer mes gains',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Choisissez le montant et votre Mobile Money.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Solde disponible',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatAmount(widget.available),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    ),
                    child: Text(
                      'Min. ${formatAmount(widget.minPayout)}',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Montant à retirer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _withdrawAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Tout retirer',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              key: PayoutRequestSheet.amountFieldKey,
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: 'FCFA',
                hintText: 'Montant',
                errorText: _amountError,
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            const Text(
              'Recevoir sur',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            Row(
              children: [
                Expanded(
                  child: _MethodChip(
                    label: 'MTN',
                    value: 'mtn_open',
                    selected: _method,
                    onTap: (value) => setState(() => _method = value),
                  ),
                ),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: _MethodChip(
                    label: 'Moov',
                    value: 'moov',
                    selected: _method,
                    onTap: (value) => setState(() => _method = value),
                  ),
                ),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: _MethodChip(
                    label: 'Celtiis',
                    value: 'sbin',
                    selected: _method,
                    onTap: (value) => setState(() => _method = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            TextField(
              key: PayoutRequestSheet.phoneFieldKey,
              controller: _destination,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Numéro Mobile Money',
                prefixIcon: const Icon(Icons.phone_iphone),
                hintText: 'Ex. +229 96 00 00 00',
                errorText: _phoneError,
              ),
            ),
            const SizedBox(height: AppDimens.md),
            Container(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Les fonds sont envoyés sur ce numéro. Le traitement peut prendre quelques minutes.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Confirmer le retrait',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orangeLight : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.orange : AppColors.border,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 17,
              color: isSelected ? AppColors.orange : AppColors.textFaint,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.orangeDark
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
