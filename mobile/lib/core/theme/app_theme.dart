import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// Thème Material 3 Béninfood — rendu premium : fond ivoire chaud,
/// actions orange, validations vertes, typographie anthracite.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.orange,
      onPrimary: Colors.white,
      primaryContainer: AppColors.orangeLight,
      onPrimaryContainer: AppColors.orangeDark,
      secondary: AppColors.green,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.greenLight,
      onSecondaryContainer: AppColors.green,
      tertiary: AppColors.gold,
      onTertiary: AppColors.text,
      tertiaryContainer: AppColors.goldLight,
      onTertiaryContainer: AppColors.goldDark,
      error: AppColors.red,
      onError: Colors.white,
      errorContainer: AppColors.redLight,
      onErrorContainer: Color(0xFF8A1B13),
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      shadow: Color(0x1418231F),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
    );

    final textTheme = base.textTheme
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
          titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.4),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
          labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.35),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, AppDimens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? AppColors.orangeDark.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.orange,
          minimumSize: const Size(0, AppDimens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
          side: const BorderSide(color: AppColors.orange, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.orange),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 15),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.orange, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.red, width: 1.8),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x1418231F),
        height: 68,
        indicatorColor: AppColors.orangeLight,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.orangeDark : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? AppColors.orangeDark : AppColors.textSecondary,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusPill)),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        selectedColor: AppColors.orangeLight,
        checkmarkColor: AppColors.orangeDark,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusXl)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        contentTextStyle: const TextStyle(fontSize: 14, color: AppColors.ivory),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.orange,
        linearTrackColor: AppColors.orangeLight,
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
      ),
      switchTheme: base.switchTheme.copyWith(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.orange : null),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.orange.withValues(alpha: 0.35) : null),
      ),
      checkboxTheme: base.checkboxTheme.copyWith(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.orange : Colors.transparent,
        ),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: base.radioTheme.copyWith(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.orange : AppColors.textFaint,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.orange,
        thumbColor: AppColors.orange,
        inactiveTrackColor: AppColors.orangeLight,
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.orange,
        textColor: Colors.white,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(fontSize: 12, color: AppColors.ivory),
      ),
    );
  }

  /// Ombre douce et chaude pour les cartes « levées ».
  static List<BoxShadow> softShadow() => const [
        BoxShadow(
          color: Color(0x1218231F),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ];
}
