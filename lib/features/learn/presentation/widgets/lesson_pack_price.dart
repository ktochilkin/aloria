import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Разрыв ожиданий: цена двигается по разнице «факт − ожидание», а не по
/// абсолютному значению отчёта.
class LessonExpectationsGap extends StatefulWidget {
  /// Создаёт интерактивный блок про разрыв ожиданий.
  const LessonExpectationsGap({super.key, required this.tint});

  /// Акцентный цвет активных элементов.
  final Color tint;

  @override
  State<LessonExpectationsGap> createState() => _LessonExpectationsGapState();
}

class _LessonExpectationsGapState extends State<LessonExpectationsGap> {
  double _actual = 70;
  double _expected = 55;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final gap = _actual - _expected;
    final up = gap >= 0;
    final color = gap.abs() < 2
        ? scheme.onSurfaceVariant
        : (up ? AppColors.success : AppColors.error);
    final move = gap.abs() < 2
        ? 'цена почти не двигается'
        : (up ? 'цена идёт вверх' : 'цена идёт вниз');

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
          Text('Цена реагирует на разницу с ожиданием',
              style: text.titleSmall),
          const SizedBox(height: 4),
          Text('Хороший отчёт может уронить цену, если рынок ждал большего.',
              style: text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          _slider('Фактический отчёт', _actual, AppColors.success,
              (v) => setState(() => _actual = v)),
          _slider('Что ждал рынок', _expected, scheme.onSurfaceVariant,
              (v) => setState(() => _expected = v)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                up ? Icons.north_east : Icons.south_east,
                color: color,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Сюрприз ${gap >= 0 ? '+' : ''}${gap.toStringAsFixed(0)} → $move',
                  style: text.bodyMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slider(
      String label, double value, Color active, ValueChanged<double> onCh) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: text.bodySmall),
            Text(value.toStringAsFixed(0),
                style: text.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600, color: active)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(activeTrackColor: widget.tint),
          child: Slider(
            value: value,
            max: 100,
            activeColor: widget.tint,
            onChanged: onCh,
          ),
        ),
      ],
    );
  }
}

/// «Бесплатный обед»: попытка получить безрисковую доходность мгновенно
/// съедается набегающими покупателями.
class LessonFreeLunch extends StatefulWidget {
  /// Создаёт интерактивный блок про исчезающий бесплатный доход.
  const LessonFreeLunch({super.key, required this.tint});

  /// Акцентный цвет активных элементов.
  final Color tint;

  @override
  State<LessonFreeLunch> createState() => _LessonFreeLunchState();
}

class _LessonFreeLunchState extends State<LessonFreeLunch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..addListener(() => setState(() {}));
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
    final t = _ctrl.value;
    final yieldNow = 30 * (1 - t);
    final price = 100 + 30 * t;

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
          Text('Бесплатных обедов не бывает', style: text.titleSmall),
          const SizedBox(height: 4),
          Text('Видна «лёгкая» доходность — толпа выкупает её до нуля.',
              style: text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: CustomPaint(
              size: Size.infinite,
              painter: _CrowdPainter(progress: t, tint: widget.tint),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat('Цена', price.toStringAsFixed(1), scheme.onSurface),
              _stat(
                'Доходность',
                '${yieldNow.toStringAsFixed(1)}%',
                yieldNow < 1 ? AppColors.error : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(backgroundColor: widget.tint),
              onPressed: () => _ctrl.forward(from: 0),
              child: const Text('Безрисковые 30%'),
            ),
          ),
          if (t > 0.97)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Рынок съел бесплатный доход.',
                  style: text.bodyMedium?.copyWith(
                      color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall),
        Text(value,
            style: text.titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _CrowdPainter extends CustomPainter {
  const _CrowdPainter({required this.progress, required this.tint});

  final double progress;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 9;
    final dot = Paint()..color = tint;
    final base = size.height - 10;
    for (var i = 0; i < count; i++) {
      final phase = i / count;
      final appear = (progress - phase).clamp(0.0, 1.0);
      if (appear <= 0) {
        continue;
      }
      final x = size.width * (0.05 + 0.9 * (i / (count - 1)));
      final r = 4.0 + 2 * appear;
      dot.color = tint.withValues(alpha: 0.35 + 0.55 * appear);
      canvas.drawCircle(Offset(x, base - 6 * appear), r, dot);
    }
    final line = Paint()
      ..color = AppColors.success
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(0, base);
    path.lineTo(size.width, base - (size.height - 18) * progress);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_CrowdPainter old) =>
      old.progress != progress || old.tint != tint;
}

/// Несимметрия риска: покупка ограничена вложенным, короткая позиция —
/// нет потолка убытка при росте цены.
class LessonShortLoss extends StatefulWidget {
  /// Создаёт интерактивный блок про несимметрию риска покупки и шорта.
  const LessonShortLoss({super.key, required this.tint});

  /// Акцентный цвет активных элементов.
  final Color tint;

  @override
  State<LessonShortLoss> createState() => _LessonShortLossState();
}

class _LessonShortLossState extends State<LessonShortLoss> {
  static const double _entry = 100;
  double _price = 100;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final longPnl = _price - _entry;
    final shortPnl = _entry - _price;

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
          Text('Риск покупки и шорта не равны', style: text.titleSmall),
          const SizedBox(height: 4),
          Text('Вход 100. У покупки убыток упирается в пол, у шорта — нет.',
              style: text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: _ShortPainter(price: _price, entry: _entry),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Цена', style: text.bodySmall),
              Text(_price.toStringAsFixed(0),
                  style: text.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600, color: widget.tint)),
            ],
          ),
          Slider(
            value: _price,
            max: 220,
            activeColor: widget.tint,
            onChanged: (v) => setState(() => _price = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _pnl('Купил', longPnl, AppColors.success),
              _pnl('Шортил', shortPnl, AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pnl(String label, double value, Color base) {
    final text = Theme.of(context).textTheme;
    final color = value >= 0 ? AppColors.success : AppColors.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: base, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: text.bodySmall),
          ],
        ),
        Text('${value >= 0 ? '+' : ''}${value.toStringAsFixed(0)}',
            style: text.titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ShortPainter extends CustomPainter {
  const _ShortPainter({required this.price, required this.entry});

  final double price;
  final double entry;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final axis = Paint()
      ..color = Colors.grey.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), axis);

    double px(double p) => (p / 220) * size.width;
    double py(double pnl) => (mid - (pnl / 120) * (size.height / 2))
        .clamp(2.0, size.height - 2);

    final longPaint = Paint()
      ..color = AppColors.success
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final shortPaint = Paint()
      ..color = AppColors.error
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final longPath = Path()..moveTo(px(0), py(-entry));
    longPath.lineTo(px(220), py(220 - entry));
    canvas.drawPath(longPath, longPaint);

    final shortPath = Path()..moveTo(px(0), py(entry));
    shortPath.lineTo(px(220), py(entry - 220));
    canvas.drawPath(shortPath, shortPaint);

    final marker = Paint()..color = Colors.white;
    final ring = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final lx = px(price);
    for (final pnl in [price - entry, entry - price]) {
      final c = Offset(lx, py(pnl));
      canvas.drawCircle(c, 4, marker);
      canvas.drawCircle(c, 4, ring);
    }
  }

  @override
  bool shouldRepaint(_ShortPainter old) =>
      old.price != price || old.entry != entry;
}

/// Маржин-колл: чем выше плечо, тем быстрее тает залог и тем раньше
/// принудительно закрывается позиция.
class LessonMarginCall extends StatefulWidget {
  /// Создаёт интерактивный блок про плечо и маржин-колл.
  const LessonMarginCall({super.key, required this.tint});

  /// Акцентный цвет активных элементов.
  final Color tint;

  @override
  State<LessonMarginCall> createState() => _LessonMarginCallState();
}

class _LessonMarginCallState extends State<LessonMarginCall> {
  double _leverage = 2;
  double _move = 0; // % движения актива, от -40 до +40

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lev = _leverage.round();

    // Залог = свои деньги. Изменение позиции = move * lev на свой капитал.
    final equityRatio = (1 + (_move / 100) * lev).clamp(0.0, 2.0);
    final called = equityRatio <= 0.25;
    // % падения, при котором сработает колл (equity = 25%).
    final callDrop = 75 / lev;

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
          Text('Плечо ускоряет потерю залога', style: text.titleSmall),
          const SizedBox(height: 4),
          Text('При залоге ниже 25% брокер закрывает позицию.',
              style: text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Text('Плечо: ${lev}x', style: text.bodySmall),
          Slider(
            value: _leverage,
            min: 1,
            max: 3,
            divisions: 2,
            label: '${lev}x',
            activeColor: widget.tint,
            onChanged: (v) => setState(() => _leverage = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Движение актива', style: text.bodySmall),
              Text('${_move >= 0 ? '+' : ''}${_move.toStringAsFixed(0)}%',
                  style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600, color: widget.tint)),
            ],
          ),
          Slider(
            value: _move,
            min: -40,
            max: 40,
            activeColor: widget.tint,
            onChanged: (v) => setState(() => _move = v),
          ),
          const SizedBox(height: 4),
          Text('Залог', style: text.bodySmall),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (equityRatio / 2).clamp(0.0, 1.0),
              minHeight: 14,
              backgroundColor: scheme.surfaceContainerHighest,
              color: called
                  ? AppColors.error
                  : (equityRatio < 0.6 ? AppColors.warning : AppColors.success),
            ),
          ),
          const SizedBox(height: 10),
          if (called)
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Маржин-колл — позиция закрыта.',
                      style: text.bodyMedium?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            )
          else
            Text('Колл сработает при падении актива на ${callDrop.toStringAsFixed(0)}%.',
                style: text.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Дивидендный гэп: в день отсечки цена падает на размер дивиденда, а сумма
/// переходит в кошелёк — итог сохраняется.
class LessonDivgapSwipe extends StatefulWidget {
  /// Создаёт интерактивный блок про дивидендный гэп.
  const LessonDivgapSwipe({super.key, required this.tint});

  /// Акцентный цвет активных элементов.
  final Color tint;

  @override
  State<LessonDivgapSwipe> createState() => _LessonDivgapSwipeState();
}

class _LessonDivgapSwipeState extends State<LessonDivgapSwipe> {
  static const double _base = 280;
  static const double _div = 24;
  double _t = 0; // 0 = вчера, 1 = сегодня (после отсечки)

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final price = _base - _div * _t;
    final wallet = _div * _t;
    final total = price + wallet;

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
          Text('Дивидендный гэп ничего не дарит', style: text.titleSmall),
          const SizedBox(height: 4),
          Text('Дивиденд ${_div.toStringAsFixed(0)} ₽ уходит из цены в кошелёк.',
              style: text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Row(
            children: [
              _box('Цена акции', '${price.toStringAsFixed(0)} ₽',
                  scheme.onSurface, scheme),
              Expanded(
                child: Icon(Icons.east,
                    color: widget.tint.withValues(alpha: 0.3 + 0.7 * _t)),
              ),
              _box('Кошелёк', '${wallet.toStringAsFixed(0)} ₽',
                  AppColors.success, scheme),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Вчера', style: text.bodySmall),
              Text('Сегодня (отсечка)', style: text.bodySmall),
            ],
          ),
          Slider(
            value: _t,
            activeColor: widget.tint,
            onChanged: (v) => setState(() => _t = v),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text('Итого: ${total.toStringAsFixed(0)} ₽ — сумма сохранилась',
                  style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: widget.tint)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(String label, String value, Color color, ColorScheme scheme) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(label, style: text.bodySmall),
          const SizedBox(height: 4),
          Text(value,
              style: text.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
