import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Учебный блок про сложный процент: кривая роста 1000 ₽ под 10% за 30 лет.
/// Собран на block_kit (эталон «воздух»): карточка-обёртка, график через
/// [blockLineChart], результат — BlockMetric + BlockChip, кнопка — BlockButton.
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

    List<FlSpot> spots(List<double> data) => [
          for (var y = 0; y <= _years; y++)
            FlSpot(y.toDouble(), _revealed ? data[y] : _start),
        ];

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Сложный процент',
      subtitle: '1000 ₽ под 10%, 30 лет',
      footer: BlockButton(
        tint: widget.tint,
        label: _revealed ? 'Ещё раз' : 'Запустить 30 лет',
        icon: Icons.play_arrow,
        onPressed: _run,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlockLegend(items: [
            (widget.tint, 'сложный процент'),
            (BlockChartColors.neutral(scheme), 'простое сложение'),
          ]),
          const SizedBox(height: BlockSpacing.m),
          AspectRatio(
            aspectRatio: 1.55,
            child: LineChart(
              blockLineChart(
                context: context,
                tint: widget.tint,
                spots: spots(_compound),
                compareSpots: spots(_simple),
                minX: 0,
                maxX: _years.toDouble(),
                minY: 0,
                maxY: _compound.last * 1.05,
                bottomInterval: 10,
              ),
              duration: BlockMotion.chart,
              curve: BlockMotion.curve,
            ),
          ),
          const SizedBox(height: BlockSpacing.l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: BlockMetric(
                  label: 'через 30 лет',
                  value: _revealed ? '${_money(_compound.last)} ₽' : '1 000 ₽',
                  color: widget.tint,
                ),
              ),
              if (_revealed) BlockChip(text: '×17, а не ×4', tint: widget.tint),
            ],
          ),
        ],
      ),
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
