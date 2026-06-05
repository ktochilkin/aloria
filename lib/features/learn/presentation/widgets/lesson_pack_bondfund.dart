import 'dart:math' as math;

import 'package:aloria/core/theme/tokens.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Цена облигации в рублях', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Цена в стакане — в процентах от номинала. К ней прибавляется НКД.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _sliderRow(
            context,
            label: 'Цена',
            value: '${_pricePercent.toStringAsFixed(1)} %',
            slider: Slider(
              min: 95,
              max: 103,
              divisions: 80,
              value: _pricePercent,
              onChanged: (v) => setState(() => _pricePercent = v),
            ),
          ),
          _sliderRow(
            context,
            label: 'Дней с купона',
            value: '${_daysFromCoupon.round()} дн.',
            slider: Slider(
              max: _couponPeriodDays.toDouble(),
              divisions: _couponPeriodDays,
              value: _daysFromCoupon,
              onChanged: (v) => setState(() => _daysFromCoupon = v),
            ),
          ),
          const SizedBox(height: 12),
          _row(context, 'Чистая цена', '${_cleanRub.toStringAsFixed(2)} ₽'),
          const SizedBox(height: 6),
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

  Widget _sliderRow(
    BuildContext context, {
    required String label,
    required String value,
    required Slider slider,
  }) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: text.bodySmall),
            Text(
              value,
              style: text.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: widget.tint,
            thumbColor: widget.tint,
          ),
          child: slider,
        ),
      ],
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

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Рейтинг и доходность', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Ниже рейтинг — выше шанс дефолта. Рынок требует за это надбавку.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Align(
            child: Text(
              _current.label,
              style: text.titleMedium?.copyWith(
                color: widget.tint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: widget.tint,
              thumbColor: widget.tint,
            ),
            child: Slider(
              max: (widget.steps.length - 1).toDouble(),
              divisions: widget.steps.length - 1,
              value: _index,
              onChanged: (v) => setState(() => _index = v),
            ),
          ),
          const SizedBox(height: 8),
          _metric(
            context,
            'Доходность к погашению',
            '${_current.yield.toStringAsFixed(1)} %',
            widget.tint,
          ),
          const SizedBox(height: 10),
          _bar(
            context,
            'Вероятность дефолта',
            _current.defaultProb,
            22.0,
            AppColors.error,
            '${_current.defaultProb.toStringAsFixed(1)} %',
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
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
        const SizedBox(height: 6),
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

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Комиссия фонда (TER) на дистанции', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Небольшая разница в комиссии за годы превращается в крупную сумму.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
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
                highColor: AppColors.error,
                gridColor: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _slider(context, 'TER дёшевого фонда', '${_terLow.toStringAsFixed(2)} %',
              _terLow, 0.1, 1.0, (v) => setState(() => _terLow = v)),
          _slider(context, 'TER дорогого фонда', '${_terHigh.toStringAsFixed(2)} %',
              _terHigh, 1.0, 3.0, (v) => setState(() => _terHigh = v)),
          _slider(context, 'Доходность рынка', '${_marketReturn.toStringAsFixed(0)} %',
              _marketReturn, 5, 18, (v) => setState(() => _marketReturn = v)),
          _slider(context, 'Срок', '${_years.round()} лет', _years, 10, 20,
              (v) => setState(() => _years = v)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Разница в итоговой сумме',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_rub(gap)} ₽',
                  style: text.titleMedium?.copyWith(
                    color: widget.tint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Дёшевый: ${_rub(low)} ₽  ·  Дорогой: ${_rub(high)} ₽',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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

  Widget _slider(
    BuildContext context,
    String label,
    String value,
    double current,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: text.bodySmall),
            Text(
              value,
              style: text.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: widget.tint,
            thumbColor: widget.tint,
          ),
          child: Slider(
            min: min,
            max: max,
            value: current,
            onChanged: onChanged,
          ),
        ),
      ],
    );
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Налог: сальдо по сделкам и дивиденды', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Прибыль и убыток по сделкам сальдируются. Дивиденды — отдельная база.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _field(context, 'Прибыль по бумаге А', '${_rub(_profitA)} ₽',
              _profitA, 0, 100000, (v) => setState(() => _profitA = v)),
          _field(context, 'Убыток по бумаге Б', '${_rub(_lossB)} ₽',
              _lossB, 0, 100000, (v) => setState(() => _lossB = v)),
          _field(context, 'Дивиденды', '${_rub(_dividends)} ₽',
              _dividends, 0, 50000, (v) => setState(() => _dividends = v)),
          const SizedBox(height: 10),
          _row(context, 'База по сделкам (А − Б)', '${_rub(_tradeBase)} ₽'),
          const SizedBox(height: 6),
          _row(context, 'Налог по сделкам', '${_rub(_tradeTax)} ₽'),
          const SizedBox(height: 6),
          _row(context, 'База по дивидендам', '${_rub(_dividends)} ₽'),
          const SizedBox(height: 6),
          _row(context, 'Налог с дивидендов', '${_rub(_divTax)} ₽'),
          const Divider(height: 18),
          _row(
            context,
            'Брокер удержит всего',
            '${_rub(_totalTax)} ₽',
            bold: true,
            valueColor: AppColors.error,
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

  Widget _field(
    BuildContext context,
    String label,
    String value,
    double current,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: text.bodySmall),
            Text(
              value,
              style: text.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: widget.tint,
            thumbColor: widget.tint,
          ),
          child: Slider(
            min: min,
            max: max,
            divisions: 100,
            value: current,
            onChanged: onChanged,
          ),
        ),
      ],
    );
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
    final text = Theme.of(context).textTheme;
    final result = _isOption ? _optionResult : _futureResult;
    final positive = result >= 0;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Фьючерс или опцион?', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Фьючерс зеркалит цену в обе стороны. Опцион (call) ограничивает убыток премией.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Фьючерс')),
              ButtonSegment(value: true, label: Text('Опцион call')),
            ],
            selected: {_isOption},
            onSelectionChanged: (s) => setState(() => _isOption = s.first),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.7,
            child: CustomPaint(
              painter: _PayoffPainter(
                strike: _strike,
                premium: _premium,
                spot: _spot,
                isOption: _isOption,
                lineColor: widget.tint,
                positiveColor: AppColors.success,
                negativeColor: AppColors.error,
                axisColor: scheme.outlineVariant.withValues(alpha: 0.6),
                gridColor: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Цена актива', style: text.bodySmall),
              Text(
                _spot.toStringAsFixed(0),
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: widget.tint,
              thumbColor: widget.tint,
            ),
            child: Slider(
              min: 80,
              max: 120,
              divisions: 80,
              value: _spot,
              onChanged: (v) => setState(() => _spot = v),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Итог по позиции', style: text.bodyMedium),
              Text(
                '${result >= 0 ? '+' : ''}${result.toStringAsFixed(1)}',
                style: text.titleMedium?.copyWith(
                  color: positive ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _isOption
                ? 'Максимальный убыток ограничен премией: −${_premium.toStringAsFixed(0)}'
                : 'Убыток и прибыль не ограничены — симметрия',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
