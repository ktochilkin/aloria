import 'package:aloria/core/theme/tokens.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Две почти слипшиеся линии (fl_chart): индекс и индексный фонд, который его
/// повторяет чуть ниже из-за комиссии. Для урока про индексные фонды.
class LessonIndexVsFund extends StatelessWidget {
  const LessonIndexVsFund({super.key, required this.tint});

  final Color tint;

  static const _index = <double>[100, 103, 101, 106, 110, 108, 114, 119];
  static const _fund = <double>[100, 102.7, 100.6, 105.3, 109, 107, 112.7, 117.4];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    List<FlSpot> spots(List<double> d) =>
        [for (var i = 0; i < d.length; i++) FlSpot(i.toDouble(), d[i])];

    LineChartBarData bar(List<double> d, Color c) => LineChartBarData(
          spots: spots(d),
          isCurved: true,
          color: c,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
        );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Dot(color: tint, label: 'индекс'),
              const SizedBox(width: 14),
              const _Dot(color: AppColors.success, label: 'фонд (−комиссия)'),
            ],
          ),
          const SizedBox(height: 12),
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
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  bar(_index, tint),
                  bar(_fund, AppColors.success),
                ],
              ),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Фонд повторяет индекс почти точь-в-точь — линии почти сливаются. '
            'Разница накапливается из комиссии.',
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(
          begin: 0.06,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Живой P&L: цена покупки — горизонтальная линия, рыночная цена анимированно
/// ходит, зона между ними подсвечивается зелёным/красным. Для урока про P&L.
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
    final text = Theme.of(context).textTheme;
    final progress = _c.value;
    final pos = progress * (_path.length - 1);
    final i = pos.floor();
    final frac = pos - i;
    final price = i < _path.length - 1
        ? _path[i] + (_path[i + 1] - _path[i]) * frac
        : _path.last;
    final pnl = price - _buy;
    final up = pnl >= 0;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'куплено по ${_buy.toStringAsFixed(0)}',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${up ? '+' : ''}${pnl.toStringAsFixed(1)} ₽',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: up ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 1.9,
            child: CustomPaint(
              painter: _PnlPainter(
                path: _path,
                buy: _buy,
                progress: progress,
                grid: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Пока не продал — это «бумажный» результат: он всё время пляшет '
            'вместе с ценой.',
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(
          begin: 0.06,
          curve: Curves.easeOutCubic,
        );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 3, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
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
        ..color = (up ? AppColors.success : AppColors.error)
            .withValues(alpha: 0.15),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = up ? AppColors.success : AppColors.error
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      tip,
      4,
      Paint()..color = up ? AppColors.success : AppColors.error,
    );
  }

  @override
  bool shouldRepaint(_PnlPainter old) => old.progress != progress;
}
