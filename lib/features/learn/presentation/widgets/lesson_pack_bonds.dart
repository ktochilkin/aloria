import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Блок 1: слайдер цены облигации в % от номинала; вживую пересчитывает
/// доходность к погашению (обратная связь к цене).
class LessonBondYieldFlip extends StatefulWidget {
  const LessonBondYieldFlip({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonBondYieldFlip> createState() => _LessonBondYieldFlipState();
}

class _LessonBondYieldFlipState extends State<LessonBondYieldFlip> {
  static const double _coupon = 8.0; // купон, % годовых
  static const int _years = 4; // до погашения

  double _price = 100;

  double get _ytm {
    // Упрощённая аппроксимация YTM: купонный поток + амортизация дисконта/премии.
    final gain = (100 - _price) / _years;
    return (_coupon + gain) / ((_price + 100) / 2) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final below = _price < 100;
    final ytmColor = below ? BlockChartColors.success : BlockChartColors.error;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Цена и доходность',
      subtitle: 'Купон фиксирован ${_coupon.toStringAsFixed(0)}%. Чем дешевле '
          'берёшь бумагу, тем выше доходность к погашению.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BlockMetric(
                  label: 'Цена, % номинала',
                  value: '${_price.toStringAsFixed(1)}%',
                  color: scheme.onSurface,
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: BlockMetric(
                  label: 'Доходность (YTM)',
                  value: '${_ytm.toStringAsFixed(2)}%',
                  color: ytmColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: BlockSpacing.m),
          BlockSlider(
            tint: widget.tint,
            label: 'Цена покупки',
            valueLabel: '${_price.toStringAsFixed(1)}%',
            value: _price,
            min: 90,
            max: 110,
            divisions: 40,
            onChanged: (v) => setState(() => _price = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('90% — дисконт',
                  style: text.labelSmall
                      ?.copyWith(color: BlockChartColors.success)),
              Text('100% — номинал',
                  style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              Text('110% — премия',
                  style: text.labelSmall
                      ?.copyWith(color: BlockChartColors.error)),
            ],
          ),
          const SizedBox(height: BlockSpacing.s),
          Text(
            below
                ? 'Бумага торгуется ниже номинала — доходность выше купона.'
                : _price > 100
                    ? 'Бумага дороже номинала — доходность ниже купона.'
                    : 'Цена равна номиналу — доходность равна купону.',
            style: text.bodySmall?.copyWith(color: ytmColor),
          ),
        ],
      ),
    );
  }
}

/// Блок 2: слайдеры ставки купона и срока; таймлайн купонных выплат,
/// последняя включает возврат номинала; сумма всех выплат.
class LessonCouponCashflow extends StatefulWidget {
  const LessonCouponCashflow({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonCouponCashflow> createState() => _LessonCouponCashflowState();
}

class _LessonCouponCashflowState extends State<LessonCouponCashflow> {
  static const double _nominal = 1000;

  double _rate = 9; // купон, % годовых
  int _years = 4;

  double get _couponPay => _nominal * _rate / 100;
  double get _total => _couponPay * _years + _nominal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Денежный поток облигации',
      subtitle: 'Номинал ${_nominal.toStringAsFixed(0)} ₽. Каждый год — купон, '
          'в конце — возврат номинала.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Кастомная визуализация: бары купонных выплат + возврат номинала.
          SizedBox(
            height: 130,
            child: CustomPaint(
              size: Size.infinite,
              painter: _CashflowPainter(
                years: _years,
                couponPay: _couponPay,
                nominal: _nominal,
                tint: widget.tint,
                grid: scheme.outlineVariant.withValues(alpha: 0.6),
                labelColor: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.s),
          BlockSlider(
            tint: widget.tint,
            label: 'Ставка купона',
            valueLabel: '${_rate.toStringAsFixed(0)}%',
            value: _rate,
            min: 5,
            max: 16,
            divisions: 11,
            onChanged: (v) => setState(() => _rate = v),
          ),
          BlockSlider(
            tint: widget.tint,
            label: 'Срок до погашения',
            valueLabel: '$_years ${_years == 1 ? 'год' : 'года'}',
            value: _years.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            onChanged: (v) => setState(() => _years = v.round()),
          ),
          const SizedBox(height: BlockSpacing.s),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: BlockSpacing.m, vertical: 10),
            decoration: BoxDecoration(
              color: BlockTint.soft(widget.tint),
              borderRadius: BlockRadii.innerBr,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Всего получишь', style: text.bodyMedium),
                Text('${_total.toStringAsFixed(0)} ₽',
                    style: text.titleMedium?.copyWith(
                        color: widget.tint, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowPainter extends CustomPainter {
  _CashflowPainter({
    required this.years,
    required this.couponPay,
    required this.nominal,
    required this.tint,
    required this.grid,
    required this.labelColor,
  });

  final int years;
  final double couponPay;
  final double nominal;
  final Color tint;
  final Color grid;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const baseY = 100.0;
    final axis = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(0, baseY), Offset(size.width, baseY), axis);

    final maxVal = couponPay + nominal;
    final slot = size.width / years;
    final barW = slot * 0.42;

    for (var i = 1; i <= years; i++) {
      final cx = slot * (i - 0.5);
      final last = i == years;
      final couponH = (couponPay / maxVal) * 82;

      // купон
      final couponPaint = Paint()..color = tint;
      final couponRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, baseY - couponH, barW, couponH),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(couponRect, couponPaint);

      if (last) {
        final nominalH = (nominal / maxVal) * 82;
        final nomPaint = Paint()..color = tint.withValues(alpha: 0.4);
        final nomRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, baseY - couponH - nominalH, barW, nominalH),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(nomRect, nomPaint);
      }

      final tp = TextPainter(
        text: TextSpan(
          text: '$i г.',
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, baseY + 6));
    }
  }

  @override
  bool shouldRepaint(_CashflowPainter old) =>
      old.years != years || old.couponPay != couponPay;
}

/// Блок 3: «пила» НКД — накапливается ежедневно, обнуляется в дату купона.
/// Слайдер дня покупки; показывает НКД и грязную цену.
class LessonNkdSawtooth extends StatefulWidget {
  const LessonNkdSawtooth({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonNkdSawtooth> createState() => _LessonNkdSawtoothState();
}

class _LessonNkdSawtoothState extends State<LessonNkdSawtooth> {
  static const int _periodDays = 182; // полугодовой купон
  static const double _couponSum = 45; // ₽ за период
  static const double _cleanPrice = 980; // чистая цена, ₽

  int _day = 60;

  double get _nkd => _couponSum * _day / _periodDays;
  double get _dirty => _cleanPrice + _nkd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Накопленный купонный доход',
      subtitle: 'НКД растёт каждый день и обнуляется в дату выплаты купона. '
          'Покупая, ты доплачиваешь НКД продавцу.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Кастомная визуализация: «пила» НКД с маркером выбранного дня.
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SawtoothPainter(
                periodDays: _periodDays,
                couponSum: _couponSum,
                day: _day,
                tint: widget.tint,
                grid: scheme.outlineVariant.withValues(alpha: 0.6),
                marker: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.s),
          BlockSlider(
            tint: widget.tint,
            label: 'День в купонном периоде',
            valueLabel: 'День $_day',
            value: _day.toDouble(),
            min: 0,
            max: _periodDays.toDouble(),
            divisions: _periodDays,
            onChanged: (v) => setState(() => _day = v.round()),
          ),
          Row(
            children: [
              Expanded(
                child: BlockMetric(
                  label: 'НКД на день $_day',
                  value: '${_nkd.toStringAsFixed(2)} ₽',
                  color: widget.tint,
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: BlockMetric(
                  label: 'Грязная цена',
                  value: '${_dirty.toStringAsFixed(2)} ₽',
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: BlockSpacing.s),
          Text(
            'Грязная = чистая ${_cleanPrice.toStringAsFixed(0)} ₽ + '
            'НКД ${_nkd.toStringAsFixed(2)} ₽',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SawtoothPainter extends CustomPainter {
  _SawtoothPainter({
    required this.periodDays,
    required this.couponSum,
    required this.day,
    required this.tint,
    required this.grid,
    required this.marker,
  });

  final int periodDays;
  final double couponSum;
  final int day;
  final Color tint;
  final Color grid;
  final Color marker;

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height - 14;
    const topY = 6.0;
    final axis = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), axis);

    // три периода-зуба
    const periods = 3;
    final periodW = size.width / periods;
    final line = Paint()
      ..color = tint
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var p = 0; p < periods; p++) {
      final x0 = periodW * p;
      final path = Path()
        ..moveTo(x0, baseY)
        ..lineTo(x0 + periodW, topY);
      canvas.drawPath(path, line);
      // вертикальный сброс
      if (p < periods - 1 || true) {
        canvas.drawLine(
          Offset(x0 + periodW, topY),
          Offset(x0 + periodW, baseY),
          Paint()
            ..color = tint.withValues(alpha: 0.35)
            ..strokeWidth = 1,
        );
      }
    }

    // маркер выбранного дня в первом периоде
    final frac = day / periodDays;
    final mx = frac * periodW;
    final my = baseY - frac * (baseY - topY);
    final mp = Paint()..color = marker;
    canvas.drawCircle(Offset(mx, my), 4, mp);
    canvas.drawLine(
      Offset(mx, my),
      Offset(mx, baseY),
      Paint()
        ..color = marker.withValues(alpha: 0.4)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SawtoothPainter old) => old.day != day;
}

/// Блок 4: gauge-стрелка YTM; слайдер цены покупки; стек-бар делит
/// доходность на купон (фикс) и доход от цены (меняет знак выше 100).
class LessonYtmGauge extends StatefulWidget {
  const LessonYtmGauge({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonYtmGauge> createState() => _LessonYtmGaugeState();
}

class _LessonYtmGaugeState extends State<LessonYtmGauge>
    with SingleTickerProviderStateMixin {
  static const double _coupon = 8.0;
  static const int _years = 5;
  static const double _maxYtm = 14.0;

  double _price = 100;
  late final AnimationController _ctrl;
  double _shownYtm = 8;

  double get _priceGain => (100 - _price) / _years;
  double get _ytm => _coupon + _priceGain;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() => setState(() {
          _shownYtm = _fromAnim;
        }));
  }

  double _animStart = 8;
  double get _fromAnim =>
      _animStart + (_ytm - _animStart) * Curves.easeOut.transform(_ctrl.value);

  void _onPrice(double v) {
    _animStart = _shownYtm;
    setState(() => _price = v);
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final gainColor =
        _priceGain >= 0 ? BlockChartColors.success : BlockChartColors.error;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Из чего собрана доходность',
      subtitle: 'YTM = купон ${_coupon.toStringAsFixed(0)}% плюс/минус доход от '
          'разницы между ценой и номиналом.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Кастомная визуализация: gauge-стрелка YTM.
          SizedBox(
            height: 110,
            child: CustomPaint(
              size: Size.infinite,
              painter: _GaugePainter(
                ytm: _shownYtm,
                maxYtm: _maxYtm,
                tint: widget.tint,
                arc: scheme.outlineVariant.withValues(alpha: 0.6),
                labelColor: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Center(
            child: Text('YTM ${_ytm.toStringAsFixed(2)}%',
                style: text.titleMedium?.copyWith(
                    color: widget.tint, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: BlockSpacing.m),
          // Кастомная визуализация: стек-бар «купон + доход от цены».
          _StackBar(
            coupon: _coupon,
            priceGain: _priceGain,
            maxAbs: _maxYtm,
            couponColor: widget.tint,
            gainColor: gainColor,
            track: scheme.surfaceContainerHighest,
          ),
          const SizedBox(height: BlockSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Купон ${_coupon.toStringAsFixed(0)}%',
                  style: text.labelSmall?.copyWith(color: widget.tint)),
              Text(
                  'Цена ${_priceGain >= 0 ? '+' : ''}'
                  '${_priceGain.toStringAsFixed(2)}%',
                  style: text.labelSmall?.copyWith(color: gainColor)),
            ],
          ),
          const SizedBox(height: BlockSpacing.s),
          BlockSlider(
            tint: widget.tint,
            label: 'Цена покупки',
            valueLabel: 'Цена ${_price.toStringAsFixed(1)}%',
            value: _price,
            min: 90,
            max: 110,
            divisions: 40,
            onChanged: _onPrice,
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.ytm,
    required this.maxYtm,
    required this.tint,
    required this.arc,
    required this.labelColor,
  });

  final double ytm;
  final double maxYtm;
  final Color tint;
  final Color arc;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 8);
    final radius = size.height - 20;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      3.14159,
      3.14159,
      false,
      Paint()
        ..color = arc
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final frac = (ytm / maxYtm).clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      3.14159,
      3.14159 * frac,
      false,
      Paint()
        ..color = tint
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final angle = 3.14159 + 3.14159 * frac;
    final needle = Offset(
      center.dx + radius * 0.86 * _cos(angle),
      center.dy + radius * 0.86 * _sin(angle),
    );
    canvas.drawLine(
        center,
        needle,
        Paint()
          ..color = labelColor
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(center, 5, Paint()..color = labelColor);
  }

  double _cos(double a) => _trig(a, true);
  double _sin(double a) => _trig(a, false);
  double _trig(double a, bool cos) {
    // компактная реализация через стандартную math недоступна без импорта;
    // используем приближение Тейлора достаточной точности на [pi; 2pi].
    final x = cos ? a + 1.5707963 : a;
    var t = x % 6.2831853;
    if (t > 3.1415926) t -= 6.2831853;
    final t2 = t * t;
    return t * (1 - t2 / 6 + t2 * t2 / 120 - t2 * t2 * t2 / 5040);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.ytm != ytm;
}

class _StackBar extends StatelessWidget {
  const _StackBar({
    required this.coupon,
    required this.priceGain,
    required this.maxAbs,
    required this.couponColor,
    required this.gainColor,
    required this.track,
  });

  final double coupon;
  final double priceGain;
  final double maxAbs;
  final Color couponColor;
  final Color gainColor;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final half = w / 2; // центр = ноль приращения, влево минус, вправо плюс
        final couponW = (coupon / maxAbs) * half;
        final gainW = (priceGain.abs() / maxAbs) * half;
        return SizedBox(
          height: 22,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: couponW,
                  decoration: BoxDecoration(
                    color: couponColor,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(6)),
                  ),
                ),
              ),
              Positioned(
                left: couponW,
                top: 0,
                bottom: 0,
                child: Container(
                  width: gainW,
                  color: gainColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Блок 5: treemap состава фонда; площадь плитки = вес бумаги;
/// тап подсвечивает плитку и показывает имя и вес.
class LessonFundTreemap extends StatefulWidget {
  const LessonFundTreemap({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonFundTreemap> createState() => _LessonFundTreemapState();
}

class _Holding {
  const _Holding(this.name, this.weight);
  final String name;
  final double weight;
}

class _LessonFundTreemapState extends State<LessonFundTreemap> {
  static const List<_Holding> _holdings = [
    _Holding('Сбербанк', 16),
    _Holding('Лукойл', 14),
    _Holding('Газпром', 12),
    _Holding('Норникель', 10),
    _Holding('Татнефть', 9),
    _Holding('Новатэк', 9),
    _Holding('Роснефть', 8),
    _Holding('Полюс', 8),
    _Holding('Яндекс', 7),
    _Holding('МТС', 7),
  ];

  int? _selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sel = _selected != null ? _holdings[_selected!] : null;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Что внутри фонда',
      subtitle: 'Площадь плитки — доля бумаги. Несколько крупных эмитентов '
          'занимают половину фонда. Нажми на плитку.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Кастомная визуализация: squarified-подобный treemap состава фонда.
          SizedBox(
            height: 180,
            child: LayoutBuilder(
              builder: (context, c) {
                final rects = _layout(Size(c.maxWidth, c.maxHeight));
                return Stack(
                  children: [
                    for (var i = 0; i < _holdings.length; i++)
                      Positioned.fromRect(
                        rect: rects[i].deflate(1.5),
                        child: _Tile(
                          holding: _holdings[i],
                          selected: _selected == i,
                          tint: widget.tint,
                          base: scheme.surfaceContainerHighest,
                          textColor: scheme.onSurface,
                          onTap: () => setState(
                              () => _selected = _selected == i ? null : i),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: BlockSpacing.m, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BlockRadii.innerBr,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(sel?.name ?? 'Выбери бумагу', style: text.bodyMedium),
                Text(sel != null ? '${sel.weight.toStringAsFixed(0)}%' : '—',
                    style: text.titleMedium?.copyWith(
                        color: widget.tint, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Squarified-подобный простой layout: слайс по строкам сверху вниз.
  List<Rect> _layout(Size size) {
    final total = _holdings.fold<double>(0, (s, h) => s + h.weight);
    final rects = <Rect>[];
    var y = 0.0;
    var i = 0;
    while (i < _holdings.length) {
      // набираем строку примерно до квадратных плиток
      final remaining = _holdings.length - i;
      final rowCount = remaining >= 4 ? 2 : remaining;
      var rowSum = 0.0;
      for (var k = 0; k < rowCount; k++) {
        rowSum += _holdings[i + k].weight;
      }
      final rowH = size.height * (rowSum / total);
      var x = 0.0;
      for (var k = 0; k < rowCount; k++) {
        final w = size.width * (_holdings[i + k].weight / rowSum);
        rects.add(Rect.fromLTWH(x, y, w, rowH));
        x += w;
      }
      y += rowH;
      i += rowCount;
    }
    return rects;
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.holding,
    required this.selected,
    required this.tint,
    required this.base,
    required this.textColor,
    required this.onTap,
  });

  final _Holding holding;
  final bool selected;
  final Color tint;
  final Color base;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? tint : tint.withValues(alpha: 0.18 + holding.weight / 100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? tint : base,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(6),
        alignment: Alignment.topLeft,
        child: Text(
          holding.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.labelSmall?.copyWith(
            color: selected ? Colors.white : textColor,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
