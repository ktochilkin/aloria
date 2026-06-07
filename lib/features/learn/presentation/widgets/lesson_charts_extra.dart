import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Две почти слипшиеся линии (fl_chart): индекс и индексный фонд, который его
/// повторяет чуть ниже из-за комиссии. Для урока про индексные фонды.
///
/// Собран на block_kit (стиль «воздух»): карточка-обёртка [LessonBlockCard],
/// легенда — [BlockLegend], палитра графика — из кита. Оставлен на конфиге
/// fl_chart: смысл блока — две сплошные цветные линии, которые почти сливаются,
/// а [blockLineChart] рисует вторую кривую нейтральным пунктиром (потерялся бы
/// смысл «фонд почти повторяет индекс той же линией»).
class LessonIndexVsFund extends StatelessWidget {
  const LessonIndexVsFund({super.key, required this.tint});

  final Color tint;

  static const _index = <double>[100, 103, 101, 106, 110, 108, 114, 119];
  static const _fund = <double>[100, 102.7, 100.6, 105.3, 109, 107, 112.7, 117.4];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    List<FlSpot> spots(List<double> d) =>
        [for (var i = 0; i < d.length; i++) FlSpot(i.toDouble(), d[i])];

    LineChartBarData bar(List<double> d, Color c) => LineChartBarData(
          spots: spots(d),
          isCurved: true,
          color: c,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
        );

    return LessonBlockCard(
      tint: tint,
      title: 'Фонд повторяет индекс',
      subtitle: 'разница — это комиссия, она накапливается',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlockLegend(items: [
            (tint, 'индекс'),
            (BlockChartColors.success, 'фонд (−комиссия)'),
          ]),
          const SizedBox(height: BlockSpacing.m),
          AspectRatio(
            aspectRatio: 1.7,
            child: LineChart(
              LineChartData(
                minY: 96,
                maxY: 122,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 8,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: BlockChartColors.grid(scheme),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  bar(_index, tint),
                  bar(_fund, BlockChartColors.success),
                ],
              ),
              duration: BlockMotion.chart,
              curve: BlockMotion.curve,
            ),
          ),
        ],
      ),
    );
  }
}

/// Живой P&L: цена покупки — горизонтальная линия, рыночная цена анимированно
/// ходит, зона между ними подсвечивается зелёным/красным. Для урока про P&L.
///
/// Собран на block_kit (стиль «воздух»): карточка-обёртка [LessonBlockCard],
/// шапка с метрикой результата [BlockMetric]. График — кастомный
/// [_PnlPainter] (заливка зоны между ценой покупки и текущей ценой, смена цвета
/// при переходе через ноль), это не ложится в [blockLineChart], поэтому painter
/// оставлен в палитре кита.
class LessonPnlLive extends StatefulWidget {
  const LessonPnlLive({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonPnlLive> createState() => _LessonPnlLiveState();
}

class _LessonPnlLiveState extends State<LessonPnlLive>
    with SingleTickerProviderStateMixin {
  static const double _buy = 100;
  static const _path = <double>[
    100, 101, 99.5, 98, 99, 101.5, 103, 102, 104, 106.5, 105, 108,
  ];

  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )
      ..addListener(() => setState(() {}))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = _c.value;
    final pos = progress * (_path.length - 1);
    final i = pos.floor();
    final frac = pos - i;
    final price = i < _path.length - 1
        ? _path[i] + (_path[i + 1] - _path[i]) * frac
        : _path.last;
    final pnl = price - _buy;
    final up = pnl >= 0;

    return LessonBlockCard(
      tint: widget.tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BlockMetric(
                label: 'результат',
                value: 'куплено по ${_buy.toStringAsFixed(0)}',
              ),
              Text(
                '${up ? '+' : ''}${pnl.toStringAsFixed(1)} ₽',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: up
                          ? BlockChartColors.success
                          : BlockChartColors.error,
                    ),
              ),
            ],
          ),
          const SizedBox(height: BlockSpacing.s),
          AspectRatio(
            aspectRatio: 1.9,
            child: CustomPaint(
              painter: _PnlPainter(
                path: _path,
                buy: _buy,
                progress: progress,
                grid: BlockChartColors.grid(scheme),
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.s),
          Text(
            'Пока не продал — это «бумажный» результат: он всё время пляшет '
            'вместе с ценой.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _PnlPainter extends CustomPainter {
  _PnlPainter({
    required this.path,
    required this.buy,
    required this.progress,
    required this.grid,
  });

  final List<double> path;
  final double buy;
  final double progress;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final hi = path.reduce((a, b) => a > b ? a : b) + 1;
    final lo = path.reduce((a, b) => a < b ? a : b) - 1;
    final n = path.length - 1;
    double y(double v) => size.height * (1 - (v - lo) / (hi - lo));
    final buyY = y(buy);

    canvas.drawLine(
      Offset(0, buyY),
      Offset(size.width, buyY),
      Paint()
        ..color = grid
        ..strokeWidth = 1.5,
    );

    final shown = n * progress;
    final full = shown.floor();
    Offset pt(int i) => Offset(size.width * i / n, y(path[i]));

    final linePath = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i <= full; i++) {
      linePath.lineTo(pt(i).dx, pt(i).dy);
    }
    Offset tip;
    if (full < n) {
      final f = shown - full;
      final a = pt(full);
      final b = pt(full + 1);
      tip = Offset(a.dx + (b.dx - a.dx) * f, a.dy + (b.dy - a.dy) * f);
      linePath.lineTo(tip.dx, tip.dy);
    } else {
      tip = pt(n);
    }

    final fill = Path.from(linePath)
      ..lineTo(tip.dx, buyY)
      ..lineTo(0, buyY)
      ..close();
    final up = path[full] >= buy;
    canvas.drawPath(
      fill,
      Paint()
        ..color = (up ? BlockChartColors.success : BlockChartColors.error)
            .withValues(alpha: 0.15),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = up ? BlockChartColors.success : BlockChartColors.error
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      tip,
      4,
      Paint()..color = up ? BlockChartColors.success : BlockChartColors.error,
    );
  }

  @override
  bool shouldRepaint(_PnlPainter old) => old.progress != progress;
}
