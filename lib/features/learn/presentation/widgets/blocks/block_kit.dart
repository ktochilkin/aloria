import 'package:aloria/features/learn/presentation/widgets/blocks/block_tokens.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

export 'package:aloria/features/learn/presentation/widgets/blocks/block_tokens.dart';

/// Набор переиспользуемых кирпичей учебных блоков в стиле «тёплый акцент».
/// Все блоки уроков собираются из этих примитивов — никакой ручной вёрстки
/// карточек/слайдеров/графиков с нуля. Токены — в block_tokens.dart.

/// Единая обёртка блока: тёплая акцент-подложка, мягкая цветная тень, радиус
/// 18. Слоты заголовка/подзаголовка/футера опциональны. Появляется с лёгким
/// fade+slide ([blockEntrance]).
class LessonBlockCard extends StatelessWidget {
  const LessonBlockCard({
    super.key,
    required this.tint,
    required this.child,
    this.title,
    this.subtitle,
    this.footer,
    this.padding = 20,
    this.animateEntrance = true,
  });

  final Color tint;
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? footer;
  final double padding;
  final bool animateEntrance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final card = Container(
      decoration: BoxDecoration(
        color: BlockTint.cardSurface(scheme),
        borderRadius: BlockRadii.cardBr,
        // На белом холсте карту отделяет тонкая линия + мягкая тень;
        // на тёмной теме — только линия (тени не читаются).
        border: Border.all(
          color: scheme.brightness == Brightness.dark
              ? scheme.outlineVariant.withValues(alpha: 0.4)
              : scheme.outline.withValues(alpha: 0.6),
        ),
        boxShadow: BlockShadow.card(scheme.brightness),
      ),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: BlockSpacing.xs),
            Text(
              subtitle!,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (title != null || subtitle != null)
            const SizedBox(height: BlockSpacing.l),
          child,
          if (footer != null) ...[
            const SizedBox(height: BlockSpacing.l),
            footer!,
          ],
        ],
      ),
    );

    return animateEntrance ? card.blockEntrance() : card;
  }
}

/// Слайдер с инлайн-подписью значения и тактильным откликом. Подпись значения
/// рисуется акцентом справа от label.
class BlockSlider extends StatelessWidget {
  const BlockSlider({
    super.key,
    required this.tint,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  final Color tint;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text(
              valueLabel,
              style: text.labelMedium
                  ?.copyWith(color: tint, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: tint,
            thumbColor: tint,
            overlayColor: tint.withValues(alpha: 0.12),
            inactiveTrackColor: scheme.outlineVariant.withValues(alpha: 0.5),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

/// Кнопка действия блока (обёртка над FilledButton в акценте). По умолчанию
/// во всю ширину — основное действие блока («запустить», «проиграть»).
class BlockButton extends StatelessWidget {
  const BlockButton({
    super.key,
    required this.tint,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
  });

  final Color tint;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: tint,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: BlockSpacing.l),
      shape: const RoundedRectangleBorder(borderRadius: BlockRadii.innerBr),
    );
    final button = icon != null
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : FilledButton(onPressed: onPressed, style: style, child: Text(label));
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Тон чипа-результата.
enum BlockTone { accent, success, error, neutral }

/// Чип-результат: залитая плашка (стиль «тёплый акцент»). Тон задаёт цвет.
class BlockChip extends StatelessWidget {
  const BlockChip({
    super.key,
    required this.text,
    required this.tint,
    this.tone = BlockTone.accent,
  });

  final String text;
  final Color tint;
  final BlockTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // «Воздух»: мягкая тонированная плашка + цветной текст (не залитая).
    final base = switch (tone) {
      BlockTone.accent => tint,
      BlockTone.success => BlockChartColors.success,
      BlockTone.error => BlockChartColors.error,
      BlockTone.neutral => null,
    };
    final bg = base == null
        ? scheme.surfaceContainerHighest
        : base.withValues(alpha: 0.14);
    final fg = base ?? scheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BlockSpacing.m, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BlockRadii.innerBr),
      child: Text(
        text,
        style: textTheme.labelMedium
            ?.copyWith(color: fg, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Метрика: подпись сверху + значение снизу. Значение можно подкрасить.
class BlockMetric extends StatelessWidget {
  const BlockMetric({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

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
        Text(
          value,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color ?? scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Крупное число с подписью — для блока-акцента на одной цифре.
class NumberAccent extends StatelessWidget {
  const NumberAccent({
    super.key,
    required this.value,
    required this.label,
    required this.tint,
  });

  final String value;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: text.titleMedium
              ?.copyWith(fontSize: 34, fontWeight: FontWeight.w800, color: tint),
        ),
        Text(
          label,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Строка-легенда: набор цветных маркеров с подписями.
class BlockLegend extends StatelessWidget {
  const BlockLegend({super.key, required this.items});

  /// Пары (цвет, подпись).
  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: BlockSpacing.l,
      runSpacing: BlockSpacing.s,
      children: [
        for (final (color, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: BlockSpacing.s),
              Text(
                label,
                style:
                    text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
      ],
    );
  }
}

/// Линейный график в домашнем стиле: гладкая акцент-линия с градиент-заливкой,
/// сетка только по горизонтали, без рамки, без тач-обработки. Все линейные
/// графики блоков строятся через эту функцию.
LineChartData blockLineChart({
  required BuildContext context,
  required Color tint,
  required List<FlSpot> spots,
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
  double? bottomInterval,
  String Function(double)? bottomLabel,
  List<FlSpot>? compareSpots,
  bool fill = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;
  return LineChartData(
    minX: minX,
    maxX: maxX,
    minY: minY,
    maxY: maxY,
    gridData: FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: BlockChartColors.grid(scheme), strokeWidth: 1),
    ),
    titlesData: FlTitlesData(
      leftTitles: const AxisTitles(),
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: bottomInterval != null,
          interval: bottomInterval,
          getTitlesWidget: (v, meta) => Text(
            bottomLabel?.call(v) ?? '${v.toInt()}',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    ),
    borderData: FlBorderData(show: false),
    lineTouchData: const LineTouchData(enabled: false),
    lineBarsData: [
      if (compareSpots != null)
        LineChartBarData(
          spots: compareSpots,
          color: BlockChartColors.neutral(scheme),
          dashArray: const [5, 4],
          dotData: const FlDotData(show: false),
        ),
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: tint,
        barWidth: 3.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: fill,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tint.withValues(alpha: BlockChartColors.fillTopAlpha),
              tint.withValues(alpha: BlockChartColors.fillBottomAlpha),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Появление блока: мягкий fade + лёгкий подъём. Применять к корню блока.
extension BlockEntrance on Widget {
  Widget blockEntrance() => animate()
      .fadeIn(duration: BlockMotion.enter)
      .slideY(begin: BlockMotion.enterSlide, curve: BlockMotion.curve);
}
