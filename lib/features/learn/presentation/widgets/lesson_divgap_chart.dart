import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Учебный блок к уроку про дивиденды: график дивидендного гэпа. Цена идёт
/// ровно, а на следующий торговый день после «последнего дня с дивидендом»
/// проседает примерно на размер выплаты. Собран на block_kit («воздух»);
/// сам график — кастомный painter (нужен видимый разрыв линии и пунктир гэпа,
/// чего гладкая линия не передаёт).
class LessonDivGapChart extends StatelessWidget {
  const LessonDivGapChart({super.key, required this.tint});

  final Color tint;

  // (день, цена). Между индексами 5 и 6 — дивидендный гэп ~8 ₽.
  static const _points = <double>[
    100, 100.5, 99.8, 100.2, 100.0, 100.3, // до отсечки
    92.3, 92.1, 92.6, 92.2, 92.5, // после гэпа
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LessonBlockCard(
      tint: tint,
      title: 'Дивидендный гэп',
      subtitle: 'Компания не стала хуже — часть стоимости просто ушла из неё '
          'деньгами в виде дивиденда.',
      child: AspectRatio(
        aspectRatio: 1.7,
        child: CustomPaint(
          painter: _DivGapPainter(
            points: _points,
            gapIndex: 5,
            line: tint,
            drop: BlockChartColors.error,
            grid: BlockChartColors.grid(scheme),
            labelStyle: text.bodySmall!.copyWith(
              color: BlockChartColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DivGapPainter extends CustomPainter {
  _DivGapPainter({
    required this.points,
    required this.gapIndex,
    required this.line,
    required this.drop,
    required this.grid,
    required this.labelStyle,
  });

  final List<double> points;
  final int gapIndex;
  final Color line;
  final Color drop;
  final Color grid;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const maxV = 102.0;
    const minV = 90.0;
    final n = points.length - 1;

    Offset at(int i) {
      final x = size.width * (i / n);
      final y = size.height * (1 - (points[i] - minV) / (maxV - minV));
      return Offset(x, y);
    }

    // Сетка.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Линия цены до отсечки.
    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final before = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i <= gapIndex; i++) {
      before.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(before, linePaint);

    // Линия после гэпа.
    final after = Path()..moveTo(at(gapIndex + 1).dx, at(gapIndex + 1).dy);
    for (var i = gapIndex + 2; i <= n; i++) {
      after.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(after, linePaint);

    // Сам гэп — пунктирная вертикаль вниз.
    final g1 = at(gapIndex);
    final g2 = at(gapIndex + 1);
    final dropPaint = Paint()
      ..color = drop
      ..strokeWidth = 2;
    var y = g1.dy;
    while (y < g2.dy) {
      canvas.drawLine(Offset(g2.dx, y), Offset(g2.dx, (y + 5).clamp(0, g2.dy)),
          dropPaint);
      y += 9;
    }
    canvas.drawCircle(g1, 4, Paint()..color = line);
    canvas.drawCircle(g2, 4, Paint()..color = drop);

    final tp = TextPainter(
      text: TextSpan(text: '−дивиденд', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(g2.dx - tp.width - 6, (g1.dy + g2.dy) / 2 - 8));
  }

  @override
  bool shouldRepaint(_DivGapPainter old) => false;
}
