import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// === ЭКСПЕРИМЕНТ: дизайн-система Coinbase, локально на торговом экране ===
// Холст текущей темы, единственный акцент Coinbase Blue (только primary-CTA),
// чернильный текст + серый body, hairline-границы вместо теней, карты r24,
// кнопки-пилюли, числа моноширинным, торговые зелёный/красный только как текст.
// Применяется через scoped Theme только на торговом экране — остальное
// приложение не затрагивается. Цвета берутся из AppPalette текущего режима,
// поэтому тёмная тема работает так же, как в остальном приложении.

/// Brand voltage — только primary-CTA.
const cbBlue = AppColors.primary;

/// Подписи/мьютед (средний серый — читается на обоих холстах).
const cbMuted = TradeColors.muted;

/// Semantic up (только текст).
const cbUp = TradeColors.up;

/// Semantic down (только текст).
const cbDown = TradeColors.down;

/// Стиль чисел: Nunito с табличными цифрами (одна ширина → ровные колонки),
/// современнее моноширинного «терминального» шрифта. Без [color] цвет
/// наследуется от окружающего стиля текста (тон текущей темы).
TextStyle cbMono({
  required double size,
  FontWeight weight = FontWeight.w600,
  Color? color,
}) => GoogleFonts.nunito(
  fontSize: size,
  fontWeight: weight,
  color: color,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Scoped-тема торгового экрана поверх базовой темы приложения.
/// Ink/body/hairline/canvas берутся из палитры активного режима (свет/тьма).
ThemeData coinbaseTheme(BuildContext context) {
  final base = Theme.of(context);
  final t = base.textTheme;
  final p = context.palette;
  final ink = p.onSurface;
  final body = p.onSurfaceVariant;
  final hairline = p.outline;
  final canvas = p.background;
  final surfaceStrong = p.surfaceVariant;

  return base.copyWith(
    scaffoldBackgroundColor: canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: cbBlue,
      onPrimary: Colors.white,
      surface: canvas,
      onSurface: ink,
      onSurfaceVariant: body,
      surfaceContainerHighest: surfaceStrong,
      outline: hairline,
      outlineVariant: hairline,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
    ),
    // Coinbase: плоско, hairline-граница вместо тени, радиус 24.
    cardTheme: CardThemeData(
      color: canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        side: BorderSide(color: hairline),
      ),
    ),
    dividerTheme: DividerThemeData(color: hairline, thickness: 1),
    textTheme: t.copyWith(
      headlineMedium: t.headlineMedium?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: -1,
        color: ink,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: -0.5,
        color: ink,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: ink,
      ),
      bodyLarge: t.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodyMedium: t.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        color: body,
      ),
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
      style: ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: canvas,
      labelStyle: const TextStyle(color: cbMuted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cbBlue, width: 2),
      ),
    ),
  );
}
