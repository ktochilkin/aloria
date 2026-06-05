import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

Widget _card(BuildContext context, Widget child) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
    ),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
    child: child,
  );
}

// ── order-builder ────────────────────────────────────────────────────────────

/// Конструктор заявки: выбираешь сторону, тип, объём (и цену для лимитной) —
/// внизу собирается человеческое описание того, что произойдёт.
class LessonOrderBuilder extends StatefulWidget {
  const LessonOrderBuilder({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonOrderBuilder> createState() => _LessonOrderBuilderState();
}

class _LessonOrderBuilderState extends State<LessonOrderBuilder> {
  bool _buy = true;
  bool _market = true;
  double _qty = 5;
  double _price = 100;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final side = _buy ? 'купить' : 'продать';

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Собери заявку', style: text.titleMedium),
          const SizedBox(height: 10),
          _seg('Сторона', ['Купить', 'Продать'], _buy ? 0 : 1,
              (i) => setState(() => _buy = i == 0)),
          const SizedBox(height: 8),
          _seg('Тип', ['Рыночная', 'Лимитная'], _market ? 0 : 1,
              (i) => setState(() => _market = i == 0)),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(width: 64, child: Text('Объём',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
            Expanded(
              child: Slider(
                value: _qty,
                min: 1,
                max: 20,
                divisions: 19,
                activeColor: widget.tint,
                onChanged: (v) => setState(() => _qty = v),
              ),
            ),
            SizedBox(width: 34, child: Text('${_qty.round()}',
                textAlign: TextAlign.right,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800))),
          ]),
          if (!_market)
            Row(children: [
              SizedBox(width: 64, child: Text('Цена',
                  style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant))),
              Expanded(
                child: Slider(
                  value: _price,
                  min: 96,
                  max: 104,
                  divisions: 32,
                  activeColor: widget.tint,
                  onChanged: (v) => setState(() => _price = v),
                ),
              ),
              SizedBox(width: 44, child: Text(_price.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800))),
            ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.tint.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _market
                  ? 'Заявка: $side ${_qty.round()} лот. по рынку — исполнится '
                      'сразу по лучшей цене в стакане.'
                  : 'Заявка: $side ${_qty.round()} лот. по ${_price.toStringAsFixed(1)} '
                      '— встанет в стакан и будет ждать встречную по этой цене '
                      'или лучше.',
              style: text.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seg(String label, List<String> opts, int sel, ValueChanged<int> on) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      SizedBox(width: 64, child: Text(label,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
      Expanded(
        child: Row(
          children: [
            for (var i = 0; i < opts.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => on(i),
                  child: Container(
                    margin: EdgeInsets.only(right: i == 0 ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel == i
                          ? widget.tint.withValues(alpha: 0.2)
                          : scheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: sel == i ? widget.tint : scheme.outlineVariant),
                    ),
                    child: Text(opts[i],
                        style: text.labelMedium?.copyWith(
                            fontWeight:
                                sel == i ? FontWeight.w800 : FontWeight.w400)),
                  ),
                ),
              ),
          ],
        ),
      ),
    ]);
  }
}

// ── candle-from-trades ───────────────────────────────────────────────────────

/// Свеча из сделок: поток сделок проигрывается точками, и из них на глазах
/// собирается свеча — тело (открытие→закрытие) и тени (макс/мин).
class LessonCandleFromTrades extends StatefulWidget {
  const LessonCandleFromTrades({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonCandleFromTrades> createState() =>
      _LessonCandleFromTradesState();
}

class _LessonCandleFromTradesState extends State<LessonCandleFromTrades>
    with SingleTickerProviderStateMixin {
  static const _trades = <double>[
    100, 100.6, 101.2, 100.8, 102.1, 101.5, 102.8, 102.2, 101.9, 102.5,
  ];

  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addListener(() => setState(() {}));
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
    final shown = (_trades.length * _c.value).ceil().clamp(1, _trades.length);
    final visible = _trades.take(shown).toList();
    final open = _trades.first;
    final close = visible.last;
    final high = visible.reduce((a, b) => a > b ? a : b);
    final low = visible.reduce((a, b) => a < b ? a : b);

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Свеча — это четыре числа', style: text.titleMedium),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: Size.infinite,
              painter: _CandleBuildPainter(
                trades: visible,
                open: open,
                close: close,
                high: high,
                low: low,
                up: AppColors.success,
                down: AppColors.error,
                dot: widget.tint,
                grid: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, children: [
            _ohlc('O', open, scheme),
            _ohlc('H', high, scheme),
            _ohlc('L', low, scheme),
            _ohlc('C', close, scheme),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _c.forward(from: 0),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(_c.value > 0.97 ? 'Ещё раз' : 'Проиграть сделки'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ohlc(String k, double v, ColorScheme scheme) {
    final text = Theme.of(context).textTheme;
    return Text.rich(TextSpan(children: [
      TextSpan(
          text: '$k ',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      TextSpan(
          text: v.toStringAsFixed(1),
          style: text.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
    ]));
  }
}

class _CandleBuildPainter extends CustomPainter {
  _CandleBuildPainter({
    required this.trades,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.up,
    required this.down,
    required this.dot,
    required this.grid,
  });

  final List<double> trades;
  final double open;
  final double close;
  final double high;
  final double low;
  final Color up;
  final Color down;
  final Color dot;
  final Color grid;

  static const double _lo = 99;
  static const double _hi = 103.5;

  double _y(double v, double h) => h * (1 - (v - _lo) / (_hi - _lo));

  @override
  void paint(Canvas canvas, Size size) {
    final tradesW = size.width * 0.62;
    final candleX = size.width * 0.82;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(tradesW, y),
          Paint()..color = grid..strokeWidth = 1);
    }
    // точки сделок
    for (var i = 0; i < trades.length; i++) {
      final x = trades.length == 1
          ? 0.0
          : tradesW * i / (trades.length - 1);
      canvas.drawCircle(
          Offset(x, _y(trades[i], size.height)), 3, Paint()..color = dot);
    }
    // формирующаяся свеча
    final color = close >= open ? up : down;
    final wick = Paint()..color = color..strokeWidth = 2;
    canvas.drawLine(Offset(candleX, _y(high, size.height)),
        Offset(candleX, _y(low, size.height)), wick);
    final top = _y(close >= open ? close : open, size.height);
    final bot = _y(close >= open ? open : close, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(candleX - 11, top, candleX + 11, bot == top ? top + 2 : bot),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CandleBuildPainter old) => old.trades.length != trades.length;
}

// ── diversification-dice ─────────────────────────────────────────────────────

/// Один тикер против корзины: «прогнать год» — одиночная бумага трясёт сильнее,
/// корзина из тех же бумаг идёт ровнее.
class LessonDiversificationDice extends StatefulWidget {
  const LessonDiversificationDice({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonDiversificationDice> createState() =>
      _LessonDiversificationDiceState();
}

class _LessonDiversificationDiceState extends State<LessonDiversificationDice>
    with SingleTickerProviderStateMixin {
  static const _single = <double>[100, 92, 118, 88, 130, 96, 124, 140];
  static const _basket = <double>[100, 101, 104, 102, 108, 107, 112, 116];

  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() => setState(() {}));
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

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _dot(AppColors.error, 'один тикер'),
            const SizedBox(width: 14),
            _dot(widget.tint, 'корзина'),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 130,
            child: CustomPaint(
              size: Size.infinite,
              painter: _TwoPathPainter(
                a: _single,
                b: _basket,
                progress: _c.value,
                ca: AppColors.error,
                cb: widget.tint,
                grid: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _c.forward(from: 0),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(_c.value > 0.97 ? 'Ещё раз' : 'Прогнать год'),
            ),
          ),
          const SizedBox(height: 6),
          Text('Одна бумага кидает из стороны в сторону; корзина из тех же '
              'бумаг идёт ровнее — это и есть диверсификация.',
              style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant, height: 1.4)),
        ],
      ),
    );
  }

  Widget _dot(Color c, String label) {
    final text = Theme.of(context).textTheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 14, height: 3, color: c),
      const SizedBox(width: 6),
      Text(label, style: text.bodySmall),
    ]);
  }
}

class _TwoPathPainter extends CustomPainter {
  _TwoPathPainter({
    required this.a,
    required this.b,
    required this.progress,
    required this.ca,
    required this.cb,
    required this.grid,
  });

  final List<double> a;
  final List<double> b;
  final double progress;
  final Color ca;
  final Color cb;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...a, ...b];
    final hi = all.reduce((x, y) => x > y ? x : y) + 4;
    final lo = all.reduce((x, y) => x < y ? x : y) - 4;
    final n = a.length - 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          Paint()..color = grid..strokeWidth = 1);
    }
    final shown = (n * progress).clamp(0, n).toDouble();
    void line(List<double> d, Color c) {
      final p = Paint()
        ..color = c
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i <= shown.floor(); i++) {
        final x = size.width * i / n;
        final y = size.height * (1 - (d[i] - lo) / (hi - lo));
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, p);
    }

    line(a, ca);
    line(b, cb);
  }

  @override
  bool shouldRepaint(_TwoPathPainter old) => old.progress != progress;
}

// ── spread-gauge ─────────────────────────────────────────────────────────────

/// Спред — цена немедленности: переключаешь ликвидный/неликвидный инструмент,
/// датчик показывает, сколько теряешь на круговой сделке по рынку.
class LessonSpreadGauge extends StatefulWidget {
  const LessonSpreadGauge({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonSpreadGauge> createState() => _LessonSpreadGaugeState();
}

class _LessonSpreadGaugeState extends State<LessonSpreadGauge> {
  bool _liquid = true;

  double get _spreadPct => _liquid ? 0.1 : 1.4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final frac = (_spreadPct / 2).clamp(0.0, 1.0);
    final color = _spreadPct < 0.5 ? AppColors.success : AppColors.error;

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Спред — цена немедленности', style: text.titleMedium),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              height: 96,
              width: 180,
              child: CustomPaint(
                painter: _GaugePainter(
                  frac: frac,
                  color: color,
                  track: scheme.surface,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Text('${_spreadPct.toStringAsFixed(1)}%',
                        style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900, color: color)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _choice('Ликвидный', _liquid,
                  () => setState(() => _liquid = true))),
              const SizedBox(width: 8),
              Expanded(child: _choice('Неликвидный', !_liquid,
                  () => setState(() => _liquid = false))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _liquid
                ? 'Узкий спред: купил и сразу продал по рынку — потерял копейки.'
                : 'Широкий спред: та же круговая сделка по рынку стоит ощутимо '
                    'дороже. Это плата за «прямо сейчас».',
            style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _choice(String label, bool sel, VoidCallback on) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: on,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? widget.tint.withValues(alpha: 0.2) : scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? widget.tint : scheme.outlineVariant),
        ),
        child: Text(label,
            style: text.labelMedium?.copyWith(
                fontWeight: sel ? FontWeight.w800 : FontWeight.w400)),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.frac, required this.color, required this.track});

  final double frac;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = 3.14159;
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, 3.14159, false, base);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, 3.14159 * frac, false, fg);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.frac != frac || old.color != color;
}

// ── if-then-rule ─────────────────────────────────────────────────────────────

/// Собери правило «если X — то Y»: выбираешь триггер и действие; правило
/// исполняется спокойно вместо решения на эмоциях.
class LessonIfThenRule extends StatefulWidget {
  const LessonIfThenRule({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonIfThenRule> createState() => _LessonIfThenRuleState();
}

class _LessonIfThenRuleState extends State<LessonIfThenRule> {
  static const _triggers = ['цена упала на 15%', 'дошла до моей цели', 'вышел слабый отчёт'];
  static const _actions = ['ничего не делаю', 'докупаю по плану', 'фиксирую часть'];

  int _trigger = 0;
  int _action = 0;
  bool _fired = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Правило вместо паники', style: text.titleMedium),
          const SizedBox(height: 4),
          Text('Дисциплина — это решение, принятое заранее.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Text('Если', style: text.labelMedium?.copyWith(color: widget.tint)),
          const SizedBox(height: 6),
          _chips(_triggers, _trigger, (i) => setState(() {
                _trigger = i;
                _fired = false;
              })),
          const SizedBox(height: 10),
          Text('то', style: text.labelMedium?.copyWith(color: widget.tint)),
          const SizedBox(height: 6),
          _chips(_actions, _action, (i) => setState(() {
                _action = i;
                _fired = false;
              })),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() => _fired = true),
              child: const Text('Проиграть сценарий'),
            ),
          ),
          if (_fired) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Случилось «${_triggers[_trigger]}». Правило сработало само: '
                '«${_actions[_action]}» — без метаний и паники в моменте.',
                style: text.bodySmall?.copyWith(height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chips(List<String> opts, int sel, ValueChanged<int> on) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < opts.length; i++)
          ChoiceChip(
            label: Text(opts[i], style: text.labelSmall),
            selected: sel == i,
            selectedColor: widget.tint.withValues(alpha: 0.2),
            onSelected: (_) => on(i),
          ),
      ],
    );
  }
}
