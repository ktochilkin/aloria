// ignore_for_file: avoid_classes_with_only_static_members

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF5D8CFF); // lighter hero blue
  static const secondary = Color(0xFFFF9E7C); // softer coral accent
  static const background = Color(0xFFE9F0FF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF1F5FF);
  static const outline = Color(0xFFB5C6F5);
  static const onPrimary = Color(0xFF0B1630);
  static const onSecondary = Color(0xFF3B1C10);
  static const onSurface = Color(0xFF0B1224);
  static const onSurfaceVariant = Color(0xFF44506A);
  static const success = Color(0xFF37B38A);
  static const warning = Color(0xFFF5C24D);
  static const error = Color(0xFFF16B82);
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
