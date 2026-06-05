import 'dart:math' as math;

import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Учебный блок к урокам про портфель/диверсификацию: интерактивный пирог.
/// Пользователь двигает доли (акции / облигации / золото), пирог
/// перерисовывается, а индикатор «устойчивость» растёт, когда добавляешь
/// спокойную часть. Показывает, как состав влияет на размах просадки.
class LessonAllocationPie extends StatefulWidget {
  const LessonAllocationPie({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonAllocationPie> createState() => _LessonAllocationPieState();
}

class _LessonAllocationPieState extends State<LessonAllocationPie> {
  double _stocks = 60;
  double _bonds = 30;
  double _gold = 10;

  double get _total => _stocks + _bonds + _gold;

  // Грубо: акции волатильнее, облигации/золото гасят размах.
  double get _drawdown {
    final t = _total <= 0 ? 1 : _total;
    final s = _stocks / t;
    final b = _bonds / t;
    final g = _gold / t;
    return (s * 45 + b * 8 + g * 18).clamp(0, 45);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = _total <= 0 ? 1 : _total;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: _PiePainter(
                fractions: [_stocks / t, _bonds / t, _gold / t],
                colors: [widget.tint, AppColors.success, const Color(0xFFE6B450)],
                bg: scheme.surface,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'просадка',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '~−${_drawdown.round()}%',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _drawdown > 25
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _AllocSlider(
            label: 'Акции',
            value: _stocks,
            color: widget.tint,
            onChanged: (v) => setState(() => _stocks = v),
          ),
          _AllocSlider(
            label: 'Облигации',
            value: _bonds,
            color: AppColors.success,
            onChanged: (v) => setState(() => _bonds = v),
          ),
          _AllocSlider(
            label: 'Золото',
            value: _gold,
            color: const Color(0xFFE6B450),
            onChanged: (v) => setState(() => _gold = v),
          ),
          Text(
            'Больше спокойной части (облигации, золото) — меньше размах '
            'просадки, но и потолок роста ниже.',
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

class _AllocSlider extends StatelessWidget {
  const _AllocSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text(label, style: text.bodySmall),
            ],
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            max: 100,
            activeColor: color,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${value.round()}',
            textAlign: TextAlign.right,
            style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.fractions, required this.colors, required this.bg});

  final List<double> fractions;
  final List<Color> colors;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    var start = -math.pi / 2;
    for (var i = 0; i < fractions.length; i++) {
      final sweep = fractions[i] * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = colors[i],
      );
      start += sweep;
    }
    // Дырка под подпись.
    canvas.drawCircle(center, radius * 0.58, Paint()..color = bg);
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.fractions[0] != fractions[0] ||
      old.fractions[1] != fractions[1] ||
      old.fractions[2] != fractions[2];
}
