// ignore_for_file: avoid_classes_with_only_static_members

import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static ThemeData get light => _buildTheme();
  static ThemeData get dark => _buildTheme();

  static ThemeData _buildTheme() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceTint: AppColors.primary,
      outline: AppColors.outline,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      error: AppColors.error,
      onError: Colors.white,
      tertiary: AppColors.success,
      onTertiary: Colors.white,
      inverseSurface: AppColors.onSurface,
      inversePrimary: AppColors.secondary,
      shadow: Colors.black,
      scrim: Colors.black54,
    );

    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: textTheme.bodyLarge?.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: AppColors.outline),
        ),
        margin: EdgeInsets.all(12),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.7),
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondary,
          side: const BorderSide(color: AppColors.outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: AppColors.secondary.withValues(alpha: 0.16),
        labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.onSurface),
        shape: const StadiumBorder(side: BorderSide(color: AppColors.outline)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.outline),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.secondary, width: 1.6),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        labelStyle: TextStyle(color: AppColors.onSurfaceVariant),
        hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.secondary,
        linearTrackColor: AppColors.outline,
        circularTrackColor: AppColors.outline,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.onSurface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      textTheme: textTheme,
      listTileTheme: const ListTileThemeData(
        tileColor: AppColors.surface,
        textColor: AppColors.onSurface,
        iconColor: AppColors.onSurfaceVariant,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minVerticalPadding: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: AppColors.error.withValues(alpha: 0.12),
        contentTextStyle: const TextStyle(
          color: AppColors.onSurface,
          fontSize: 14,
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        FeedbackColors(
          success: AppColors.success,
          warning: AppColors.warning,
          error: AppColors.error,
        ),
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
