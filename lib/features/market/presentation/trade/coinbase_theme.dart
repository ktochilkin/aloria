import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// === ЭКСПЕРИМЕНТ: дизайн-система Coinbase, локально на торговом экране ===
// Белый холст, единственный акцент Coinbase Blue (только primary-CTA),
// чернильный текст + серый body, hairline-границы вместо теней, карты r24,
// кнопки-пилюли, числа моноширинным, торговые зелёный/красный только как текст.
// Применяется через scoped Theme только на торговом экране — остальное
// приложение не затрагивается.

/// Brand voltage — только primary-CTA.
const cbBlue = AppColors.primary;

/// Заголовки/эмфаза.
const cbInk = AppLightColors.ink;

/// Основной текст (прохладный серый).
const cbBody = AppLightColors.body;

/// Подписи/мьютед.
const cbMuted = TradeColors.muted;

/// 1px разделители/границы карт.
const cbHairline = AppLightColors.hairline;

/// Холст.
const cbCanvas = AppLightColors.canvas;

/// Вторичные кнопки/плашки.
const cbSurfaceStrong = AppLightColors.surfaceStrong;

/// Semantic up (только текст).
const cbUp = TradeColors.up;

/// Semantic down (только текст).
const cbDown = TradeColors.down;

/// Стиль чисел: Nunito с табличными цифрами (одна ширина → ровные колонки),
/// современнее моноширинного «терминального» шрифта.
TextStyle cbMono({
  required double size,
  FontWeight weight = FontWeight.w600,
  Color color = cbInk,
}) =>
    GoogleFonts.nunito(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Scoped-тема торгового экрана поверх базовой темы приложения.
ThemeData coinbaseTheme(BuildContext context) {
  final base = Theme.of(context);
  final t = base.textTheme;
  return base.copyWith(
    scaffoldBackgroundColor: cbCanvas,
    colorScheme: base.colorScheme.copyWith(
      primary: cbBlue,
      onPrimary: Colors.white,
      surface: cbCanvas,
      onSurface: cbInk,
      onSurfaceVariant: cbBody,
      surfaceContainerHighest: cbSurfaceStrong,
      outline: cbHairline,
      outlineVariant: cbHairline,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: cbCanvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: cbInk,
      elevation: 0,
    ),
    // Coinbase: плоско, hairline-граница вместо тени, радиус 24.
    cardTheme: const CardThemeData(
      color: cbCanvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        side: BorderSide(color: cbHairline),
      ),
    ),
    dividerTheme: const DividerThemeData(color: cbHairline, thickness: 1),
    textTheme: t.copyWith(
      headlineMedium: t.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w400, letterSpacing: -1, color: cbInk),
      headlineSmall: t.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w400, letterSpacing: -0.5, color: cbInk),
      titleMedium: t.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0, color: cbInk),
      bodyLarge: t.bodyLarge?.copyWith(fontWeight: FontWeight.w400, color: cbInk),
      bodyMedium: t.bodyMedium?.copyWith(fontWeight: FontWeight.w400, color: cbBody),
      labelMedium: t.labelMedium?.copyWith(color: cbMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cbBlue,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: const SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(StadiumBorder()),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: cbCanvas,
      labelStyle: const TextStyle(color: cbMuted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cbHairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cbBlue, width: 2),
      ),
    ),
  );
}
