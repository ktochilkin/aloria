import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Учебный блок про сложный процент: кривая роста 1000 ₽ под 10% за 30 лет.
/// На fl_chart — гладкая линия с градиент-заливкой, рост анимируется при
/// запуске. Пунктир — простое сложение (+100/год) для контраста.
class LessonCompoundGrowth extends StatefulWidget {
  const LessonCompoundGrowth({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonCompoundGrowth> createState() => _LessonCompoundGrowthState();
}

class _LessonCompoundGrowthState extends State<LessonCompoundGrowth> {
  static const int _years = 30;
  static const double _start = 1000;
  static const double _rate = 0.10;

  late final List<double> _compound = List.generate(
    _years + 1,
    (y) => _start * _pow(1 + _rate, y),
  );
  late final List<double> _simple = List.generate(
    _years + 1,
    (y) => _start + _start * _rate * y,
  );

  bool _revealed = false;

  void _run() {
    setState(() => _revealed = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    List<FlSpot> spots(List<double> data) => [
          for (var y = 0; y <= _years; y++)
            FlSpot(y.toDouble(), _revealed ? data[y] : _start),
        ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _legend(widget.tint, 'сложный процент', false),
              _legend(scheme.onSurfaceVariant, 'простое сложение', true),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.55,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: _years.toDouble(),
                minY: 0,
                maxY: _compound.last * 1.05,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 5000,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    
                  ),
                  topTitles: const AxisTitles(
                    
                  ),
                  rightTitles: const AxisTitles(
                    
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10,
                      getTitlesWidget: (v, meta) => Text(
                        '${v.toInt()}',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots(_simple),
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    dashArray: [5, 4],
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: spots(_compound),
                    isCurved: true,
                    color: widget.tint,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          widget.tint.withValues(alpha: 0.28),
                          widget.tint.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'через 30 лет',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _revealed ? '${_money(_compound.last)} ₽' : '1 000 ₽',
                      style: text.titleMedium?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: widget.tint,
                      ),
                    ),
                  ],
                ),
              ),
              if (_revealed)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: widget.tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '×17, а не ×4',
                    style: text.labelLarge?.copyWith(
                      color: widget.tint,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).scale(
                      begin: const Offset(0.8, 0.8),
                      curve: Curves.easeOutBack,
                    ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(_revealed ? 'Ещё раз' : 'Запустить 30 лет'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(
          begin: 0.06,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _legend(Color color, String label, bool dashed) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 3,
          decoration: BoxDecoration(
            color: dashed ? color.withValues(alpha: 0.5) : color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: text.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

double _pow(double base, int exp) {
  var r = 1.0;
  for (var i = 0; i < exp; i++) {
    r *= base;
  }
  return r;
}

String _money(double v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}
