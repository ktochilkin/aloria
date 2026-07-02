import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/presentation/numeric_text.dart';
import 'package:flutter/material.dart';

/// «Индекс Алории» — простой барометр рынка из средней дневной динамики бумаг.
/// Прототип: без истории/спарклайна; живым станет с ИИ-режиссёром.
class AloriaIndexCard extends StatelessWidget {
  const AloriaIndexCard({super.key, required this.securities});

  final List<MarketSecurity> securities;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final priced = securities.where((s) => s.changePercent != null).toList();
    if (priced.isEmpty) return const SizedBox.shrink();

    final avg =
        priced.map((s) => s.changePercent!).reduce((a, b) => a + b) /
        priced.length;
    final up = avg >= 0;
    final color = up ? AppColors.success : AppColors.error;
    final mood = avg.abs() < 0.1
        ? 'около нуля'
        : (up ? 'рынок растёт' : 'рынок снижается');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.show_chart_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Индекс Алории',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mood,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${up ? '+' : ''}${avg.toStringAsFixed(2)}%',
              style: monoNum(size: 18, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
