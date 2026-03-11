import 'package:flutter/material.dart';

/// Константа высоты навигационной панели (должна совпадать с navigationBarTheme.height в app_theme.dart)
const double kNavigationBarHeight = 72.0;

/// Возвращает безопасный отступ снизу с учетом высоты навигационной панели
/// Использовать для padding в ScrollView и ListView
double getBottomPaddingWithNavBar(BuildContext context) {
  // Теперь используем обычный отступ везде, т.к. extendBody отключен
  return 16.0;
}

/// Extension для удобного доступа к padding
extension LayoutExtension on BuildContext {
  /// Безопасный отступ снизу для контента с навигационной панелью
  double get bottomNavBarPadding => getBottomPaddingWithNavBar(this);
}
