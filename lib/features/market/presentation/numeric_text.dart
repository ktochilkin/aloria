import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Стиль для финансовых чисел: Nunito с табличными цифрами (`tabularFigures`).
/// Тот же дружелюбный шрифт, что и весь текст приложения — но цифры одной
/// ширины, поэтому цены/объёмы выравниваются в колонки и «не пляшут» при
/// обновлении. Современнее моноширинного «терминального» шрифта.
TextStyle monoNum({
  required double size,
  FontWeight weight = FontWeight.w600,
  Color? color,
}) =>
    GoogleFonts.nunito(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
