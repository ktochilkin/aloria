import 'package:flutter/material.dart';

/// Пустое состояние секции портфеля (нет позиций / нет заявок) —
/// скруглённая карточка с поясняющим текстом.
class PortfolioEmptyCard extends StatelessWidget {
  const PortfolioEmptyCard({super.key, required this.text});

  /// Поясняющий текст.
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
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
