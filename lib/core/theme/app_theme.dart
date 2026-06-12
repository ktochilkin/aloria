// ignore_for_file: avoid_classes_with_only_static_members, deprecated_member_use_from_same_package

import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: palette.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: palette.onSecondary,
      surface: palette.surface,
      onSurface: palette.onSurface,
      surfaceTint: AppColors.primary,
      outline: palette.outline,
      surfaceContainerHighest: palette.surfaceVariant,
      onSurfaceVariant: palette.onSurfaceVariant,
      error: AppColors.error,
      onError: Colors.white,
      tertiary: AppColors.success,
      onTertiary: Colors.white,
      shadow: Colors.black,
      scrim: Colors.black54,
    );

    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: textTheme.bodyLarge?.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.onSurface,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      // База Coinbase: белая карта, hairline-граница вместо тени, радиус 24.
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: palette.outline),
        ),
        margin: const EdgeInsets.all(12),
      ),
      dividerTheme: DividerThemeData(
        color: palette.outline,
        thickness: 1,
      ),
      // Кнопки — пилюли (StadiumBorder), синий primary.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: palette.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.onSurface,
          side: BorderSide(color: palette.outline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: const StadiumBorder(),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        labelStyle:
            textTheme.labelMedium?.copyWith(color: palette.onSurface),
        shape: StadiumBorder(side: BorderSide(color: palette.outline)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: palette.outline),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        labelStyle: TextStyle(color: palette.onSurfaceVariant),
        hintStyle: TextStyle(color: palette.onSurfaceVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: palette.outline,
        circularTrackColor: palette.outline,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: palette.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return IconThemeData(
            color: palette.onSurfaceVariant.withValues(alpha: 0.75),
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            );
          }
          return textTheme.labelMedium?.copyWith(
            color: palette.onSurfaceVariant.withValues(alpha: 0.75),
            fontWeight: FontWeight.w500,
          );
        }),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      textTheme: textTheme,
      listTileTheme: ListTileThemeData(
        tileColor: palette.surface,
        textColor: palette.onSurface,
        iconColor: palette.onSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minVerticalPadding: 10,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: AppColors.error.withValues(alpha: 0.12),
        contentTextStyle: TextStyle(
          color: palette.onSurface,
          fontSize: 14,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        const FeedbackColors(
          success: AppColors.success,
          warning: AppColors.warning,
          error: AppColors.error,
        ),
        AppPaletteExtension(palette),
      ],
    );
  }
}

@immutable
class FeedbackColors extends ThemeExtension<FeedbackColors> {
  const FeedbackColors({
    required this.success,
    required this.warning,
    required this.error,
  });
  final Color success;
  final Color warning;
  final Color error;

  @override
  FeedbackColors copyWith({Color? success, Color? warning, Color? error}) {
    return FeedbackColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  FeedbackColors lerp(ThemeExtension<FeedbackColors>? other, double t) {
    if (other is! FeedbackColors) return this;
    return FeedbackColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}
