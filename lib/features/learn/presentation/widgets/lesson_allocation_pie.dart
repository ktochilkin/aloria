import 'dart:math' as math;

import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Учебный блок к урокам про портфель/диверсификацию: интерактивный пирог.
/// Пользователь двигает доли (акции / облигации / золото), пирог
/// перерисовывается, а индикатор «устойчивость» растёт, когда добавляешь
/// спокойную часть. Показывает, как состав влияет на размах просадки.
/// Собран на block_kit (стиль «воздух»): карточка-обёртка, слайдеры —
/// BlockSlider, легенда — BlockLegend; пирог рисуется своим painter'ом.
class LessonAllocationPie extends StatefulWidget {
  const LessonAllocationPie({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonAllocationPie> createState() => _LessonAllocationPieState();
}

class _LessonAllocationPieState extends State<LessonAllocationPie> {
  static const Color _gold = Color(0xFFE6B450);

  double _stocks = 60;
  double _bonds = 30;
  double _goldShare = 10;

  double get _total => _stocks + _bonds + _goldShare;

  // Грубо: акции волатильнее, облигации/золото гасят размах.
  double get _drawdown {
    final t = _total <= 0 ? 1 : _total;
    final s = _stocks / t;
    final b = _bonds / t;
    final g = _goldShare / t;
    return (s * 45 + b * 8 + g * 18).clamp(0, 45);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = _total <= 0 ? 1 : _total;
    const bondsColor = BlockChartColors.success;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Состав портфеля',
      subtitle: 'Больше спокойной части (облигации, золото) — меньше размах '
          'просадки, но и потолок роста ниже.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: _PiePainter(
                fractions: [_stocks / t, _bonds / t, _goldShare / t],
                colors: [widget.tint, bondsColor, _gold],
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
                            ? BlockChartColors.error
                            : BlockChartColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          BlockLegend(items: [
            (widget.tint, 'акции'),
            (bondsColor, 'облигации'),
            (_gold, 'золото'),
          ]),
          const SizedBox(height: BlockSpacing.m),
          BlockSlider(
            tint: widget.tint,
            label: 'Акции',
            valueLabel: '${_stocks.round()}',
            value: _stocks,
            min: 0,
            max: 100,
            onChanged: (v) => setState(() => _stocks = v),
          ),
          BlockSlider(
            tint: bondsColor,
            label: 'Облигации',
            valueLabel: '${_bonds.round()}',
            value: _bonds,
            min: 0,
            max: 100,
            onChanged: (v) => setState(() => _bonds = v),
          ),
          BlockSlider(
            tint: _gold,
            label: 'Золото',
            valueLabel: '${_goldShare.round()}',
            value: _goldShare,
            min: 0,
            max: 100,
            onChanged: (v) => setState(() => _goldShare = v),
          ),
        ],
      ),
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
