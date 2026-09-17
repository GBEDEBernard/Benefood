import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

/// Montant formaté en FCFA (centimes XOF → affichage).
class AmountText extends StatelessWidget {
  const AmountText(this.amountCents, {super.key, this.style, this.showSymbol = true});

  final int? amountCents;
  final TextStyle? style;
  final bool showSymbol;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatAmount(amountCents ?? 0, showSymbol: showSymbol),
      style: style,
    );
  }
}