import 'package:flutter/material.dart';

/// Stepper de quantité (− valeur +) avec bornes — J24 §2.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.quantity, required this.onChanged, this.min = 1, this.max = 99});

  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget stepButton(IconData icon, bool enabled, VoidCallback onTap) {
      return InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: enabled ? colorScheme.surfaceContainerHighest : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: enabled ? colorScheme.onSurface : colorScheme.outline),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          stepButton(Icons.remove, quantity > min, () => onChanged(quantity - 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('$quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          stepButton(Icons.add, quantity < max, () => onChanged(quantity + 1)),
        ],
      ),
    );
  }
}