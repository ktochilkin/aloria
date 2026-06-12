import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Падающий график: выбор «продать в панике» / «держать по плану».
/// После выбора график доигрывается дальше и показывает цену решения.
class LessonPanicButton extends StatefulWidget {
  const LessonPanicButton({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonPanicButton> createState() => _LessonPanicButtonState();
}

class _LessonPanicButtonState extends State<LessonPanicButton>
    with SingleTickerProviderStateMixin {
  /// Цена за единицу в рублях: сначала падение до дна, затем восстановление.
  static const List<double> _path = <double>[
    100, 98, 95, 91, 86, 80, 74, 70, 68, 67,
    69, 73, 78, 83, 88, 92, 95, 97, 99, 101,
  ];

  /// Индекс «дна», в котором паника максимальна.
  static const int _panicIndex = 9;

  late final AnimationController _controller;
  bool? _soldInPanic;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _decide({required bool panic}) {
    setState(() => _soldInPanic = panic);
    _controller.forward(from: 0);
  }

  void _reset() {
    setState(() => _soldInPanic = null);
    _controller.value = 0;
  }

  double get _visibleProgress {
    if (_soldInPanic == null) {
      return _panicIndex / (_path.length - 1);
    }
    return _controller.value;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final double entryPrice = _path.first;
    final double bottomPrice = _path[_panicIndex];
    final double finalPrice = _path.last;

    String? verdict;
    Color? verdictColor;
    bool? verdictPanic;
    if (_soldInPanic != null && _controller.isCompleted) {
      verdictPanic = _soldInPanic;
      if (_soldInPanic!) {
        final double loss = entryPrice - bottomPrice;
        verdict =
            'Зафиксирован убыток ${loss.toStringAsFixed(0)} ₽ на ед. '
            'Через несколько минут цена вернулась к ${finalPrice.toStringAsFixed(0)} ₽.';
        verdictColor = AppColors.error;
      } else {
        final double profit = finalPrice - entryPrice;
        verdict =
            'Цена восстановилась до ${finalPrice.toStringAsFixed(0)} ₽ '
            '(+${profit.toStringAsFixed(0)} ₽ к входу). План сработал.';
        verdictColor = AppColors.success;
      }
    }

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Резкое падение. Что сделаешь?',
      footer: verdict != null
          ? BlockButton(
              tint: widget.tint,
              label: 'Ещё раз',
              icon: Icons.refresh,
              onPressed: _reset,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _PanicChartPainter(
                path: _path,
                progress: _visibleProgress,
                tint: widget.tint,
                line: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          if (_soldInPanic == null)
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decide(panic: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Продать в панике'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _decide(panic: false),
                    style: FilledButton.styleFrom(backgroundColor: widget.tint),
                    child: const Text('Держать по плану'),
                  ),
                ),
              ],
            )
          else if (verdict != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                BlockChip(
                  text: verdictPanic! ? 'Убыток зафиксирован' : 'План сработал',
                  tint: widget.tint,
                  tone: verdictPanic ? BlockTone.error : BlockTone.success,
                ),
                const SizedBox(height: BlockSpacing.s),
                Text(verdict, style: text.bodyMedium?.copyWith(color: verdictColor)),
              ],
            )
          else
            Text(
              'Смотрим, чем закончилось…',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _PanicChartPainter extends CustomPainter {
  const _PanicChartPainter({
    required this.path,
    required this.progress,
    required this.tint,
    required this.line,
  });

  final List<double> path;
  final double progress;
  final Color tint;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    const double minP = 60;
    const double maxP = 105;
    double xOf(int i) => size.width * i / (path.length - 1);
    double yOf(double p) =>
        size.height - (p - minP) / (maxP - minP) * size.height;

    final double shown = progress * (path.length - 1);
    final int lastFull = shown.floor();

    final Path chart = Path()..moveTo(xOf(0), yOf(path[0]));
    for (int i = 1; i <= lastFull && i < path.length; i++) {
      chart.lineTo(xOf(i), yOf(path[i]));
    }
    if (lastFull + 1 < path.length) {
      final double t = shown - lastFull;
      final double x = xOf(lastFull) + (xOf(lastFull + 1) - xOf(lastFull)) * t;
      final double yV =
          yOf(path[lastFull]) + (yOf(path[lastFull + 1]) - yOf(path[lastFull])) * t;
      chart.lineTo(x, yV);
    }

    canvas.drawPath(
      chart,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = tint,
    );

    canvas.drawLine(
      Offset(0, yOf(path.first)),
      Offset(size.width, yOf(path.first)),
      Paint()
        ..color = line.withValues(alpha: 0.4)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PanicChartPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Конструктор свечи: четыре слайдера OHLC перестраивают одну свечу.
class LessonCandleAnatomy extends StatefulWidget {
  const LessonCandleAnatomy({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonCandleAnatomy> createState() => _LessonCandleAnatomyState();
}

class _LessonCandleAnatomyState extends State<LessonCandleAnatomy> {
  double _open = 240;
  double _close = 268;
  double _high = 280;
  double _low = 230;

  static const double _min = 200;
  static const double _max = 300;

  void _normalize() {
    final double top = _open > _close ? _open : _close;
    final double bottom = _open < _close ? _open : _close;
    if (_high < top) _high = top;
    if (_low > bottom) _low = bottom;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    _normalize();
    final bool bullish = _close >= _open;
    final Color body = bullish ? AppColors.success : AppColors.error;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Из чего состоит свеча',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 96,
                height: 180,
                child: CustomPaint(
                  painter: _CandlePainter(
                    open: _open,
                    close: _close,
                    high: _high,
                    low: _low,
                    min: _min,
                    max: _max,
                    color: body,
                  ),
                ),
              ),
              const SizedBox(width: BlockSpacing.m),
              Expanded(
                child: Column(
                  children: <Widget>[
                    _slider('Открытие', _open, (v) => setState(() => _open = v)),
                    _slider('Закрытие', _close, (v) => setState(() => _close = v)),
                    _slider('Максимум', _high, (v) => setState(() => _high = v)),
                    _slider('Минимум', _low, (v) => setState(() => _low = v)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BlockSpacing.s),
          Text(
            bullish
                ? 'Закрытие выше открытия — свеча зелёная (рост за период).'
                : 'Закрытие ниже открытия — свеча красная (снижение за период).',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return BlockSlider(
      tint: widget.tint,
      label: label,
      valueLabel: value.toStringAsFixed(0),
      value: value,
      min: _min,
      max: _max,
      onChanged: onChanged,
    );
  }
}

class _CandlePainter extends CustomPainter {
  const _CandlePainter({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.min,
    required this.max,
    required this.color,
  });

  final double open;
  final double close;
  final double high;
  final double low;
  final double min;
  final double max;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    double yOf(double p) => size.height - (p - min) / (max - min) * size.height;
    final double cx = size.width / 2;

    final Paint wick = Paint()
      ..color = color
      ..strokeWidth = 2;
    canvas.drawLine(Offset(cx, yOf(high)), Offset(cx, yOf(low)), wick);

    final double top = yOf(open > close ? open : close);
    final double bottom = yOf(open < close ? open : close);
    final Rect bodyRect = Rect.fromLTRB(cx - 16, top, cx + 16, bottom + 0.0001);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(3)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CandlePainter oldDelegate) =>
      oldDelegate.open != open ||
      oldDelegate.close != close ||
      oldDelegate.high != high ||
      oldDelegate.low != low ||
      oldDelegate.color != color;
}

/// Круговые часы суток MOEX с секторами торговых сессий.
class LessonSessionClock extends StatefulWidget {
  const LessonSessionClock({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonSessionClock> createState() => _LessonSessionClockState();
}

class _LessonSessionClockState extends State<LessonSessionClock> {
  /// Сессии в минутах от начала суток.
  static const List<_Session> _sessions = <_Session>[
    _Session('Утренняя', 410, 590, AppColors.warning, true),
    _Session('Основная', 600, 1120, AppColors.success, true),
    _Session('Вечерняя', 1145, 1430, _evening, true),
  ];

  static const Color _evening = Color(0xFF6E8BD8);

  int? _selected;

  String _fmt(int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    String caption;
    if (_selected == null) {
      caption = 'Нажми на сектор, чтобы узнать о сессии.';
    } else if (_selected == -1) {
      caption = 'Ночь — биржа закрыта, торгов нет.';
    } else {
      final _Session s = _sessions[_selected!];
      caption =
          '${s.name}: ${_fmt(s.start)}–${_fmt(s.end)}. Торговля идёт.';
    }

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Сутки торгов на MOEX',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: GestureDetector(
                onTapDown: (details) {
                  final int sel = _hit(details.localPosition);
                  setState(() => _selected = sel);
                },
                child: CustomPaint(
                  painter: _ClockPainter(
                    sessions: _sessions,
                    selected: _selected,
                    ring: scheme.outlineVariant,
                    night: scheme.surfaceContainerHigh,
                    tint: widget.tint,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          Text(caption, style: text.bodyMedium),
        ],
      ),
    );
  }

  int _hit(Offset p) {
    const Offset center = Offset(100, 100);
    final Offset d = p - center;
    double angle = (d.direction) + 1.5708; // 0 наверху, по часовой
    if (angle < 0) angle += 6.2832;
    final double minutes = angle / 6.2832 * 1440;
    for (int i = 0; i < _sessions.length; i++) {
      if (minutes >= _sessions[i].start && minutes <= _sessions[i].end) {
        return i;
      }
    }
    return -1;
  }
}

class _Session {
  const _Session(this.name, this.start, this.end, this.color, this.trading);
  final String name;
  final int start;
  final int end;
  final Color color;
  final bool trading;
}

class _ClockPainter extends CustomPainter {
  const _ClockPainter({
    required this.sessions,
    required this.selected,
    required this.ring,
    required this.night,
    required this.tint,
  });

  final List<_Session> sessions;
  final int? selected;
  final Color ring;
  final Color night;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 6;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(center, radius, Paint()..color = night);

    double a(int m) => m / 1440 * 6.2832 - 1.5708;
    for (int i = 0; i < sessions.length; i++) {
      final _Session s = sessions[i];
      final double start = a(s.start);
      final double sweep = (s.end - s.start) / 1440 * 6.2832;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = s.color.withValues(alpha: selected == i ? 1 : 0.7),
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring,
    );
    canvas.drawCircle(center, radius * 0.42, Paint()..color = night);
    canvas.drawCircle(
      center,
      radius * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = tint.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_ClockPainter oldDelegate) =>
      oldDelegate.selected != selected;
}

/// Сортировка инструментов по риску: надёжнее → рискованнее.
class LessonSortByRisk extends StatefulWidget {
  const LessonSortByRisk({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonSortByRisk> createState() => _LessonSortByRiskState();
}

class _LessonSortByRiskState extends State<LessonSortByRisk> {
  /// Эталонный порядок по возрастанию риска (rank = индекс).
  static const List<String> _correct = <String>[
    'Банковский вклад',
    'ОФЗ',
    'Корпоративная облигация',
    'Голубая фишка',
    'Акция малой компании',
  ];

  late List<String> _order;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _order = <String>[
      'Голубая фишка',
      'Банковский вклад',
      'Акция малой компании',
      'ОФЗ',
      'Корпоративная облигация',
    ];
  }

  void _move(int index, int delta) {
    final int target = index + delta;
    if (target < 0 || target >= _order.length) return;
    setState(() {
      final String item = _order.removeAt(index);
      _order.insert(target, item);
      _checked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final bool allCorrect = _order.toString() == _correct.toString();

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Расставь: надёжнее → рискованнее',
      subtitle: 'Сверху — где риск ниже.',
      footer: BlockButton(
        tint: widget.tint,
        label: 'Проверить',
        icon: Icons.check,
        onPressed: () => setState(() => _checked = true),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < _order.length; i++)
            _row(i, scheme, text),
          if (_checked) ...[
            const SizedBox(height: BlockSpacing.s),
            BlockChip(
              text: allCorrect ? 'Верно!' : 'Есть ошибки',
              tint: widget.tint,
              tone: allCorrect ? BlockTone.success : BlockTone.error,
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(int i, ColorScheme scheme, TextTheme text) {
    final bool ok = _correct[i] == _order[i];
    final Color border = _checked
        ? (ok ? AppColors.success : AppColors.error)
        : scheme.outlineVariant.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: <Widget>[
          Text('${i + 1}', style: text.labelLarge),
          const SizedBox(width: 12),
          Expanded(child: Text(_order[i], style: text.bodyMedium)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: i == 0 ? null : () => _move(i, -1),
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: i == _order.length - 1 ? null : () => _move(i, 1),
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
        ],
      ),
    );
  }
}

/// Сортировка предложений: настоящее или красный флаг.
class LessonScamSorter extends StatefulWidget {
  const LessonScamSorter({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonScamSorter> createState() => _LessonScamSorterState();
}

class _LessonScamSorterState extends State<LessonScamSorter> {
  static const List<_Offer> _offers = <_Offer>[
    _Offer(
      'ОФЗ',
      'Облигации федерального займа на бирже.',
      true,
      'Госбумаги, торгуются на MOEX. Доходность скромная, но прозрачная.',
    ),
    _Offer(
      'Копи-трейдинг блогера',
      '«Повторяй мои сделки, я в плюсе всегда».',
      false,
      'Прошлый результат не гарантирует будущий, а «всегда в плюсе» не бывает.',
    ),
    _Offer(
      'Клуб «20% в месяц без риска»',
      'Гарантированная доходность без потерь.',
      false,
      'Доходность без риска — главный признак схемы. 20% в месяц нереально.',
    ),
    _Offer(
      'Фонд на индекс',
      'БПИФ на индекс МосБиржи.',
      true,
      'Биржевой фонд, повторяет индекс. Понятная диверсификация, есть риск.',
    ),
    _Offer(
      '«Приведи друга — удвоим вклад»',
      'Доход растёт за привлечённых людей.',
      false,
      'Заработок на привлечении новых участников — признак пирамиды.',
    ),
  ];

  int _index = 0;
  bool? _lastCorrect;
  int _score = 0;

  void _answer(bool real) {
    final _Offer offer = _offers[_index];
    setState(() {
      _lastCorrect = offer.real == real;
      if (_lastCorrect!) _score++;
    });
  }

  void _next() {
    setState(() {
      _index = (_index + 1) % _offers.length;
      _lastCorrect = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final _Offer offer = _offers[_index];
    final bool answered = _lastCorrect != null;

    return LessonBlockCard(
      tint: widget.tint,
      footer: answered
          ? BlockButton(
              tint: widget.tint,
              label: 'Дальше',
              icon: Icons.arrow_forward,
              onPressed: _next,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Настоящее или красный флаг?',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text('${_index + 1}/${_offers.length}',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: BlockSpacing.l),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.5),
              borderRadius: BlockRadii.innerBr,
              border: Border.all(
                color: answered
                    ? (offer.real ? AppColors.success : AppColors.error)
                    : scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(offer.title, style: text.titleSmall),
                const SizedBox(height: BlockSpacing.xs),
                Text(offer.subtitle, style: text.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          if (!answered)
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: () => _answer(true),
                    style: FilledButton.styleFrom(backgroundColor: widget.tint),
                    child: const Text('Настоящее'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _answer(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Красный флаг'),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                BlockChip(
                  text: _lastCorrect! ? 'Верно' : 'Мимо',
                  tint: widget.tint,
                  tone: _lastCorrect! ? BlockTone.success : BlockTone.error,
                ),
                const SizedBox(height: BlockSpacing.s),
                Text(offer.explanation, style: text.bodyMedium),
              ],
            ),
          const SizedBox(height: BlockSpacing.m),
          BlockMetric(label: 'Счёт', value: '$_score'),
        ],
      ),
    );
  }
}

class _Offer {
  const _Offer(this.title, this.subtitle, this.real, this.explanation);
  final String title;
  final String subtitle;
  final bool real;
  final String explanation;
}
