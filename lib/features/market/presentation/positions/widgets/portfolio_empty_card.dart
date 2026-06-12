import 'package:aloria/core/widgets/state_placeholder.dart';
import 'package:flutter/material.dart';

/// Пустое состояние секции портфеля (нет позиций / нет заявок).
class PortfolioEmptyCard extends StatelessWidget {
  const PortfolioEmptyCard({super.key, required this.text, this.icon});

  /// Поясняющий текст.
  final String text;

  /// Иконка состояния (по умолчанию — папка).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return StatePlaceholder(
      icon: icon ?? Icons.folder_open_outlined,
      title: text,
    );
  }
}

/// Лоадер секции портфеля — компактный спиннер по центру.
class PortfolioSectionLoader extends StatelessWidget {
  const PortfolioSectionLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        height: 56,
        width: 56,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
