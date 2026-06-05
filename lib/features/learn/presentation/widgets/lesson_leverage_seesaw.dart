import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Учебный блок к уроку про плечо: слайдер плеча 1×…3× синхронно усиливает
/// обе стороны. Актив сходил на ±5% — твой результат на ±(5×плечо)%. Показывает,
/// что плечо усиливает прибыль и убыток в равной мере.
class LessonLeverageSeesaw extends StatefulWidget {
  const LessonLeverageSeesaw({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonLeverageSeesaw> createState() => _LessonLeverageSeesawState();
}

class _LessonLeverageSeesawState extends State<LessonLeverageSeesaw> {
  static const double _assetMove = 5;
  double _leverage = 1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final yours = _assetMove * _leverage;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          const _Bar(
            label: 'актив сходил на',
            value: _assetMove,
            max: 15,
            muted: true,
          ),
          const SizedBox(height: 12),
          _Bar(label: 'твой результат', value: yours, max: 15, muted: false),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.expand, size: 16, color: widget.tint),
              const SizedBox(width: 6),
              Text(
                'Плечо',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '${_leverage.toStringAsFixed(0)}×',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: widget.tint,
                ),
              ),
            ],
          ),
          Slider(
            value: _leverage,
            min: 1,
            max: 3,
            divisions: 2,
            activeColor: widget.tint,
            onChanged: (v) => setState(() => _leverage = v),
          ),
          Text(
            'И прибыль, и убыток растут в ${_leverage.toStringAsFixed(0)} раза — '
            'плечо усиливает обе стороны одинаково.',
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

/// Симметричная пара полос: вверх (прибыль) и вниз (убыток) на одну величину.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.max,
    required this.muted,
  });

  final String label;
  final double value;
  final double max;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final frac = (value / max).clamp(0.0, 1.0);
    final up = muted
        ? AppColors.success.withValues(alpha: 0.4)
        : AppColors.success;
    final down =
        muted ? AppColors.error.withValues(alpha: 0.4) : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _Half(
                frac: frac,
                color: up,
                text: '+${value.toStringAsFixed(0)}%',
                alignEnd: false,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _Half(
                frac: frac,
                color: down,
                text: '−${value.toStringAsFixed(0)}%',
                alignEnd: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({
    required this.frac,
    required this.color,
    required this.text,
    required this.alignEnd,
  });

  final double frac;
  final Color color;
  final String text;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: alignEnd ? Alignment.centerLeft : Alignment.centerRight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 30,
        width: (frac * 120).clamp(34, 120),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color),
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(alignEnd ? 0 : 8),
            right: Radius.circular(alignEnd ? 8 : 0),
          ),
        ),
        child: Text(
          text,
          style: t.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
