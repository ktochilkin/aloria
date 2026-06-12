// ignore_for_file: avoid_classes_with_only_static_members

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Семантические цвета, не зависящие от темы. Зелёный/красный для P/U,
/// жёлтый предупреждения, основной синий и тёплый коралл — одинаковые
/// в светлой и тёмной теме (имеют достаточный контраст на обоих фонах).
class AppColors {
  // База Coinbase: единственный акцент структуры — Coinbase Blue. Тёплый
  // коралл (secondary) остаётся для контентных/игровых акцентов, не для хрома.
  static const primary = Color(0xFF0052FF);
  static const secondary = Color(0xFFFF7A59);

  // Семантика: мягкие, менее насыщенные зелёный/красный (не «кричащие»).
  // Внимание/предупреждение — тёплый терракотовый оранж: жёлтый на белом
  // холсте выглядел грязно.
  static const success = Color(0xFF37B38A);
  static const warning = Color(0xFFF0794A);
  static const error = Color(0xFFF16B82);

  /// Учебный акцент: глубокий перивинкл-синий — светлый брат [primary],
  /// тинт этапов и базовый цвет диаграмм.
  static const accentBlue = Color(0xFF4C6FFF);

  /// Светлый край градиента от [primary] (баннер учебного режима).
  static const primaryBright = Color(0xFF7BA3FF);

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

/// Категориальная палитра диаграмм (стек портфеля и т.п.): порядок цветов —
/// от акцентного к нейтральному, серый — для агрегата «Прочие».
abstract final class AppChartPalette {
  static const blue = AppColors.accentBlue;
  static const blueLight = Color(0xFF7B93FF);
  static const blueFaint = Color(0xFFAAB9FF);
  static const coral = AppColors.secondary;
  static const coralLight = Color(0xFFFFA98F);
  static const neutral = Color(0xFFC8C8D0);

  /// Цвета по порядку назначения категориям.
  static const categorical = <Color>[
    blue,
    blueLight,
    blueFaint,
    coral,
    coralLight,
    neutral,
  ];
}

/// Сырьё светлой палитры как const-константы: для мест, где требуется
/// const-выражение (default-параметры, static const алиасы экранов) —
/// поля `AppPalette.light` в const-контексте недоступны.
abstract final class AppLightColors {
  /// Почти чёрные заголовки/цифры.
  static const ink = Color(0xFF0A0B0D);

  /// Вторичный текст.
  static const body = Color(0xFF5B616E);

  /// Тонкие разделители и обводки.
  static const hairline = Color(0xFFDEE1E6);

  /// Белый холст.
  static const canvas = Color(0xFFFFFFFF);

  /// Плотная серая поверхность (чипы, подложки).
  static const surfaceStrong = Color(0xFFEEF0F3);
}

/// Семантика торгового экрана (база Coinbase): рост/падение передаются
/// только цветом текста, плюс мьютед-подписи. Осознанно отличаются от
/// [AppColors.success]/[AppColors.error] — на экране данных нужны более
/// плотные, «биржевые» зелёный и красный.
abstract final class TradeColors {
  static const up = Color(0xFF05B169);
  static const down = Color(0xFFCF202F);
  static const muted = Color(0xFF7C828A);
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
    // База Coinbase: белый холст, surface-strong и hairline.
    background: AppLightColors.canvas,
    surface: AppLightColors.canvas,
    surfaceVariant: AppLightColors.surfaceStrong,
    outline: AppLightColors.hairline,
    onSurface: AppLightColors.ink,
    onSurfaceVariant: AppLightColors.body,
    onPrimary: Colors.white,
    onSecondary: Color(0xFF3B1C10),
    heroBorder: AppLightColors.hairline,
    heroShadow: Color(0x00000000),
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
  static const fontFamilyFallback = ['Nunito', 'sans-serif'];

  // Заголовки — тем же Nunito, плотным начертанием: рукописный Caveat
  // конфликтовал с финансовым контекстом и хуже читался.
  static TextTheme get textTheme => TextTheme(
    headlineLarge: GoogleFonts.nunito(
      fontSize: 28,
      height: 1.1,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    headlineMedium: GoogleFonts.nunito(
      fontSize: 22,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
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
