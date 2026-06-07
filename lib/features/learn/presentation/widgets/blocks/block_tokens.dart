// ignore_for_file: avoid_classes_with_only_static_members

// Токены дизайн-системы учебных блоков. Направление — «светлый
// премиум-финтех, ВОЗДУХ» (см. память project_block_design_system): белая
// карта, мягкая нейтральная диффузная тень, без подложки и обводки, крупный
// радиус, много воздуха, акцент дозированно.
// Поверх core/theme (ColorScheme, AppColors, AppTypography): здесь только то,
// чего нет в ядре — шкала отступов, радиусы, тени, палитра графиков, движение.
//
// Правило: в блоках использовать ТОЛЬКО эти значения. Хочется новое число —
// сначала проверь, нет ли подходящего тут; новый токен заводим осознанно.
import 'package:flutter/material.dart';

/// Шкала отступов (4-точечная сетка). Между элементами блока — `m`/`l`,
/// мелкие зазоры — `xs`/`s`, крупные секции — `xl`.
abstract final class BlockSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
}

/// Радиусы скругления. `card` — внешняя карточка блока, `inner` — вложенные
/// плашки/чипы/кнопки внутри неё.
abstract final class BlockRadii {
  static const double card = 20;
  static const double inner = 12;

  static const BorderRadius cardBr = BorderRadius.all(Radius.circular(card));
  static const BorderRadius innerBr = BorderRadius.all(Radius.circular(inner));
}

/// Длительности и кривые анимаций. Вход — мягкое появление; морфинг —
/// перестроение содержимого; chart — рост графика.
abstract final class BlockMotion {
  static const Duration enter = Duration(milliseconds: 350);
  static const Duration morph = Duration(milliseconds: 800);
  static const Duration chart = Duration(milliseconds: 800);
  static const Curve curve = Curves.easeOutCubic;

  /// Смещение появления (slideY) — доля высоты.
  static const double enterSlide = 0.06;
}

/// Тени «воздуха»: мягкая нейтральная диффузная тень под белой картой. На
/// тёмной теме тени читаются плохо — гасим, отделяет карту тонкая рамка
/// (см. LessonBlockCard).
abstract final class BlockShadow {
  static List<BoxShadow> card(Brightness brightness) {
    if (brightness == Brightness.dark) return const [];
    return const [
      BoxShadow(
        color: Color(0x14000000), // black @ ~0.08
        blurRadius: 24,
        spreadRadius: -6,
        offset: Offset(0, 12),
      ),
    ];
  }
}

/// Помощники по работе с акцентом (`tint` приходит в каждый блок).
abstract final class BlockTint {
  /// Поверхность карточки «воздуха» — чистый surface (белый в светлой теме),
  /// без акцент-подложки: карта держится тенью и светлотой на фоне страницы.
  static Color cardSurface(ColorScheme scheme) => scheme.surface;

  /// Заливка мягкого чипа/плашки (например, результат-акцент).
  static Color soft(Color tint) => tint.withValues(alpha: 0.14);
}

/// Палитра графиков: акцент (приходит как tint) + семантика + нейтраль/сетка.
abstract final class BlockChartColors {
  static const Color success = Color(0xFF37B38A);
  static const Color error = Color(0xFFF16B82);

  /// Цвет линии сетки (от темы).
  static Color grid(ColorScheme scheme) =>
      scheme.outlineVariant.withValues(alpha: 0.35);

  /// Нейтральная (вторая) линия — пунктир/сравнение.
  static Color neutral(ColorScheme scheme) =>
      scheme.onSurfaceVariant.withValues(alpha: 0.5);

  /// Верхняя/нижняя прозрачность градиент-заливки под линией («воздух» —
  /// дозированная, лёгкая заливка).
  static const double fillTopAlpha = 0.18;
  static const double fillBottomAlpha = 0.0;
}
