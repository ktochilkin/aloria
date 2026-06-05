import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Учебный блок к уроку про риск: слайдер «уровень риска» раздвигает вилку
/// возможных исходов симметрично в обе стороны. Показывает, что больше риска —
/// это шире диапазон и вверх, и вниз, а не просто «больше шанс проиграть».
class LessonRiskFork extends StatefulWidget {
  const LessonRiskFork({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonRiskFork> createState() => _LessonRiskForkState();
}

class _LessonRiskForkState extends State<LessonRiskFork> {
  // 0 = вклад/ОФЗ, 1 = агрессивные акции.
  double _risk = 0.2;

  // Возможный размах исхода (±%) при текущем уровне риска.
  double get _spread => 4 + _risk * 56; // от ±4% до ±60%

  String get _label {
    if (_risk < 0.25) return 'Депозит, короткие ОФЗ';
    if (_risk < 0.6) return 'Голубые фишки, фонды';
    return 'Малые компании, агрессивные акции';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final spread = _spread;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          SizedBox(
            height: 170,
            child: _ForkView(spread: spread, maxSpread: 60),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.tune, size: 16, color: widget.tint),
              const SizedBox(width: 6),
              Text(
                'Уровень риска',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                _label,
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: widget.tint,
                ),
              ),
            ],
          ),
          Slider(
            value: _risk,
            divisions: 20,
            activeColor: widget.tint,
            onChanged: (v) => setState(() => _risk = v),
          ),
          Text(
            'Диапазон исхода: от −${spread.round()}% до +${spread.round()}%. '
            'Больше риска — шире в обе стороны.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForkView extends StatelessWidget {
  const _ForkView({required this.spread, required this.maxSpread});

  final double spread;
  final double maxSpread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final frac = (spread / maxSpread).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, c) {
        final half = c.maxHeight / 2 - 16;
        final up = half * frac;
        final down = half * frac;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Центральная линия — старт.
            Positioned(
              left: 0,
              right: 0,
              child: Container(height: 2, color: scheme.outlineVariant),
            ),
            // Зелёная зона вверх.
            Align(
              child: Padding(
                padding: EdgeInsets.only(bottom: up),
                child: _Cap(
                  text: '+${spread.round()}%',
                  color: AppColors.success,
                  up: true,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.bottomCenter,
              margin: EdgeInsets.only(bottom: half),
              width: 60,
              height: up,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.success.withValues(alpha: 0.05),
                    AppColors.success.withValues(alpha: 0.35),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
            ),
            // Красная зона вниз.
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.topCenter,
              margin: EdgeInsets.only(top: half),
              width: 60,
              height: down,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.error.withValues(alpha: 0.05),
                    AppColors.error.withValues(alpha: 0.35),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
              ),
            ),
            Align(
              child: Padding(
                padding: EdgeInsets.only(top: down),
                child: _Cap(
                  text: '−${spread.round()}%',
                  color: AppColors.error,
                  up: false,
                ),
              ),
            ),
            // Подпись старта.
            Align(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                color: scheme.surface,
                child: Text(
                  'старт',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Cap extends StatelessWidget {
  const _Cap({required this.text, required this.color, required this.up});

  final String text;
  final Color color;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: t.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
