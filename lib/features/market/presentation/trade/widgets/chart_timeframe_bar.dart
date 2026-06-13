import 'package:aloria/features/market/application/price_feed_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Сегментный переключатель таймфрейма графика. Пишет выбор в
/// [chartTimeframeProvider]; нотифаер ленты реагирует на него и точечно
/// перезагружает свечи (цена и стакан не трогаются).
class ChartTimeframeBar extends ConsumerWidget {
  const ChartTimeframeBar({super.key, required this.symbol});

  /// Тикер инструмента — ключ выбора таймфрейма.
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final selected = ref.watch(chartTimeframeProvider(symbol));

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final tf in kChartTimeframes)
            Expanded(
              child: _Segment(
                label: tf.label,
                selected: tf.code == selected,
                onTap: () => ref
                    .read(chartTimeframeProvider(symbol).notifier)
                    .state = tf.code,
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
