import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Points d'étape du parcours d'inscription : l'étape active est orange
/// (et allongée), les suivantes sont grises.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.activeIndex, this.count = 4});

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == activeIndex ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == activeIndex
                  ? AppColors.orange
                  : AppColors.borderStrong,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
