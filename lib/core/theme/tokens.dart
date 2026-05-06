// ignore_for_file: avoid_classes_with_only_static_members

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Семантические цвета, не зависящие от темы. Зелёный/красный для P/U,
/// жёлтый предупреждения, основной синий и тёплый коралл — одинаковые
/// в светлой и тёмной теме (имеют достаточный контраст на обоих фонах).
class AppColors {
  static const primary = Color(0xFF5D8CFF);
  static const secondary = Color(0xFFFF9E7C);
  static const success = Color(0xFF37B38A);
  static const warning = Color(0xFFF5C24D);
  static const error = Color(0xFFF16B82);

  // Совместимость со старым кодом, который ссылается напрямую.
  // Эти значения совпадают с light-палитрой и больше не должны использоваться
  // в новых местах — берите цвета из Theme.of(context).colorScheme.
  @Deprecated('Use Theme.of(context).colorScheme.surface')
  static const surface = Color(0xFFFFFFFF);
  @Deprecated('Use Theme.of(context).colorScheme.surface')
  static const background = Color(0xFFE9F0FF);
  @Deprecated('Use Theme.of(context).colorScheme.surfaceContainerHighest')
  static const surfaceVariant = Color(0xFFF1F5FF);
  @Deprecated('Use Theme.of(context).colorScheme.outline')
  static const outline = Color(0xFFB5C6F5);
  @Deprecated('Use Theme.of(context).colorScheme.onPrimary')
  static const onPrimary = Color(0xFF0B1630);
  @Deprecated('Use Theme.of(context).colorScheme.onSecondary')
  static const onSecondary = Color(0xFF3B1C10);
  @Deprecated('Use Theme.of(context).colorScheme.onSurface')
  static const onSurface = Color(0xFF0B1224);
  @Deprecated('Use Theme.of(context).colorScheme.onSurfaceVariant')
  static const onSurfaceVariant = Color(0xFF44506A);
}

/// Палитра темы — одно и то же для конкретного режима.
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.outline,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onPrimary,
    required this.onSecondary,
    required this.heroBorder,
    required this.heroShadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color outline;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color onPrimary;
  final Color onSecondary;

  /// Тонкая обводка карточек hero/списков. На светлой — почти прозрачный
  /// тёмно-синий, на тёмной — низкий контраст-белый.
  final Color heroBorder;

  /// Цвет тени под hero-карточкой. На тёмной теме обычно прозрачный
  /// (тени читаются плохо).
  final Color heroShadow;

  static const light = AppPalette(
    background: Color(0xFFF4F5F8),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1F5FF),
    outline: Color(0xFFB5C6F5),
    onSurface: Color(0xFF0B1224),
    onSurfaceVariant: Color(0xFF44506A),
    onPrimary: Colors.white,
    onSecondary: Color(0xFF3B1C10),
    heroBorder: Color(0x12141C20),
    heroShadow: Color(0x0A14161C),
  );

  static const dark = AppPalette(
    background: Color(0xFF0E1117),
    surface: Color(0xFF161B22),
    surfaceVariant: Color(0xFF1F2530),
    outline: Color(0x33FFFFFF),
    onSurface: Color(0xFFE5E7EE),
    onSurfaceVariant: Color(0xFF93A0BC),
    onPrimary: Colors.white,
    onSecondary: Color(0xFF3B1C10),
    heroBorder: Color(0x22FFFFFF),
    heroShadow: Color(0x00000000),
  );
}

/// Доступ к палитре через ThemeExtension — чтобы виджеты могли запрашивать
/// палитру и не дублировать логику «как в системе».
@immutable
class AppPaletteExtension extends ThemeExtension<AppPaletteExtension> {
  const AppPaletteExtension(this.palette);

  final AppPalette palette;

  @override
  AppPaletteExtension copyWith({AppPalette? palette}) =>
      AppPaletteExtension(palette ?? this.palette);

  @override
  AppPaletteExtension lerp(ThemeExtension<AppPaletteExtension>? other, double t) {
    if (other is! AppPaletteExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPaletteExtension>()?.palette ??
      AppPalette.light;
}

class AppTypography {
  static const fontFamilyFallback = ['Nunito', 'Caveat', 'sans-serif'];

  static TextTheme get textTheme => TextTheme(
    headlineLarge: GoogleFonts.caveat(
      fontSize: 32,
      height: 1.05,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: GoogleFonts.caveat(
      fontSize: 26,
      height: 1.08,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.nunito(
      fontSize: 19,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
    bodyLarge: GoogleFonts.nunito(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: GoogleFonts.nunito(
      fontSize: 15,
      height: 1.45,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: GoogleFonts.nunito(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
    bodySmall: GoogleFonts.nunito(
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w500,
    ),
  );
}
