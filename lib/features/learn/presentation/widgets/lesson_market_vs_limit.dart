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


class _LessonMarketVsLimitState extends State<LessonMarketVsLimit>
    with SingleTickerProviderStateMixin {
  /// Продавцы, сверху вниз к центру: лучшая (нижняя) цена — последняя.
  static const _asks = <double>[101.4, 101.2, 101.0];

  /// Покупатели, от центра вниз: лучшая (верхняя) цена — первая.
  static const _bids = <double>[100.8, 100.6, 100.4];

  static double get _bestAsk => _asks.last;
  static double get _bestBid => _bids.first;

  /// Путь цены после выставления лимитной: сползает вниз, разворачивается
  /// и уходит вверх. Минимум 100.4 — лимиты ниже не исполнятся.
  static const List<double> _path = [
    100.9, 100.8, 100.7, 100.6, 100.5, 100.4, 100.5, 100.7, 100.9, 101.1, 101.3,
  ];

  _Mode _mode = _Mode.market;
  double _limitPrice = 100.5;

  /// Минимум, до которого цена уже спускалась в текущем прогоне лимитной:
  /// покупатели с ценой выше уже получили свои сделки — их строки «тают».
  double? _minReached;

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
    var minSoFar = _path.first;
    for (var i = 0; i <= lastIndex && i < _path.length; i++) {
      if (_path[i] < minSoFar) minSoFar = _path[i];
      if (_path[i] <= _limitPrice) {
        _anim.stop();
        setState(() {
          _minReached = minSoFar;
          _limitPhase = _LimitPhase.filled;
          _limitFillPrice = _limitPrice;
          _limitTried = true;
        });
        return;
      }
    }
    if (_anim.isCompleted) {
      setState(() {
        _minReached = minSoFar;
        _limitPhase = _LimitPhase.missed;
        _limitTried = true;
      });
      return;
    }
    setState(() => _minReached = minSoFar);
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
    setState(() {
      _limitPhase = _LimitPhase.waiting;
      _minReached = _path.first;
    });
    _anim.forward(from: 0);
  }

  void _resetLimit() {
    _anim.stop();
    setState(() {
      _limitPhase = _LimitPhase.idle;
      _limitFillPrice = null;
      _minReached = null;
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
            meltBelow:
                _mode == _Mode.limit && _limitResting ? _minReached : null,
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
          'Сделка прошла у продавца с самой выгодной ценой — смотри отметку. '
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
                'Ты встал в очередь покупателей со своей ценой '
                '${_limitPrice.toStringAsFixed(2)} ₽. Смотри: пока цена '
                'спускается, покупатели выше получают сделки раньше тебя…',
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
                        ? 'Твоя цена оказалась не хуже, чем просит продавец, — '
                            'сделка прошла сразу, смотри отметку. И не дороже '
                            'твоей цены.'
                        : 'Цена спустилась до твоей линии — сделка по твоей цене, '
                            'дешевле, чем «по рынку». Но этого могло и не случиться.')
                    : 'Очередь перед тобой растаяла, но цена развернулась, чуть '
                        'не дойдя. Заявка стоит дальше: можно оставить, '
                        'передвинуть или отменить.',
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

/// Очередь предложений: продавцы сверху, покупатели снизу. Без биржевых
/// терминов — каждая строка читается как живой участник («продавец просит»,
/// «покупатель готов»). Умеет отмечать сделку у лучшего продавца и показывать
/// строку «ты»; покупатели перед твоей заявкой «тают», когда цена проходит
/// их уровень — они получают свои сделки раньше тебя.
class _Ladder extends StatelessWidget {
  const _Ladder({
    required this.asks,
    required this.bids,
    required this.tint,
    required this.dealAtBestAsk,
    required this.yourPrice,
    required this.yourPhase,
    required this.meltBelow,
  });

  final List<double> asks;
  final List<double> bids;
  final Color tint;

  /// Отметить сделку у лучшего (нижнего) продавца.
  final bool dealAtBestAsk;

  /// Цена стоящей в очереди лимитной заявки (null — заявки нет).
  final double? yourPrice;
  final _LimitPhase yourPhase;

  /// Минимум, до которого уже спускалась цена: покупатели с ценой выше
  /// получили сделки — их строки растаяли.
  final double? meltBelow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final rows = <Widget>[];
    for (final price in asks) {
      final isDeal = dealAtBestAsk && price == asks.last;
      rows.add(_PersonRow(
        price: price,
        seller: true,
        deal: isDeal,
        melted: false,
      ));
    }

    rows.add(const _MeetDivider());

    var yourPending = yourPrice != null;
    for (final price in bids) {
      if (yourPending && yourPrice! > price) {
        rows.add(_YourRow(price: yourPrice!, phase: yourPhase, tint: tint));
        yourPending = false;
      }
      rows.add(_PersonRow(
        price: price,
        seller: false,
        deal: false,
        melted: meltBelow != null && meltBelow! <= price,
      ));
    }
    if (yourPending) {
      rows.add(_YourRow(price: yourPrice!, phase: yourPhase, tint: tint));
    }

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
          Text('хотят продать — и просят:',
              style: text.labelMedium?.copyWith(
                  color: BlockChartColors.error, fontSize: 11)),
          const SizedBox(height: BlockSpacing.xs),
          ...rows,
          const SizedBox(height: BlockSpacing.xs),
          Text('хотят купить — и готовы дать:',
              style: text.labelMedium?.copyWith(
                  color: BlockChartColors.success, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Строка участника: «продавец · цена» или «покупатель · цена».
/// Растаявший покупатель уже получил свою сделку и ушёл из очереди.
class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.price,
    required this.seller,
    required this.deal,
    required this.melted,
  });

  final double price;
  final bool seller;
  final bool deal;
  final bool melted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = seller ? BlockChartColors.error : BlockChartColors.success;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: melted ? 0.35 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 30,
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: BlockSpacing.s),
        decoration: BoxDecoration(
          color: deal
              ? BlockChartColors.success.withValues(alpha: 0.14)
              : color.withValues(alpha: melted ? 0.04 : 0.10),
          borderRadius: BorderRadius.circular(8),
          border: deal ? Border.all(color: BlockChartColors.success) : null,
        ),
        child: Row(
          children: [
            Icon(
              seller ? Icons.sell_outlined : Icons.person_outline,
              size: 15,
              color: melted ? scheme.onSurfaceVariant : color,
            ),
            const SizedBox(width: 6),
            Text(
              seller ? 'продавец' : 'покупатель',
              style: text.bodySmall?.copyWith(
                color: melted ? scheme.onSurfaceVariant : scheme.onSurface,
                decoration: melted ? TextDecoration.lineThrough : null,
              ),
            ),
            const Spacer(),
            if (deal) ...[
              const Icon(Icons.bolt, size: 14, color: BlockChartColors.success),
              const SizedBox(width: 4),
              Text(
                'ты купил у него',
                style: text.labelMedium?.copyWith(
                  color: BlockChartColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: BlockSpacing.s),
            ] else if (melted) ...[
              Text(
                'уже купил',
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: BlockSpacing.s),
            ],
            Text(
              '${price.toStringAsFixed(2)} ₽',
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: melted ? scheme.onSurfaceVariant : scheme.onSurface,
                decoration: melted ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Строка твоей лимитной заявки в очереди покупателей.
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
      _LimitPhase.filled => (Icons.bolt, 'купил!'),
      _LimitPhase.missed => (Icons.schedule, 'так и ждёшь'),
      _ => (Icons.schedule, 'ждёшь своей цены'),
    };

    return Container(
      height: 30,
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: BlockSpacing.s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Row(
        children: [
          Icon(Icons.face, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            'ты',
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
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
          const SizedBox(width: BlockSpacing.s),
          Text(
            '${price.toStringAsFixed(2)} ₽',
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Разделитель между продавцами и покупателями: здесь цены ещё не сошлись.
class _MeetDivider extends StatelessWidget {
  const _MeetDivider();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: List.generate(
          24,
          (i) => Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: scheme.outlineVariant,
            ),
          ),
        ),
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
