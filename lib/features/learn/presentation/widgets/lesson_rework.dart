import 'dart:math' as math;

import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Переработанные блоки после ревью (старые реализации были слабыми).
/// Собраны на block_kit (стиль «воздух»): карточка-обёртка [LessonBlockCard],
/// слайдеры [BlockSlider], статусы/результаты [BlockChip], числа [BlockMetric].
/// Кастомные части (painter стакана, стек-бары YTM/дюрации) сохранены как суть.

// ── order-status ───────────────────────────────────────────────────────────

/// Путь заявки: выбираешь сценарий — статус идёт от «Активна» к финалу с
/// человеческим объяснением. Те же слова/цвета, что в боевом UI.
class LessonOrderStatusFlow extends StatefulWidget {
  const LessonOrderStatusFlow({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonOrderStatusFlow> createState() => _LessonOrderStatusFlowState();
}

enum _Final { filled, canceled, rejected }

class _Scenario {
  const _Scenario(this.label, this.result, this.why);
  final String label;
  final _Final result;
  final String why;
}

class _LessonOrderStatusFlowState extends State<LessonOrderStatusFlow> {
  static const _scenarios = [
    _Scenario('Рыночная — есть встречная', _Final.filled,
        'В стакане нашлась встречная заявка — сделка прошла сразу.'),
    _Scenario('Лимитная вне рынка', _Final.canceled,
        'Цена не дошла до твоей, а заявка была на день — к закрытию снялась.'),
    _Scenario('Не хватает денег', _Final.rejected,
        'Заявка превысила покупательную способность — биржа её не приняла.'),
    _Scenario('Отменил сам', _Final.canceled,
        'Ты снял заявку до того, как она исполнилась.'),
  ];

  _Scenario? _picked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final picked = _picked;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Путь заявки',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusChip('Активна', AppColors.warning, active: picked == null),
              _arrow(scheme),
              if (picked == null)
                _statusChip('?', scheme.outline, active: false)
              else
                _statusChip(
                  _finalLabel(picked.result),
                  _finalColor(picked.result),
                  active: true,
                ),
            ],
          ),
          const SizedBox(height: BlockSpacing.s),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: picked == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                        vertical: BlockSpacing.xs),
                    padding: const EdgeInsets.all(BlockSpacing.m),
                    decoration: BoxDecoration(
                      color: _finalColor(picked.result).withValues(alpha: 0.1),
                      borderRadius: BlockRadii.innerBr,
                    ),
                    child: Text(picked.why, style: text.bodySmall),
                  ),
          ),
          const SizedBox(height: BlockSpacing.s),
          Wrap(
            spacing: BlockSpacing.s,
            runSpacing: BlockSpacing.s,
            children: [
              for (final s in _scenarios)
                ChoiceChip(
                  label: Text(s.label, style: text.labelSmall),
                  selected: picked == s,
                  selectedColor: widget.tint.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _picked = s),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _finalLabel(_Final f) => switch (f) {
        _Final.filled => 'Исполнена',
        _Final.canceled => 'Отменена',
        _Final.rejected => 'Отклонена',
      };

  Color _finalColor(_Final f) => switch (f) {
        _Final.filled => AppColors.success,
        _Final.canceled => Theme.of(context).colorScheme.onSurfaceVariant,
        _Final.rejected => AppColors.error,
      };

  Widget _statusChip(String label, Color color, {required bool active}) {
    return AnimatedOpacity(
      opacity: active ? 1 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: BlockSpacing.m, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _arrow(ColorScheme scheme) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.arrow_forward, size: 18, color: scheme.onSurfaceVariant),
      );
}

// ── margin-call ──────────────────────────────────────────────────────────────

/// Плечо приближает маржин-колл: слайдер плеча показывает, на сколько процентов
/// должна упасть цена, чтобы залог обнулился; слайдер движения цены доводит до
/// колла.
class LessonMarginCallDial extends StatefulWidget {
  const LessonMarginCallDial({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonMarginCallDial> createState() => _LessonMarginCallDialState();
}

class _LessonMarginCallDialState extends State<LessonMarginCallDial> {
  double _leverage = 2;
  double _move = 0; // движение цены, % (минус = вниз)

  // Колл при потере ~80% своего залога.
  double get _callDrop => 80 / _leverage;
  double get _equityLeft {
    final lossPct = (-_move) * _leverage; // потеря залога в %
    return (100 - lossPct).clamp(0, 100);
  }

  bool get _called => -_move >= _callDrop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Плечо и маржин-колл',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Залог', style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant)),
              Text(
                _called ? 'МАРЖИН-КОЛЛ' : '${_equityLeft.round()}%',
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _called
                      ? AppColors.error
                      : _equityLeft < 40
                          ? AppColors.warning
                          : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: BlockSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 16, color: scheme.surface),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 150),
                  widthFactor: _called ? 1 : _equityLeft / 100,
                  child: Container(
                    height: 16,
                    color: (_called
                            ? AppColors.error
                            : _equityLeft < 40
                                ? AppColors.warning
                                : AppColors.success)
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: BlockSpacing.l),
          BlockSlider(
            tint: widget.tint,
            label: 'Плечо',
            valueLabel: '${_leverage.toStringAsFixed(0)}×',
            value: _leverage,
            min: 1,
            max: 5,
            divisions: 4,
            onChanged: (v) => setState(() => _leverage = v),
          ),
          BlockSlider(
            tint: widget.tint,
            label: 'Цена сходила',
            valueLabel: '${_move.toStringAsFixed(0)}%',
            value: _move,
            min: -40,
            max: 10,
            divisions: 50,
            onChanged: (v) => setState(() => _move = v),
          ),
          const SizedBox(height: BlockSpacing.s),
          Text(
            _called
                ? 'Цена упала на ${(-_move).round()}% — при плече '
                    '${_leverage.toStringAsFixed(0)}× этого хватило, чтобы '
                    'обнулить залог. Позицию закрыли принудительно.'
                : 'При плече ${_leverage.toStringAsFixed(0)}× до маржин-колла — '
                    'падение всего на ${_callDrop.round()}%.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant,
                height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── matching-mini ────────────────────────────────────────────────────────────

/// Сведи две заявки: тянешь цену покупателя и продавца; при пересечении —
/// сделка по цене пассивной стороны, печатается принт.
class LessonMatchBook extends StatefulWidget {
  const LessonMatchBook({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonMatchBook> createState() => _LessonMatchBookState();
}

class _LessonMatchBookState extends State<LessonMatchBook> {
  double _bid = 99;
  double _ask = 103;
  final List<double> _prints = [];

  bool get _crossed => _bid >= _ask;

  void _maybeTrade() {
    if (_crossed) {
      final price = _ask; // цена пассивной стороны (продавец стоял)
      if (_prints.isEmpty || _prints.last != price) {
        _prints.insert(0, price);
        if (_prints.length > 3) _prints.removeLast();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Как рождается сделка',
      subtitle: 'Сведи цену покупателя и продавца. Совпали — сделка.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Кастомная визуализация стакана-ленты (painter) — суть блока.
          SizedBox(
            height: 70,
            child: CustomPaint(
              size: Size.infinite,
              painter: _LadderPainter(
                bid: _bid,
                ask: _ask,
                crossed: _crossed,
                buy: AppColors.success,
                sell: AppColors.error,
                tint: widget.tint,
                track: scheme.surface,
              ),
              child: Center(
                child: AnimatedOpacity(
                  opacity: _crossed ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: BlockSpacing.m, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.tint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Сделка по ${_ask.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.s),
          BlockSlider(
            tint: AppColors.success,
            label: 'Покупатель',
            valueLabel: _bid.toStringAsFixed(0),
            value: _bid,
            min: 95,
            max: 107,
            onChanged: (v) => setState(() {
              _bid = v;
              _maybeTrade();
            }),
          ),
          BlockSlider(
            tint: AppColors.error,
            label: 'Продавец',
            valueLabel: _ask.toStringAsFixed(0),
            value: _ask,
            min: 95,
            max: 107,
            onChanged: (v) => setState(() {
              _ask = v;
              _maybeTrade();
            }),
          ),
          if (_prints.isNotEmpty) ...[
            const SizedBox(height: BlockSpacing.xs),
            Row(
              children: [
                Text('Лента: ', style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
                for (final p in _prints)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(p.toStringAsFixed(0),
                        style: text.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700, color: widget.tint)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LadderPainter extends CustomPainter {
  _LadderPainter({
    required this.bid,
    required this.ask,
    required this.crossed,
    required this.buy,
    required this.sell,
    required this.tint,
    required this.track,
  });

  final double bid;
  final double ask;
  final bool crossed;
  final Color buy;
  final Color sell;
  final Color tint;
  final Color track;

  static const double _min = 95;
  static const double _max = 107;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y),
        Paint()..color = track..strokeWidth = 6..strokeCap = StrokeCap.round);
    double x(double price) =>
        ((price - _min) / (_max - _min)).clamp(0.0, 1.0) * size.width;
    // спред-зона
    if (!crossed) {
      canvas.drawLine(Offset(x(bid), y), Offset(x(ask), y),
          Paint()..color = tint.withValues(alpha: 0.3)..strokeWidth = 6);
    }
    _marker(canvas, x(bid), y, buy);
    _marker(canvas, x(ask), y, sell);
  }

  void _marker(Canvas canvas, double cx, double cy, Color color) {
    canvas.drawCircle(Offset(cx, cy), 9, Paint()..color = color);
    canvas.drawCircle(Offset(cx, cy), 9,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_LadderPainter old) =>
      old.bid != bid || old.ask != ask || old.crossed != crossed;
}

// ── ytm-gauge ────────────────────────────────────────────────────────────────

/// Доходность к погашению: слайдер цены покупки; YTM = купон + амортизация
/// дисконта/премии к средней цене. Стек-бар делит YTM на купон и доход от цены.
class LessonYtmDial extends StatefulWidget {
  const LessonYtmDial({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonYtmDial> createState() => _LessonYtmDialState();
}

class _LessonYtmDialState extends State<LessonYtmDial> {
  static const double _coupon = 8; // купон, % номинала
  static const int _years = 5;

  double _price = 100; // % номинала

  // Приближённая YTM (формула простой доходности к погашению).
  double get _priceGain => (100 - _price) / _years; // % номинала в год
  double get _ytm => (_coupon + _priceGain) / ((_price + 100) / 2) * 100;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final couponPart = _coupon / ((_price + 100) / 2) * 100;
    final gainPart = _ytm - couponPart;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Доходность к погашению',
      subtitle: 'Купон ${_coupon.toStringAsFixed(0)}% от номинала, до погашения '
          '$_years лет. Дешевле берёшь — выше YTM.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              '${_ytm.toStringAsFixed(2)}%',
              style: text.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: _price < 100 ? AppColors.success : AppColors.error,
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.s),
          // Кастомный стек-бар: купон + доход от цены — суть блока.
          SizedBox(
            height: 22,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Expanded(
                    flex: (couponPart.abs() * 100).round().clamp(1, 100000),
                    child: Container(
                      color: widget.tint.withValues(alpha: 0.6),
                      alignment: Alignment.center,
                      child: Text('купон',
                          style: text.labelSmall?.copyWith(color: Colors.white)),
                    ),
                  ),
                  Expanded(
                    flex: (gainPart.abs() * 100).round().clamp(1, 100000),
                    child: Container(
                      color: (gainPart >= 0 ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.6),
                      alignment: Alignment.center,
                      child: Text(gainPart >= 0 ? '+цена' : '−цена',
                          style: text.labelSmall?.copyWith(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          BlockSlider(
            tint: widget.tint,
            label: 'Цена покупки',
            valueLabel: '${_price.toStringAsFixed(0)}%',
            value: _price,
            min: 85,
            max: 115,
            divisions: 30,
            onChanged: (v) => setState(() => _price = v),
          ),
          Text(
            _price < 100
                ? 'Купил с дисконтом — к купону добавляется доход от роста к '
                    'номиналу. YTM выше купона.'
                : _price > 100
                    ? 'Купил с премией — погашение по номиналу съест часть. '
                        'YTM ниже купона.'
                    : 'По номиналу — YTM примерно равна купону.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant,
                height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── rate-move-gauge ──────────────────────────────────────────────────────────

/// Ставка ЦБ и реакция облигаций: слайдер ставки двигает цены короткой и
/// длинной бумаги; длинная реагирует сильнее (дюрация).
class LessonRateReaction extends StatefulWidget {
  const LessonRateReaction({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonRateReaction> createState() => _LessonRateReactionState();
}

class _LessonRateReactionState extends State<LessonRateReaction> {
  static const double _base = 10; // стартовая ставка/купон

  double _rate = 10;

  // Цена ≈ номинал, скорректированный на (ставка−купон)×дюрация.
  double _price(double years) {
    final p = 100 - (_rate - _base) * years;
    return p.clamp(40, 160);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Ставка ЦБ и цена облигаций',
      subtitle: 'Купон 10%. Двигай ставку — длинная бумага реагирует сильнее '
          'короткой.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bondBar(context, 'Короткая (2 года)', _price(1.8)),
          const SizedBox(height: BlockSpacing.m),
          _bondBar(context, 'Длинная (10 лет)', _price(7.5)),
          const SizedBox(height: BlockSpacing.l),
          BlockSlider(
            tint: widget.tint,
            label: 'Ключевая ставка',
            valueLabel: '${_rate.toStringAsFixed(0)}%',
            value: _rate,
            min: 5,
            max: 18,
            divisions: 13,
            onChanged: (v) => setState(() => _rate = v),
          ),
          Text(
            _rate > _base
                ? 'Ставка выше купона — обе дешевле номинала, длинная просела '
                    'заметнее.'
                : _rate < _base
                    ? 'Ставка ниже купона — обе дороже номинала, длинная выросла '
                        'сильнее.'
                    : 'Ставка равна купону — обе у номинала.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant,
                height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _bondBar(BuildContext context, String label, double price) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final below = price < 100;
    final color = below ? AppColors.error : AppColors.success;
    // 100% в центре, диапазон 60..140 -> 0..1
    const center = (100 - 60) / 80;
    final frac = ((price - 60) / 80).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: text.bodySmall),
            Text('${price.round()}%',
                style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: BlockSpacing.xs),
        LayoutBuilder(builder: (context, c) {
          return SizedBox(
            height: 14,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                // отметка номинала
                Positioned(
                  left: c.maxWidth * center - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: scheme.outline),
                ),
                // полоса от центра до текущей цены
                Positioned(
                  left: math.min(c.maxWidth * center, c.maxWidth * frac),
                  width: (c.maxWidth * (frac - center)).abs(),
                  top: 0,
                  bottom: 0,
                  child: Container(color: color.withValues(alpha: 0.5)),
                ),
                Positioned(
                  left: (c.maxWidth * frac - 6).clamp(0, c.maxWidth - 12),
                  top: 1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
