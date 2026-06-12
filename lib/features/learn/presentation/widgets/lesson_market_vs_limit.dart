import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Тренажёр «рыночная против лимитной»: пользователь покупает одну и ту же
/// бумагу двумя способами и проживает разницу прямо в мини-стакане.
/// Рыночная съедает лучшую цену продавца — уровень подсвечивается отметкой
/// сделки. Лимитная встаёт строкой «твоя заявка» на своё место по цене,
/// затем цена идёт по детерминированному пути: дошла до лимита — исполнение,
/// нет — заявка так и стоит. Когда испробованы оба способа, появляется
/// вывод-сравнение. Оба сценария можно сбросить и попробовать снова.
class LessonMarketVsLimit extends StatefulWidget {
  const LessonMarketVsLimit({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonMarketVsLimit> createState() => _LessonMarketVsLimitState();
}

enum _Mode { market, limit }

enum _LimitPhase { idle, waiting, filled, missed }

class _Lvl {
  const _Lvl(this.price, this.vol);
  final double price;
  final int vol;
}

class _LessonMarketVsLimitState extends State<LessonMarketVsLimit>
    with SingleTickerProviderStateMixin {
  /// Продавцы (аски), сверху вниз к центру: лучшая цена — последняя.
  static const _asks = <_Lvl>[
    _Lvl(101.4, 60),
    _Lvl(101.2, 85),
    _Lvl(101.0, 120),
  ];

  /// Покупатели (биды), от центра вниз: лучшая цена — первая.
  static const _bids = <_Lvl>[
    _Lvl(100.8, 90),
    _Lvl(100.6, 140),
    _Lvl(100.4, 60),
  ];

  static double get _bestAsk => _asks.last.price;
  static double get _bestBid => _bids.first.price;

  /// Путь цены после выставления лимитной: сползает вниз, разворачивается
  /// и уходит вверх. Минимум 100.4 — лимиты ниже не исполнятся.
  static const List<double> _path = [
    100.9, 100.8, 100.7, 100.6, 100.5, 100.4, 100.5, 100.7, 100.9, 101.1, 101.3,
  ];

  _Mode _mode = _Mode.market;
  double _limitPrice = 100.5;

  /// Видимое состояние эксперимента «по рынку» (сбрасывается кнопкой).
  bool _marketDone = false;
  _LimitPhase _limitPhase = _LimitPhase.idle;
  double? _limitFillPrice;

  /// «Опыт получен» — липкие флаги для вывода-сравнения, сброс их не трогает.
  bool _marketTried = false;
  bool _limitTried = false;

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
    final progressed = (_path.length - 1) * _anim.value;
    final lastIndex = progressed.floor();
    for (var i = 0; i <= lastIndex && i < _path.length; i++) {
      if (_path[i] <= _limitPrice) {
        _anim.stop();
        setState(() {
          _limitPhase = _LimitPhase.filled;
          _limitFillPrice = _limitPrice;
          _limitTried = true;
        });
        return;
      }
    }
    if (_anim.isCompleted) {
      setState(() {
        _limitPhase = _LimitPhase.missed;
        _limitTried = true;
      });
      return;
    }
    setState(() {});
  }

  void _buyMarket() => setState(() {
        _marketDone = true;
        _marketTried = true;
      });

  void _resetMarket() => setState(() => _marketDone = false);

  void _placeLimit() {
    if (_limitPrice >= _bestAsk) {
      // Встречная цена уже не хуже лимита — исполнение сразу по ней,
      // и не дороже твоей цены.
      setState(() {
        _limitPhase = _LimitPhase.filled;
        _limitFillPrice = _bestAsk;
        _limitTried = true;
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

  /// Лимитная стоит в стакане (не мгновенное исполнение по встречной).
  bool get _limitResting =>
      _limitPhase != _LimitPhase.idle && _limitFillPrice != _bestAsk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final dealAtAsk = (_mode == _Mode.market && _marketDone) ||
        (_mode == _Mode.limit &&
            _limitPhase == _LimitPhase.filled &&
            _limitFillPrice == _bestAsk);

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Рыночная или лимитная?',
      subtitle: 'Купи одну и ту же бумагу двумя способами.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Ladder(
            asks: _asks,
            bids: _bids,
            tint: widget.tint,
            dealAtBestAsk: dealAtAsk,
            yourPrice: _mode == _Mode.limit && _limitResting ? _limitPrice : null,
            yourPhase: _limitPhase,
          ),
          const SizedBox(height: BlockSpacing.m),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'По рынку',
                  selected: _mode == _Mode.market,
                  tint: widget.tint,
                  done: _marketTried,
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
          if (_marketTried && _limitTried) ...[
            const SizedBox(height: BlockSpacing.l),
            _Summary(tint: widget.tint),
          ],
        ],
      ),
    );
  }

  Widget _retryButton(ColorScheme scheme, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
        ),
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
          'Сделка прошла по лучшей цене продавцов — смотри отметку в стакане. '
          'Мгновенно, но это ${_bestAsk.toStringAsFixed(2)} ₽, а не '
          '${_bestBid.toStringAsFixed(2)} ₽, которые предлагали покупатели.',
          style: text.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: BlockSpacing.s),
        _retryButton(scheme, 'Попробовать снова', _resetMarket),
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
        final instantFill = _limitFillPrice == _bestAsk;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!instantFill) ...[
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
            ],
            if (_limitPhase == _LimitPhase.waiting)
              Text(
                'Твоя заявка встала в стакан по '
                '${_limitPrice.toStringAsFixed(2)} ₽ — видишь её среди '
                'покупателей? Ждём, дойдёт ли цена…',
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
                    ? (instantFill
                        ? 'Твоя цена была не хуже встречной — заявка исполнилась '
                            'сразу по лучшей цене продавцов, смотри отметку в '
                            'стакане. И не дороже твоей цены.'
                        : 'Цена спустилась до твоей линии — сделка по твоей цене, '
                            'дешевле, чем «по рынку». Но этого могло и не случиться.')
                    : 'Рынок развернулся, не дойдя до твоей цены. Заявка стоит '
                        'в стакане дальше: можно оставить, передвинуть или отменить.',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: BlockSpacing.s),
              _retryButton(scheme, 'Попробовать другую цену', _resetLimit),
            ],
          ],
        );
    }
  }
}

/// Мини-стакан лесенкой: продавцы сверху, покупатели снизу, спред между ними.
/// Умеет показывать отметку сделки на лучшем аске и строку «твоя заявка».
class _Ladder extends StatelessWidget {
  const _Ladder({
    required this.asks,
    required this.bids,
    required this.tint,
    required this.dealAtBestAsk,
    required this.yourPrice,
    required this.yourPhase,
  });

  final List<_Lvl> asks;
  final List<_Lvl> bids;
  final Color tint;

  /// Подсветить лучший аск как «здесь прошла сделка».
  final bool dealAtBestAsk;

  /// Цена стоящей в стакане лимитной заявки (null — заявки нет).
  final double? yourPrice;
  final _LimitPhase yourPhase;

  @override
  Widget build(BuildContext context) {
    final maxVol =
        [...asks, ...bids].map((l) => l.vol).reduce((a, b) => a > b ? a : b);

    final rows = <Widget>[];
    for (final a in asks) {
      final isDeal = dealAtBestAsk && a.price == asks.last.price;
      rows.add(_LadderRow(
        price: a.price,
        vol: a.vol,
        maxVol: maxVol,
        color: BlockChartColors.error,
        deal: isDeal,
        tint: tint,
      ));
    }

    rows.add(_SpreadDivider(
      spread: asks.last.price - bids.first.price,
    ));

    var yourPending = yourPrice != null;
    for (final b in bids) {
      if (yourPending && yourPrice! > b.price) {
        rows.add(_YourRow(price: yourPrice!, phase: yourPhase, tint: tint));
        yourPending = false;
      }
      rows.add(_LadderRow(
        price: b.price,
        vol: b.vol,
        maxVol: maxVol,
        color: BlockChartColors.success,
        deal: false,
        tint: tint,
      ));
    }
    if (yourPending) {
      rows.add(_YourRow(price: yourPrice!, phase: yourPhase, tint: tint));
    }

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(BlockSpacing.m),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BlockRadii.innerBr,
        border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('продают',
                  style: text.labelMedium?.copyWith(
                      color: BlockChartColors.error, fontSize: 11)),
              const Spacer(),
              Text('СТАКАН',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  )),
            ],
          ),
          const SizedBox(height: BlockSpacing.xs),
          ...rows,
          const SizedBox(height: BlockSpacing.xs),
          Text('покупают',
              style: text.labelMedium?.copyWith(
                  color: BlockChartColors.success, fontSize: 11)),
        ],
      ),
    );
  }
}

class _LadderRow extends StatelessWidget {
  const _LadderRow({
    required this.price,
    required this.vol,
    required this.maxVol,
    required this.color,
    required this.deal,
    required this.tint,
  });

  final double price;
  final int vol;
  final int maxVol;
  final Color color;
  final bool deal;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final frac = (vol / maxVol).clamp(0.12, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 28,
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      decoration: deal
          ? BoxDecoration(
              color: BlockChartColors.success.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: BlockChartColors.success),
            )
          : null,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (!deal)
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BlockSpacing.s),
            child: Row(
              children: [
                Text(
                  price.toStringAsFixed(2),
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: BlockSpacing.s),
                Text(
                  '$vol',
                  style:
                      text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                if (deal) ...[
                  const Icon(Icons.bolt,
                      size: 14, color: BlockChartColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'сделка прошла здесь',
                    style: text.labelMedium?.copyWith(
                      color: BlockChartColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка лимитной заявки пользователя в лесенке.
class _YourRow extends StatelessWidget {
  const _YourRow({
    required this.price,
    required this.phase,
    required this.tint,
  });

  final double price;
  final _LimitPhase phase;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final filled = phase == _LimitPhase.filled;
    final color = filled ? BlockChartColors.success : tint;
    final (IconData icon, String label) = switch (phase) {
      _LimitPhase.filled => (Icons.bolt, 'исполнена'),
      _LimitPhase.missed => (Icons.schedule, 'так и ждёт'),
      _ => (Icons.schedule, 'ждёт'),
    };

    return Container(
      height: 28,
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: BlockSpacing.s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Text(
            price.toStringAsFixed(2),
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: BlockSpacing.s),
          Text(
            'твоя заявка',
            style: text.labelMedium?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: text.labelMedium?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpreadDivider extends StatelessWidget {
  const _SpreadDivider({required this.spread});

  final double spread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: scheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BlockSpacing.s),
            child: Text(
              'спред ${spread.toStringAsFixed(2)} ₽',
              style: text.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: scheme.outlineVariant)),
        ],
      ),
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
