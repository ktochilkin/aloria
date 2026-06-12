import 'dart:math' as math;

import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Облигация: чистая цена в процентах, НКД и грязная цена сделки.
class LessonBondToRubles extends StatefulWidget {
  const LessonBondToRubles({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonBondToRubles> createState() => _LessonBondToRublesState();
}

class _LessonBondToRublesState extends State<LessonBondToRubles> {
  static const double _nominal = 1000;
  static const double _couponRub = 35; // полугодовой купон, руб.
  static const int _couponPeriodDays = 182;

  double _pricePercent = 99;
  double _daysFromCoupon = 40;

  double get _cleanRub => _nominal * _pricePercent / 100;
  double get _accruedRub => _couponRub * (_daysFromCoupon / _couponPeriodDays);
  double get _dirtyRub => _cleanRub + _accruedRub;

  @override
  Widget build(BuildContext context) {
    return LessonBlockCard(
      tint: widget.tint,
      title: 'Цена облигации в рублях',
      subtitle:
          'Цена в стакане — в процентах от номинала. К ней прибавляется НКД.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlockSlider(
            tint: widget.tint,
            label: 'Цена',
            valueLabel: '${_pricePercent.toStringAsFixed(1)} %',
            value: _pricePercent,
            min: 95,
            max: 103,
            divisions: 80,
            onChanged: (v) => setState(() => _pricePercent = v),
          ),
          const SizedBox(height: BlockSpacing.s),
          BlockSlider(
            tint: widget.tint,
            label: 'Дней с купона',
            valueLabel: '${_daysFromCoupon.round()} дн.',
            value: _daysFromCoupon,
            min: 0,
            max: _couponPeriodDays.toDouble(),
            divisions: _couponPeriodDays,
            onChanged: (v) => setState(() => _daysFromCoupon = v),
          ),
          const SizedBox(height: BlockSpacing.m),
          _row(context, 'Чистая цена', '${_cleanRub.toStringAsFixed(2)} ₽'),
          const SizedBox(height: BlockSpacing.s),
          _row(
            context,
            'НКД',
            '+ ${_accruedRub.toStringAsFixed(2)} ₽',
            valueColor: widget.tint,
          ),
          const Divider(height: 18),
          _row(
            context,
            'Грязная цена сделки',
            '${_dirtyRub.toStringAsFixed(2)} ₽',
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: text.bodyMedium),
        Text(
          value,
          style: (bold ? text.titleMedium : text.bodyMedium)?.copyWith(
            color: valueColor ?? scheme.onSurface,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Рейтинг и доходность: чем ниже рейтинг, тем выше премия за риск.
class LessonRatingYield extends StatelessWidget {
  const LessonRatingYield({super.key, required this.tint});

  final Color tint;

  static const List<_RatingStep> _steps = [
    _RatingStep('AAA(RU)', 14.5, 0.2),
    _RatingStep('AA(RU)', 15.5, 0.6),
    _RatingStep('A(RU)', 17.0, 1.5),
    _RatingStep('BBB(RU)', 19.5, 3.5),
    _RatingStep('BB(RU)', 24.0, 9.0),
    _RatingStep('B(RU) и ниже', 31.0, 22.0),
  ];

  @override
  Widget build(BuildContext context) {
    return _RatingYieldBody(tint: tint, steps: _steps);
  }
}

class _RatingStep {
  const _RatingStep(this.label, this.yield, this.defaultProb);

  final String label;
  final double yield;
  final double defaultProb;
}

class _RatingYieldBody extends StatefulWidget {
  const _RatingYieldBody({required this.tint, required this.steps});

  final Color tint;
  final List<_RatingStep> steps;

  @override
  State<_RatingYieldBody> createState() => _RatingYieldBodyState();
}

class _RatingYieldBodyState extends State<_RatingYieldBody> {
  double _index = 0;

  _RatingStep get _current => widget.steps[_index.round()];
  _RatingStep get _best => widget.steps.first;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final premium = _current.yield - _best.yield;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Рейтинг и доходность',
      subtitle:
          'Ниже рейтинг — выше шанс дефолта. Рынок требует за это надбавку.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlockSlider(
            tint: widget.tint,
            label: 'Рейтинг',
            valueLabel: _current.label,
            value: _index,
            min: 0,
            max: (widget.steps.length - 1).toDouble(),
            divisions: widget.steps.length - 1,
            onChanged: (v) => setState(() => _index = v),
          ),
          const SizedBox(height: BlockSpacing.s),
          _metric(
            context,
            'Доходность к погашению',
            '${_current.yield.toStringAsFixed(1)} %',
            widget.tint,
          ),
          const SizedBox(height: BlockSpacing.m),
          _bar(
            context,
            'Вероятность дефолта',
            _current.defaultProb,
            22.0,
            BlockChartColors.error,
            '${_current.defaultProb.toStringAsFixed(1)} %',
          ),
          const SizedBox(height: BlockSpacing.m),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: BlockSpacing.m,
              vertical: BlockSpacing.s,
            ),
            decoration: BoxDecoration(
              color: BlockTint.soft(widget.tint),
              borderRadius: BlockRadii.innerBr,
            ),
            child: Text(
              'Премия = плата за риск: +${premium.toStringAsFixed(1)} % к AAA',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: text.bodyMedium),
        Text(
          value,
          style: text.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _bar(
    BuildContext context,
    String label,
    double value,
    double max,
    Color color,
    String caption,
  ) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: text.bodyMedium),
            Text(
              caption,
              style: text.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: BlockSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (value / max).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// TER двух фондов: со временем расходы расходятся в итоговой сумме.
class LessonTerRace extends StatefulWidget {
  const LessonTerRace({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonTerRace> createState() => _LessonTerRaceState();
}

class _LessonTerRaceState extends State<LessonTerRace> {
  static const double _start = 100000; // стартовый взнос, руб.

  double _terLow = 0.5;
  double _terHigh = 2.5;
  double _marketReturn = 12;
  double _years = 15;

  double _finalValue(double ter) {
    final net = (_marketReturn - ter) / 100;
    return _start * math.pow(1 + net, _years).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final low = _finalValue(_terLow);
    final high = _finalValue(_terHigh);
    final gap = low - high;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Комиссия фонда (TER) на дистанции',
      subtitle:
          'Небольшая разница в комиссии за годы превращается в крупную сумму.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlockLegend(items: [
            (widget.tint, 'дёшевый фонд'),
            (BlockChartColors.error, 'дорогой фонд'),
          ]),
          const SizedBox(height: BlockSpacing.m),
          // Кастомная визуализация (две экспоненты в одном масштабе) —
          // оставлена на CustomPaint, палитра переведена на токены блоков.
          AspectRatio(
            aspectRatio: 1.9,
            child: CustomPaint(
              painter: _TerRacePainter(
                start: _start,
                terLow: _terLow,
                terHigh: _terHigh,
                marketReturn: _marketReturn,
                years: _years,
                lowColor: widget.tint,
                highColor: BlockChartColors.error,
                gridColor: BlockChartColors.grid(scheme),
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          BlockSlider(
            tint: widget.tint,
            label: 'TER дёшевого фонда',
            valueLabel: '${_terLow.toStringAsFixed(2)} %',
            value: _terLow,
            min: 0.1,
            max: 1.0,
            onChanged: (v) => setState(() => _terLow = v),
          ),
          BlockSlider(
            tint: widget.tint,
            label: 'TER дорогого фонда',
            valueLabel: '${_terHigh.toStringAsFixed(2)} %',
            value: _terHigh,
            min: 1.0,
            max: 3.0,
            onChanged: (v) => setState(() => _terHigh = v),
          ),
          BlockSlider(
            tint: widget.tint,
            label: 'Доходность рынка',
            valueLabel: '${_marketReturn.toStringAsFixed(0)} %',
            value: _marketReturn,
            min: 5,
            max: 18,
            onChanged: (v) => setState(() => _marketReturn = v),
          ),
          BlockSlider(
            tint: widget.tint,
            label: 'Срок',
            valueLabel: '${_years.round()} лет',
            value: _years,
            min: 10,
            max: 20,
            onChanged: (v) => setState(() => _years = v),
          ),
          const SizedBox(height: BlockSpacing.s),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: BlockSpacing.m,
              vertical: BlockSpacing.m,
            ),
            decoration: BoxDecoration(
              color: BlockTint.soft(widget.tint),
              borderRadius: BlockRadii.innerBr,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlockMetric(
                  label: 'Разница в итоговой сумме',
                  value: '${_rub(gap)} ₽',
                  color: widget.tint,
                ),
                const SizedBox(height: BlockSpacing.xs),
                Text(
                  'Дёшевый: ${_rub(low)} ₽  ·  Дорогой: ${_rub(high)} ₽',
                  style:
                      text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _rub(double value) {
    final whole = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(whole[i]);
    }
    return buffer.toString();
  }
}

class _TerRacePainter extends CustomPainter {
  _TerRacePainter({
    required this.start,
    required this.terLow,
    required this.terHigh,
    required this.marketReturn,
    required this.years,
    required this.lowColor,
    required this.highColor,
    required this.gridColor,
  });

  final double start;
  final double terLow;
  final double terHigh;
  final double marketReturn;
  final double years;
  final Color lowColor;
  final Color highColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final lowNet = (marketReturn - terLow) / 100;
    final highNet = (marketReturn - terHigh) / 100;
    final maxValue = start * math.pow(1 + math.max(lowNet, highNet), years);

    Path buildPath(double net) {
      final path = Path();
      const steps = 40;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final value = start * math.pow(1 + net, years * t);
        final x = size.width * t;
        final y = size.height * (1 - value / maxValue);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    final highPaint = Paint()
      ..color = highColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final lowPaint = Paint()
      ..color = lowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(buildPath(highNet), highPaint);
    canvas.drawPath(buildPath(lowNet), lowPaint);
  }

  @override
  bool shouldRepaint(covariant _TerRacePainter old) {
    return old.terLow != terLow ||
        old.terHigh != terHigh ||
        old.marketReturn != marketReturn ||
        old.years != years;
  }
}

/// Сальдирование по сделкам и отдельная база по дивидендам, налог 13%.
class LessonTaxSaldo extends StatefulWidget {
  const LessonTaxSaldo({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonTaxSaldo> createState() => _LessonTaxSaldoState();
}

class _LessonTaxSaldoState extends State<LessonTaxSaldo> {
  static const double _rate = 0.13;

  double _profitA = 50000;
  double _lossB = 20000;
  double _dividends = 8000;

  double get _tradeBase => math.max(0, _profitA - _lossB);
  double get _tradeTax => _tradeBase * _rate;
  double get _divTax => _dividends * _rate;
  double get _totalTax => _tradeTax + _divTax;

  @override
  Widget build(BuildContext context) {
    return LessonBlockCard(
      tint: widget.tint,
      title: 'Налог: сальдо по сделкам и дивиденды',
      subtitle:
          'Прибыль и убыток по сделкам сальдируются. Дивиденды — отдельная база.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlockSlider(
            tint: widget.tint,
            label: 'Прибыль по бумаге А',
            valueLabel: '${_rub(_profitA)} ₽',
            value: _profitA,
            min: 0,
            max: 100000,
            divisions: 100,
            onChanged: (v) => setState(() => _profitA = v),
          ),
          BlockSlider(
            tint: widget.tint,
            label: 'Убыток по бумаге Б',
            valueLabel: '${_rub(_lossB)} ₽',
            value: _lossB,
            min: 0,
            max: 100000,
            divisions: 100,
            onChanged: (v) => setState(() => _lossB = v),
          ),
          BlockSlider(
            tint: widget.tint,
            label: 'Дивиденды',
            valueLabel: '${_rub(_dividends)} ₽',
            value: _dividends,
            min: 0,
            max: 50000,
            divisions: 100,
            onChanged: (v) => setState(() => _dividends = v),
          ),
          const SizedBox(height: BlockSpacing.s),
          _row(context, 'База по сделкам (А − Б)', '${_rub(_tradeBase)} ₽'),
          const SizedBox(height: BlockSpacing.s),
          _row(context, 'Налог по сделкам', '${_rub(_tradeTax)} ₽'),
          const SizedBox(height: BlockSpacing.s),
          _row(context, 'База по дивидендам', '${_rub(_dividends)} ₽'),
          const SizedBox(height: BlockSpacing.s),
          _row(context, 'Налог с дивидендов', '${_rub(_divTax)} ₽'),
          const Divider(height: 18),
          _row(
            context,
            'Брокер удержит всего',
            '${_rub(_totalTax)} ₽',
            bold: true,
            valueColor: BlockChartColors.error,
          ),
        ],
      ),
    );
  }

  String _rub(double value) {
    final whole = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(whole[i]);
    }
    return buffer.toString();
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: text.bodyMedium),
        Text(
          value,
          style: (bold ? text.titleMedium : text.bodyMedium)?.copyWith(
            color: valueColor ?? scheme.onSurface,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Фьючерс симметричен, опцион ограничивает убыток премией.
class LessonFutureVsOption extends StatefulWidget {
  const LessonFutureVsOption({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonFutureVsOption> createState() => _LessonFutureVsOptionState();
}

class _LessonFutureVsOptionState extends State<LessonFutureVsOption> {
  static const double _strike = 100;
  static const double _premium = 6;

  double _spot = 100;
  bool _isOption = false;

  double get _futureResult => _spot - _strike;
  double get _optionResult => math.max(_spot - _strike, 0) - _premium;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = _isOption ? _optionResult : _futureResult;
    final positive = result >= 0;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Фьючерс или опцион?',
      subtitle:
          'Фьючерс зеркалит цену в обе стороны. Опцион (call) ограничивает убыток премией.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Фьючерс')),
              ButtonSegment(value: true, label: Text('Опцион call')),
            ],
            selected: {_isOption},
            onSelectionChanged: (s) => setState(() => _isOption = s.first),
          ),
          const SizedBox(height: BlockSpacing.m),
          // Кастомная диаграмма выплат (излом по страйку + маркер спота) —
          // оставлена на CustomPaint, палитра переведена на токены блоков.
          AspectRatio(
            aspectRatio: 1.7,
            child: CustomPaint(
              painter: _PayoffPainter(
                strike: _strike,
                premium: _premium,
                spot: _spot,
                isOption: _isOption,
                lineColor: widget.tint,
                positiveColor: BlockChartColors.success,
                negativeColor: BlockChartColors.error,
                axisColor: scheme.outlineVariant.withValues(alpha: 0.6),
                gridColor: BlockChartColors.grid(scheme),
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          BlockSlider(
            tint: widget.tint,
            label: 'Цена актива',
            valueLabel: _spot.toStringAsFixed(0),
            value: _spot,
            min: 80,
            max: 120,
            divisions: 80,
            onChanged: (v) => setState(() => _spot = v),
          ),
          const SizedBox(height: BlockSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: BlockMetric(
                  label: 'Итог по позиции',
                  value: '${result >= 0 ? '+' : ''}${result.toStringAsFixed(1)}',
                  color: positive
                      ? BlockChartColors.success
                      : BlockChartColors.error,
                ),
              ),
              BlockChip(
                text: positive ? 'в плюсе' : 'в минусе',
                tint: widget.tint,
                tone: positive ? BlockTone.success : BlockTone.error,
              ),
            ],
          ),
          const SizedBox(height: BlockSpacing.xs),
          Text(
            _isOption
                ? 'Максимальный убыток ограничен премией: −${_premium.toStringAsFixed(0)}'
                : 'Убыток и прибыль не ограничены — симметрия',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PayoffPainter extends CustomPainter {
  _PayoffPainter({
    required this.strike,
    required this.premium,
    required this.spot,
    required this.isOption,
    required this.lineColor,
    required this.positiveColor,
    required this.negativeColor,
    required this.axisColor,
    required this.gridColor,
  });

  final double strike;
  final double premium;
  final double spot;
  final bool isOption;
  final Color lineColor;
  final Color positiveColor;
  final Color negativeColor;
  final Color axisColor;
  final Color gridColor;

  static const double _minSpot = 80;
  static const double _maxSpot = 120;
  static const double _maxPayoff = 20;

  double _payoff(double s) {
    if (isOption) {
      return math.max(s - strike, 0) - premium;
    }
    return s - strike;
  }

  Offset _toPixel(Size size, double s, double payoff) {
    final x = size.width * (s - _minSpot) / (_maxSpot - _minSpot);
    final y = size.height * (1 - (payoff + _maxPayoff) / (2 * _maxPayoff));
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final zeroY = _toPixel(size, _minSpot, 0).dy;
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), axisPaint);

    final path = Path();
    const steps = 60;
    for (var i = 0; i <= steps; i++) {
      final s = _minSpot + (_maxSpot - _minSpot) * i / steps;
      final p = _toPixel(size, s, _payoff(s).clamp(-_maxPayoff, _maxPayoff));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final payoff = _payoff(spot).clamp(-_maxPayoff, _maxPayoff);
    final dot = _toPixel(size, spot, payoff);
    final dotPaint = Paint()
      ..color = payoff >= 0 ? positiveColor : negativeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dot, 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _PayoffPainter old) {
    return old.spot != spot || old.isOption != isOption;
  }
}
