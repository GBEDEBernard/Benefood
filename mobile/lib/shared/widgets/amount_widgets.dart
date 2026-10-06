import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

/// Montant formaté en FCFA (entier sans décimale → affichage).
class AmountText extends StatelessWidget {
  const AmountText(
    this.amount, {
    super.key,
    this.style,
    this.showSymbol = true,
    this.maxLines,
    this.overflow,
  });

  final int? amount;
  final TextStyle? style;
  final bool showSymbol;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatAmount(amount ?? 0, showSymbol: showSymbol),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}