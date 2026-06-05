import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Учебный блок к уроку про инфляцию: «таяние денег». Сумма на счёте та же,
/// но покупательная способность с годами тает. Слайдер лет — реальная
/// стоимость сжимается. Для урока про инфляцию.
class LessonInflationErosion extends StatefulWidget {
  const LessonInflationErosion({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonInflationErosion> createState() =>
      _LessonInflationErosionState();
}

class _LessonInflationErosionState extends State<LessonInflationErosion> {
  static const double _amount = 1000;
  static const double _rate = 0.07; // 7% в год
  double _years = 0;

  double get _real {
    var v = _amount;
    for (var i = 0; i < _years.round(); i++) {
      v *= 1 - _rate;
    }
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final real = _real;
    final lostPct = (1 - real / _amount) * 100;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MoneyBar(
            label: 'на счёте',
            value: _amount,
            frac: 1,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          _MoneyBar(
            label: 'реально можно купить',
            value: real,
            frac: real / _amount,
            color: real / _amount < 0.6 ? AppColors.error : widget.tint,
            animate: true,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: widget.tint),
              const SizedBox(width: 6),
              Text(
                'Прошло лет',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '${_years.round()}',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Slider(
            value: _years,
            max: 20,
            divisions: 20,
            activeColor: widget.tint,
            onChanged: (v) => setState(() => _years = v),
          ),
          Text(
            'Сумма та же, но за ${_years.round()} лет инфляция 7% в год съела '
            '${lostPct.round()}% покупательной способности.',
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

class _MoneyBar extends StatelessWidget {
  const _MoneyBar({
    required this.label,
    required this.value,
    required this.frac,
    required this.color,
    this.animate = false,
  });

  final String label;
  final double value;
  final double frac;
  final Color color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
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
              '${value.round()} ₽',
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: 18, color: scheme.surface),
              AnimatedFractionallySizedBox(
                duration: Duration(milliseconds: animate ? 250 : 0),
                widthFactor: frac.clamp(0.02, 1),
                child: Container(height: 18, color: color.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
