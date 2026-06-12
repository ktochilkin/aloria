import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Тренажёр «рыночная против лимитной»: пользователь покупает одну и ту же
/// бумагу двумя способами и проживает разницу. Рыночная исполняется сразу по
/// цене продавца. Лимитная встаёт в очередь по своей цене, затем цена ходит
/// по детерминированному пути: дошла до лимита — исполнение, нет — заявка так
/// и ждёт. Когда испробованы оба способа, появляется вывод-сравнение.
class LessonMarketVsLimit extends StatefulWidget {
  const LessonMarketVsLimit({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonMarketVsLimit> createState() => _LessonMarketVsLimitState();
}

enum _Mode { market, limit }

enum _LimitPhase { idle, waiting, filled, missed }

class _LessonMarketVsLimitState extends State<LessonMarketVsLimit>
    with SingleTickerProviderStateMixin {
  /// Лучшая цена продавца (аск): по ней исполнится покупка «по рынку».
  static const double _bestAsk = 101.0;

  /// Лучшая цена покупателя (бид).
  static const double _bestBid = 100.8;

  /// Путь цены после выставления лимитной: сползает вниз, разворачивается
  /// и уходит вверх. Минимум 100.4 — лимиты ниже не исполнятся.
  static const List<double> _path = [
    100.9, 100.8, 100.7, 100.6, 100.5, 100.4, 100.5, 100.7, 100.9, 101.1, 101.3,
  ];

  _Mode _mode = _Mode.market;
  double _limitPrice = 100.5;

  bool _marketDone = false;
  _LimitPhase _limitPhase = _LimitPhase.idle;

  /// Цена, по которой исполнилась лимитная (равна лимиту или лучше).
  double? _limitFillPrice;

  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..addListener(_onTick);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onTick() {
    if (_limitPhase != _LimitPhase.waiting) {
      setState(() {});
      return;
    }
    // Дошла ли цена до лимита на уже пройденной части пути.
    final progressed = (_path.length - 1) * _anim.value;
    final lastIndex = progressed.floor();
    for (var i = 0; i <= lastIndex && i < _path.length; i++) {
      if (_path[i] <= _limitPrice) {
        _anim.stop();
        setState(() {
          _limitPhase = _LimitPhase.filled;
          _limitFillPrice = _limitPrice;
        });
        return;
      }
    }
    if (_anim.isCompleted) {
      setState(() => _limitPhase = _LimitPhase.missed);
      return;
    }
    setState(() {});
  }

  void _buyMarket() => setState(() => _marketDone = true);

  void _placeLimit() {
    if (_limitPrice >= _bestAsk) {
      // Встречная цена в стакане уже лучше лимита — исполняется сразу,
      // и не дороже твоей цены.
      setState(() {
        _limitPhase = _LimitPhase.filled;
        _limitFillPrice = _bestAsk;
      });
      return;
    }
    setState(() => _limitPhase = _LimitPhase.waiting);
    _anim.forward(from: 0);
  }

  void _resetLimit() {
    _anim.stop();
    setState(() {
      _limitPhase = _LimitPhase.idle;
      _limitFillPrice = null;
    });
  }

  bool get _limitTried =>
      _limitPhase == _LimitPhase.filled || _limitPhase == _LimitPhase.missed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Рыночная или лимитная?',
      subtitle: 'Купи одну и ту же бумагу двумя способами.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MiniBook(bestBid: _bestBid, bestAsk: _bestAsk),
          const SizedBox(height: BlockSpacing.m),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'По рынку',
                  selected: _mode == _Mode.market,
                  tint: widget.tint,
                  done: _marketDone,
                  onTap: () => setState(() => _mode = _Mode.market),
                ),
              ),
              const SizedBox(width: BlockSpacing.s),
              Expanded(
                child: _ModeButton(
                  label: 'По своей цене',
                  selected: _mode == _Mode.limit,
                  tint: widget.tint,
                  done: _limitTried,
                  onTap: () => setState(() => _mode = _Mode.limit),
                ),
              ),
            ],
          ),
          const SizedBox(height: BlockSpacing.m),
          if (_mode == _Mode.market)
            _marketPane(text, scheme)
          else
            _limitPane(text, scheme),
          if (_marketDone && _limitTried) ...[
            const SizedBox(height: BlockSpacing.l),
            _Summary(tint: widget.tint),
          ],
        ],
      ),
    );
  }

  Widget _marketPane(TextTheme text, ColorScheme scheme) {
    if (!_marketDone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Рыночная заявка не выбирает цену: берёт лучшее, что есть '
            'у продавцов прямо сейчас.',
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          BlockButton(
            tint: widget.tint,
            label: 'Купить по рынку',
            icon: Icons.bolt,
            onPressed: _buyMarket,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BlockChip(
              text: 'исполнена сразу',
              tint: widget.tint,
              tone: BlockTone.success,
            ),
            const Spacer(),
            BlockMetric(
              label: 'цена сделки',
              value: '${_bestAsk.toStringAsFixed(2)} ₽',
              color: widget.tint,
            ),
          ],
        ),
        const SizedBox(height: BlockSpacing.s),
        Text(
          'Мгновенно — но по цене продавца: ${_bestAsk.toStringAsFixed(2)} ₽, '
          'а не ${_bestBid.toStringAsFixed(2)} ₽, которые ты видел у покупателей.',
          style: text.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _limitPane(TextTheme text, ColorScheme scheme) {
    switch (_limitPhase) {
      case _LimitPhase.idle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlockSlider(
              tint: widget.tint,
              label: 'Моя цена',
              valueLabel: '${_limitPrice.toStringAsFixed(2)} ₽',
              value: _limitPrice,
              min: 100.0,
              max: 101.4,
              divisions: 14,
              onChanged: (v) => setState(() => _limitPrice = v),
            ),
            const SizedBox(height: BlockSpacing.s),
            BlockButton(
              tint: widget.tint,
              label: 'Выставить заявку',
              icon: Icons.schedule,
              onPressed: _placeLimit,
            ),
          ],
        );
      case _LimitPhase.waiting:
      case _LimitPhase.filled:
      case _LimitPhase.missed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 110,
              width: double.infinity,
              child: CustomPaint(
                painter: _PathPainter(
                  path: _path,
                  progress:
                      _limitPhase == _LimitPhase.waiting ? _anim.value : 1.0,
                  limit: _limitPrice,
                  fillPrice: _limitFillPrice,
                  tint: widget.tint,
                  grid: BlockChartColors.grid(scheme),
                  muted: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: BlockSpacing.s),
            if (_limitPhase == _LimitPhase.waiting)
              Text(
                'Заявка в стакане по ${_limitPrice.toStringAsFixed(2)} ₽. '
                'Ждём, дойдёт ли цена…',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              )
            else ...[
              Row(
                children: [
                  BlockChip(
                    text: _limitPhase == _LimitPhase.filled
                        ? 'исполнена'
                        : 'так и не исполнилась',
                    tint: widget.tint,
                    tone: _limitPhase == _LimitPhase.filled
                        ? BlockTone.success
                        : BlockTone.error,
                  ),
                  const Spacer(),
                  if (_limitPhase == _LimitPhase.filled)
                    BlockMetric(
                      label: 'цена сделки',
                      value: '${_limitFillPrice!.toStringAsFixed(2)} ₽',
                      color: widget.tint,
                    ),
                ],
              ),
              const SizedBox(height: BlockSpacing.s),
              Text(
                _limitPhase == _LimitPhase.filled
                    ? (_limitFillPrice == _bestAsk
                        ? 'Твоя цена была не хуже встречной — заявка исполнилась '
                            'сразу, причём по лучшей цене из стакана.'
                        : 'Цена спустилась до твоей линии — сделка по твоей цене, '
                            'дешевле, чем «по рынку». Но этого могло и не случиться.')
                    : 'Рынок развернулся, не дойдя до твоей цены. Заявка ждёт '
                        'дальше: можно оставить, передвинуть или отменить.',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: BlockSpacing.s),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _resetLimit,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Попробовать другую цену'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    side: BorderSide(color: scheme.outline),
                  ),
                ),
              ),
            ],
          ],
        );
    }
  }
}

/// Компактный стакан: лучший покупатель и лучший продавец.
class _MiniBook extends StatelessWidget {
  const _MiniBook({required this.bestBid, required this.bestAsk});

  final double bestBid;
  final double bestAsk;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget side(String label, double price, Color color, bool alignEnd) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BlockSpacing.m,
            vertical: BlockSpacing.s,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BlockRadii.innerBr,
          ),
          child: Column(
            crossAxisAlignment:
                alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.labelMedium?.copyWith(color: color, fontSize: 11),
              ),
              Text(
                '${price.toStringAsFixed(2)} ₽',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        side('покупатели готовы по', bestBid, BlockChartColors.success, false),
        const SizedBox(width: BlockSpacing.s),
        side('продавцы просят', bestAsk, BlockChartColors.error, true),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.tint,
    required this.done,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color tint;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: BlockSpacing.m),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? BlockTint.soft(tint) : scheme.surface,
          borderRadius: BlockRadii.innerBr,
          border: Border.all(
            color: selected ? tint : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done) ...[
              const Icon(Icons.check, size: 14, color: BlockChartColors.success),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: text.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Вывод после обоих экспериментов.
class _Summary extends StatelessWidget {
  const _Summary({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget row(IconData icon, String title, String body) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: BlockSpacing.s),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: text.bodySmall?.copyWith(height: 1.4),
                children: [
                  TextSpan(
                    text: '$title — ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: body,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(BlockSpacing.m),
      decoration: BoxDecoration(
        color: BlockTint.soft(tint),
        borderRadius: BlockRadii.innerBr,
      ),
      child: Column(
        children: [
          row(Icons.bolt, 'Рыночная',
              'гарантирует сделку прямо сейчас, но цену выбирает рынок.'),
          const SizedBox(height: BlockSpacing.s),
          row(Icons.schedule, 'Лимитная',
              'гарантирует твою цену, но не гарантирует саму сделку.'),
        ],
      ),
    );
  }
}

/// Спарклайн пути цены с линией лимита и точкой исполнения.
class _PathPainter extends CustomPainter {
  _PathPainter({
    required this.path,
    required this.progress,
    required this.limit,
    required this.fillPrice,
    required this.tint,
    required this.grid,
    required this.muted,
  });

  final List<double> path;
  final double progress;
  final double limit;
  final double? fillPrice;
  final Color tint;
  final Color grid;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    const lo = 100.0;
    const hi = 101.4;
    double y(double v) => size.height * (1 - (v - lo) / (hi - lo));
    double x(int i) => size.width * i / (path.length - 1);

    // Линия лимита — пунктир.
    final limitY = y(limit);
    final dash = Paint()
      ..color = muted.withValues(alpha: 0.7)
      ..strokeWidth = 1.4;
    var dx = 0.0;
    while (dx < size.width) {
      canvas.drawLine(Offset(dx, limitY), Offset(dx + 6, limitY), dash);
      dx += 11;
    }

    // Пройденная часть пути цены.
    final shown = ((path.length - 1) * progress).clamp(0, path.length - 1.0);
    final line = Paint()
      ..color = tint
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final p = Path()..moveTo(x(0), y(path[0]));
    final fullSegments = shown.floor();
    for (var i = 1; i <= fullSegments; i++) {
      p.lineTo(x(i), y(path[i]));
    }
    final frac = shown - fullSegments;
    if (frac > 0 && fullSegments + 1 < path.length) {
      final yv = path[fullSegments] +
          (path[fullSegments + 1] - path[fullSegments]) * frac;
      p.lineTo(
        x(fullSegments) + (x(fullSegments + 1) - x(fullSegments)) * frac,
        y(yv),
      );
    }
    canvas.drawPath(p, line);

    // Точка исполнения — там, где путь впервые коснулся лимита.
    if (fillPrice != null) {
      var fillIndex = 0;
      for (var i = 0; i < path.length; i++) {
        if (path[i] <= limit) {
          fillIndex = i;
          break;
        }
      }
      final dot = Paint()..color = BlockChartColors.success;
      canvas.drawCircle(Offset(x(fillIndex), y(path[fillIndex])), 5, dot);
    }

    // Подпись лимита.
    final tp = TextPainter(
      text: TextSpan(
        text: 'твоя цена ${limit.toStringAsFixed(2)}',
        style: TextStyle(
          color: muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelY =
        limitY > size.height / 2 ? limitY - tp.height - 3 : limitY + 3;
    tp.paint(canvas, Offset(0, labelY));
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.progress != progress ||
      old.limit != limit ||
      old.fillPrice != fillPrice;
}
