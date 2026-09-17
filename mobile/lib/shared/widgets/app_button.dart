import 'package:flutter/material.dart';

/// Bouton pleine largeur avec états (loading / disabled) — J24 §2.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;
  final AppButtonVariant variant;
  final bool fullWidth;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final background = switch (variant) {
      AppButtonVariant.primary => colorScheme.primary,
      AppButtonVariant.secondary => colorScheme.secondaryContainer,
      AppButtonVariant.outline => Colors.transparent,
      AppButtonVariant.danger => colorScheme.error,
    };

    final foreground = switch (variant) {
      AppButtonVariant.primary => colorScheme.onPrimary,
      AppButtonVariant.secondary => colorScheme.onSecondaryContainer,
      AppButtonVariant.outline => colorScheme.primary,
      AppButtonVariant.danger => colorScheme.onError,
    };

    final canTap = enabled && !loading;
    final border = variant == AppButtonVariant.outline
        ? BorderSide(color: colorScheme.primary, width: 1.5)
        : BorderSide.none;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.4),
          disabledForegroundColor: foreground.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: border),
        ),
        onPressed: canTap ? onPressed : null,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

enum AppButtonVariant { primary, secondary, outline, danger }