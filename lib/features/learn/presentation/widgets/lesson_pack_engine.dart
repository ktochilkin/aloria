import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Один уровень mock-стакана: цена и объём (в лотах).
class _Level {
  const _Level(this.price, this.volume);

  final double price;
  final int volume;
}

/// Маленький цветной бар-индикатор объёма для строки стакана.
class _VolumeBar extends StatelessWidget {
  const _VolumeBar({
    required this.fraction,
    required this.color,
    this.dimmed = false,
  });

  final double fraction;
  final Color color;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: constraints.maxWidth * fraction.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: dimmed ? 0.18 : 0.55),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 1. Покупка по рынку: слайдер лотов «съедает» стакан asks сверху вниз,
/// показывает среднюю цену исполнения и проскальзывание.
class LessonEatTheBook extends StatefulWidget {
  const LessonEatTheBook({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonEatTheBook> createState() => _LessonEatTheBookState();
}

class _LessonEatTheBookState extends State<LessonEatTheBook> {
  static const List<_Level> _asks = <_Level>[
    _Level(101.0, 3),
    _Level(101.5, 5),
    _Level(102.0, 4),
    _Level(102.5, 8),
    _Level(103.0, 6),
    _Level(104.0, 10),
  ];

  double _lots = 1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    var remaining = _lots.round();
    var cost = 0.0;
    var filled = 0;
    final eaten = <bool>[];
    final maxVol = _asks.map((l) => l.volume).reduce((a, b) => a > b ? a : b);

    for (final level in _asks) {
      if (remaining <= 0) {
        eaten.add(false);
        continue;
      }
      final take = remaining < level.volume ? remaining : level.volume;
      cost += take * level.price;
      filled += take;
      remaining -= take;
      eaten.add(true);
    }

    final avg = filled > 0 ? cost / filled : _asks.first.price;
    final best = _asks.first.price;
    final slippage = (avg - best) / best * 100;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Покупка по рынку',
      subtitle: 'Чем больше объём, тем глубже ты «съедаешь» стакан.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _asks.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: BlockSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      _asks[i].price.toStringAsFixed(1),
                      style: text.bodySmall?.copyWith(
                        color: eaten[i]
                            ? scheme.onSurfaceVariant
                            : BlockChartColors.error,
                        decoration:
                            eaten[i] ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${_asks[i].volume}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: BlockSpacing.s),
                  Expanded(
                    child: _VolumeBar(
                      fraction: _asks[i].volume / maxVol,
                      color: BlockChartColors.error,
                      dimmed: eaten[i],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: BlockSpacing.s),
          BlockSlider(
            tint: widget.tint,
            label: 'Лотов',
            valueLabel: '${_lots.round()}',
            value: _lots,
            min: 1,
            max: 30,
            divisions: 29,
            onChanged: (v) => setState(() => _lots = v),
          ),
          const SizedBox(height: BlockSpacing.m),
          Row(
            children: [
              Expanded(
                child: BlockMetric(
                  label: 'Средняя',
                  value: '${avg.toStringAsFixed(2)} ₽',
                  color: widget.tint,
                ),
              ),
              Expanded(
                child: BlockMetric(
                  label: 'Проскальзывание',
                  value: '${slippage.toStringAsFixed(2)}%',
                  color: slippage > 0.6
                      ? AppColors.warning
                      : BlockChartColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2. Лимитка против ожидания: слайдер цены, линия ездит по уровням стакана.
class LessonLimitOrWait extends StatefulWidget {
  const LessonLimitOrWait({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonLimitOrWait> createState() => _LessonLimitOrWaitState();
}

class _LessonLimitOrWaitState extends State<LessonLimitOrWait> {
  static const List<_Level> _asks = <_Level>[
    _Level(102.0, 4),
    _Level(101.5, 6),
    _Level(101.0, 3),
  ];
  static const List<_Level> _bids = <_Level>[
    _Level(100.5, 5),
    _Level(100.0, 7),
    _Level(99.5, 4),
  ];

  static const double _bestAsk = 101.0;

  double _price = 100.5;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final immediate = _price >= _bestAsk;
    const maxVol = 7;

    Widget row(_Level level, Color color, bool highlight) {
      return Padding(
        padding: const EdgeInsets.only(bottom: BlockSpacing.xs),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: highlight ? widget.tint.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  level.price.toStringAsFixed(1),
                  style: text.bodySmall?.copyWith(color: color),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${level.volume}',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: BlockSpacing.s),
              Expanded(
                child: _VolumeBar(
                  fraction: level.volume / maxVol,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final placedInBids = !immediate;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Лимитка: сразу или в очередь',
      subtitle: 'Цена лимитки решает: пересекаем спред или ждём встречную.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in _asks)
            row(a, BlockChartColors.error, immediate && a.price == _bestAsk),
          const Divider(height: BlockSpacing.s),
          if (placedInBids)
            Padding(
              padding: const EdgeInsets.only(bottom: BlockSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      _price.toStringAsFixed(1),
                      style: text.bodySmall?.copyWith(color: widget.tint),
                    ),
                  ),
                  Icon(Icons.schedule, size: 14, color: widget.tint),
                  const SizedBox(width: 6),
                  Text(
                    'твоя заявка в очереди',
                    style: text.bodySmall?.copyWith(color: widget.tint),
                  ),
                ],
              ),
            ),
          for (final b in _bids) row(b, BlockChartColors.success, false),
          const SizedBox(height: BlockSpacing.s),
          BlockSlider(
            tint: widget.tint,
            label: 'Цена лимитки',
            valueLabel: '${_price.toStringAsFixed(1)} ₽',
            value: _price,
            min: 99.5,
            max: 102.0,
            divisions: 5,
            onChanged: (v) => setState(() => _price = v),
          ),
          const SizedBox(height: BlockSpacing.s),
          Align(
            alignment: Alignment.centerLeft,
            child: BlockChip(
              text: immediate
                  ? 'исполнится сразу'
                  : 'встанет в очередь, ждёт встречную',
              tint: widget.tint,
              tone: immediate ? BlockTone.success : BlockTone.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. Мини-мэтчинг: два слайдера цен покупателя и продавца, сделка при пересечении.
class LessonMatchingMini extends StatefulWidget {
  const LessonMatchingMini({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonMatchingMini> createState() => _LessonMatchingMiniState();
}

class _LessonMatchingMiniState extends State<LessonMatchingMini>
    with SingleTickerProviderStateMixin {
  double _buy = 99;
  double _sell = 101;

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..addListener(() => setState(() {}));

  bool _wasMatched = false;

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  void _check() {
    final matched = _buy >= _sell;
    if (matched && !_wasMatched) {
      _flash.forward(from: 0);
    }
    _wasMatched = matched;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final matched = _buy >= _sell;

    // Карточка стороны заявки со статусом-чипом (Активна/Исполнена) —
    // кастомная плашка движка, оставлена как есть.
    Widget card(String title, double price, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(BlockSpacing.m),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BlockRadii.innerBr,
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.bodySmall),
              const SizedBox(height: 2),
              Text(
                '${price.toStringAsFixed(0)} ₽',
                style: text.titleMedium?.copyWith(color: color),
              ),
              const SizedBox(height: BlockSpacing.s),
              BlockChip(
                text: matched ? 'Исполнена' : 'Активна',
                tint: color,
                tone: matched ? BlockTone.success : BlockTone.accent,
              ),
            ],
          ),
        ),
      );
    }

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Как встречаются заявки',
      subtitle: 'Сделка происходит, когда покупатель готов платить не меньше, '
          'чем хочет продавец.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                card('Покупатель', _buy, BlockChartColors.success),
                const SizedBox(width: BlockSpacing.m),
                card('Продавец', _sell, BlockChartColors.error),
              ],
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          BlockSlider(
            tint: BlockChartColors.success,
            label: 'Покупка',
            valueLabel: _buy.toStringAsFixed(0),
            value: _buy,
            min: 95,
            max: 105,
            divisions: 10,
            onChanged: (v) => setState(() {
              _buy = v;
              _check();
            }),
          ),
          BlockSlider(
            tint: BlockChartColors.error,
            label: 'Продажа',
            valueLabel: _sell.toStringAsFixed(0),
            value: _sell,
            min: 95,
            max: 105,
            divisions: 10,
            onChanged: (v) => setState(() {
              _sell = v;
              _check();
            }),
          ),
          const SizedBox(height: BlockSpacing.s),
          if (matched)
            Opacity(
              opacity: (0.4 + _flash.value * 0.6).clamp(0.0, 1.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: BlockSpacing.m,
                  vertical: BlockSpacing.m,
                ),
                decoration: BoxDecoration(
                  color: widget.tint.withValues(alpha: 0.2),
                  borderRadius: BlockRadii.innerBr,
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt, size: 16, color: widget.tint),
                    const SizedBox(width: 6),
                    Text(
                      'СДЕЛКА по ${_sell.toStringAsFixed(0)} ₽',
                      style: text.titleSmall?.copyWith(color: widget.tint),
                    ),
                  ],
                ),
              ),
            )
          else
            Text(
              'Пока цены не пересеклись — обе заявки ждут.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// 4. Стакан против ленты: рыночная заявка снимает уровень и печатает сделку.
class LessonBookVsTape extends StatefulWidget {
  const LessonBookVsTape({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonBookVsTape> createState() => _LessonBookVsTapeState();
}

class _TapePrint {
  const _TapePrint(this.price, this.volume);

  final double price;
  final int volume;
}

class _LessonBookVsTapeState extends State<LessonBookVsTape>
    with SingleTickerProviderStateMixin {
  static const List<_Level> _initialAsks = <_Level>[
    _Level(101.0, 3),
    _Level(101.5, 5),
    _Level(102.0, 4),
    _Level(102.5, 8),
  ];

  late List<_Level> _asks = List<_Level>.of(_initialAsks);
  final List<_TapePrint> _tape = <_TapePrint>[];

  late final AnimationController _link = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..addListener(() => setState(() {}));

  void _marketHit() {
    if (_asks.isEmpty) {
      setState(() {
        _asks = List<_Level>.of(_initialAsks);
        _tape.clear();
      });
      return;
    }
    final top = _asks.first;
    setState(() {
      _asks = _asks.sublist(1);
      _tape.insert(0, _TapePrint(top.price, top.volume));
      if (_tape.length > 5) _tape.removeLast();
    });
    _link.forward(from: 0);
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Стакан и лента сделок',
      subtitle: 'Стакан — намерения. Лента — факт. Рыночная заявка превращает '
          'одно в другое.',
      footer: BlockButton(
        tint: widget.tint,
        label: _asks.isEmpty ? 'Сбросить' : 'Прилетела рыночная',
        icon: Icons.flash_on,
        fullWidth: false,
        onPressed: _marketHit,
      ),
      // Кастомная визуализация движка: два столбца (стакан/лента) со
      // связкой-анимацией снятия уровня — суть блока, не упрощаем.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Стакан (asks)', style: text.bodySmall),
                  const SizedBox(height: 6),
                  for (var i = 0; i < _asks.length; i++)
                    Opacity(
                      opacity:
                          i == 0 ? (1 - _link.value).clamp(0.3, 1.0) : 1,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: BlockSpacing.xs),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(
                                _asks[i].price.toStringAsFixed(1),
                                style: text.bodySmall?.copyWith(
                                  color: BlockChartColors.error,
                                ),
                              ),
                            ),
                            Text(
                              '${_asks[i].volume}',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_asks.isEmpty)
                    Text(
                      'уровни сняты',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BlockSpacing.s),
              child: Icon(
                Icons.east,
                size: 18,
                color: widget.tint.withValues(
                  alpha: (0.3 + _link.value * 0.7).clamp(0.0, 1.0),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Лента', style: text.bodySmall),
                  const SizedBox(height: 6),
                  if (_tape.isEmpty)
                    Text(
                      'пока пусто',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  for (var i = 0; i < _tape.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: BlockSpacing.xs),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              _tape[i].price.toStringAsFixed(1),
                              style: text.bodySmall?.copyWith(
                                color:
                                    i == 0 ? widget.tint : scheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${_tape[i].volume}',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5. Гэп и стоп: слайдер уровня стопа, выбор стоп-маркет/стоп-лимит, гэп вниз.
class LessonGapStop extends StatefulWidget {
  const LessonGapStop({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonGapStop> createState() => _LessonGapStopState();
}

class _LessonGapStopState extends State<LessonGapStop> {
  static const List<double> _series = <double>[
    100, 99, 98.5, 99.5, 98, 97, 97.5, 96.5, 95.5, 96,
  ];

  double _stop = 95;
  bool _isMarket = true;
  bool _gapped = false;

  static const double _gapTo = 92.5;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final triggered = _gapped;
    const marketFill = _gapTo;
    final lineColor = widget.tint;

    String result;
    Color resultColor;
    if (!_gapped) {
      result = 'Стоп на ${_stop.toStringAsFixed(1)} ₽ ждёт. Открытие гэпом — '
          'и цену перепрыгнут.';
      resultColor = scheme.onSurfaceVariant;
    } else if (_isMarket) {
      result = 'Стоп-маркет исполнен по ${marketFill.toStringAsFixed(1)} ₽ — '
          'ниже стопа. Гэп проскочил уровень.';
      resultColor = AppColors.warning;
    } else {
      result = 'Стоп-лимит на ${_stop.toStringAsFixed(1)} ₽ не исполнен: '
          'цена ушла ниже лимита, заявка висит.';
      resultColor = BlockChartColors.error;
    }

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Гэп и стоп-заявка',
      subtitle:
          'На открытии цена может прыгнуть мимо стопа. Тип стопа решает исход.',
      footer: BlockButton(
        tint: widget.tint,
        label: _gapped ? 'Сброс' : 'Открытие гэпом',
        fullWidth: false,
        onPressed: () => setState(() => _gapped = !_gapped),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Кастомный painter: линия цены, пунктир стопа, прыжок гэпом вниз —
          // суть блока, не заменяется blockLineChart.
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _GapChartPainter(
                series: _series,
                stop: _stop,
                gapTo: _gapped ? _gapTo : null,
                lineColor: lineColor,
                gridColor: BlockChartColors.grid(scheme),
                stopColor: AppColors.warning,
                fillColor: triggered
                    ? (_isMarket ? AppColors.warning : BlockChartColors.error)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.s),
          BlockSlider(
            tint: widget.tint,
            label: 'Стоп',
            valueLabel: _stop.toStringAsFixed(1),
            value: _stop,
            min: 90,
            max: 99,
            divisions: 18,
            onChanged: (v) => setState(() => _stop = v),
          ),
          const SizedBox(height: BlockSpacing.s),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Стоп-маркет'),
                selected: _isMarket,
                selectedColor: widget.tint.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _isMarket = true),
              ),
              const SizedBox(width: BlockSpacing.s),
              ChoiceChip(
                label: const Text('Стоп-лимит'),
                selected: !_isMarket,
                selectedColor: widget.tint.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _isMarket = false),
              ),
            ],
          ),
          const SizedBox(height: BlockSpacing.s),
          Text(result, style: text.bodySmall?.copyWith(color: resultColor)),
        ],
      ),
    );
  }
}

/// Рисует mini-график цены, уровень стопа и прыжок гэпом вниз.
class _GapChartPainter extends CustomPainter {
  _GapChartPainter({
    required this.series,
    required this.stop,
    required this.gapTo,
    required this.lineColor,
    required this.gridColor,
    required this.stopColor,
    required this.fillColor,
  });

  final List<double> series;
  final double stop;
  final double? gapTo;
  final Color lineColor;
  final Color gridColor;
  final Color stopColor;
  final Color fillColor;

  static const double _min = 90;
  static const double _max = 101;

  double _y(double price, double h) {
    final t = (price - _min) / (_max - _min);
    return h - t.clamp(0.0, 1.0) * h;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height / 4 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final step = size.width / (series.length + 1);
    final path = Path();
    for (var i = 0; i < series.length; i++) {
      final x = step * (i + 1);
      final y = _y(series[i], size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final lastX = step * series.length;
    final lastY = _y(series.last, size.height);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, linePaint);

    // Уровень стопа.
    final stopY = _y(stop, size.height);
    final stopPaint = Paint()
      ..color = stopColor
      ..strokeWidth = 1.5;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, stopY), Offset(x + 6, stopY), stopPaint);
      x += 12;
    }

    if (gapTo != null) {
      final gapX = size.width - step * 0.5;
      final gapY = _y(gapTo!, size.height);
      final gapPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(Offset(lastX, lastY), Offset(gapX, gapY), gapPaint);
      canvas.drawCircle(
        Offset(gapX, gapY),
        4,
        Paint()..color = fillColor,
      );
    } else {
      canvas.drawCircle(
        Offset(lastX, lastY),
        3,
        Paint()..color = lineColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GapChartPainter old) {
    return old.stop != stop ||
        old.gapTo != gapTo ||
        old.fillColor != fillColor ||
        old.lineColor != lineColor;
  }
}
