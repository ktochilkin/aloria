import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Учебный блок к уроку про риск: слайдер «уровень риска» раздвигает вилку
/// возможных исходов симметрично в обе стороны — из одной точки «старт»
/// расходятся две линии: вверх (+%) и вниз (−%). Показывает, что больше
/// риска — это шире и вверх, и вниз, а не просто «больше шанс проиграть».
class LessonRiskFork extends StatefulWidget {
  const LessonRiskFork({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonRiskFork> createState() => _LessonRiskForkState();
}

class _LessonRiskForkState extends State<LessonRiskFork> {
  double _risk = 0.2;

  double get _spread => 4 + _risk * 56; // ±4% … ±60%

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 2.1,
            child: CustomPaint(
              painter: _ForkPainter(
                frac: (spread / 60).clamp(0.0, 1.0),
                spread: spread,
                up: AppColors.success,
                down: AppColors.error,
                axis: scheme.outlineVariant,
                labelStyle: text.labelLarge!.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                startStyle: text.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.tune, size: 16, color: widget.tint),
              const SizedBox(width: 6),
              Text(
                'Уровень риска',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  _label,
                  textAlign: TextAlign.right,
                  style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: widget.tint,
                  ),
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

class _ForkPainter extends CustomPainter {
  _ForkPainter({
    required this.frac,
    required this.spread,
    required this.up,
    required this.down,
    required this.axis,
    required this.labelStyle,
    required this.startStyle,
  });

  final double frac;
  final double spread;
  final Color up;
  final Color down;
  final Color axis;
  final TextStyle labelStyle;
  final TextStyle startStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 54.0;
    const rightPad = 64.0;
    final midY = size.height / 2;
    final start = Offset(leftPad, midY);
    final endX = size.width - rightPad;
    final reach = (midY - 14) * frac;
    final topEnd = Offset(endX, midY - reach);
    final botEnd = Offset(endX, midY + reach);

    // Базовая линия (старт).
    final axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(leftPad, midY), Offset(endX, midY), axisPaint);

    // Заливка вилки.
    final fill = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(topEnd.dx, topEnd.dy)
      ..lineTo(botEnd.dx, botEnd.dy)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = up.withValues(alpha: 0.06),
    );

    // Верхняя ветка (зелёная).
    canvas.drawLine(
      start,
      topEnd,
      Paint()
        ..color = up
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    // Нижняя ветка (красная).
    canvas.drawLine(
      start,
      botEnd,
      Paint()
        ..color = down
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Точка старта.
    canvas.drawCircle(start, 5, Paint()..color = axis);
    _text(canvas, 'старт', startStyle, Offset(4, midY - 7));

    // Подписи на концах.
    _text(canvas, '+${spread.round()}%', labelStyle.copyWith(color: up),
        Offset(endX + 8, topEnd.dy - 9));
    _text(canvas, '−${spread.round()}%', labelStyle.copyWith(color: down),
        Offset(endX + 8, botEnd.dy - 9));
  }

  void _text(Canvas canvas, String s, TextStyle style, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_ForkPainter old) => old.frac != frac;
}
