import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/domain/macro_state.dart';
import 'package:aloria/features/market/presentation/numeric_text.dart';
import 'package:flutter/material.dart';

/// Человекочитаемое имя режима цикла + акцентный цвет.
({String label, Color color}) macroRegimeMeta(String regime) => switch (regime) {
  'expansion' => (label: 'Расширение', color: AppColors.success),
  'peak' => (label: 'Перегрев', color: AppColors.warning),
  'recession' => (label: 'Рецессия', color: AppColors.error),
  'recovery' => (label: 'Восстановление', color: AppColors.primary),
  _ => (label: regime, color: AppColors.secondary),
};

/// Карточка макроэкономики на обзоре рынка: режим цикла, ставка, инфляция,
/// прогресс экономического цикла. По тапу ([onTap]) открывает пояснение.
/// При [useCard] = false рисуется без обёртки [Card] — поверхность даёт внешний
/// контейнер (например, OpenContainer при раскрытии в экран).
class MacroCard extends StatelessWidget {
  const MacroCard({
    super.key,
    required this.state,
    this.onTap,
    this.useCard = true,
  });

  final MacroState state;
  final VoidCallback? onTap;
  final bool useCard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final meta = macroRegimeMeta(state.regime);
    final progress = state.cycleLength > 0
        ? state.cycleDay.clamp(0, state.cycleLength) / state.cycleLength
        : 0.0;

    final inner = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Макроэкономика',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                _RegimeBadge(label: meta.label, color: meta.color),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Ключевая ставка',
                    value: '${_fmt(state.keyRate)}%',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Инфляция',
                    value: '${_fmt(state.inflation)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Цикл',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'день ${state.cycleDay} из ${state.cycleLength}',
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                color: meta.color,
              ),
            ),
          ],
        ),
      ),
    );

    if (!useCard) return inner;
    return Card(margin: EdgeInsets.zero, child: inner);
  }

  static String _fmt(double v) =>
      v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
}

class _RegimeBadge extends StatelessWidget {
  const _RegimeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: text.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(value, style: monoNum(size: 18)),
      ],
    );
  }
}
