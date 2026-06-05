import 'dart:math' as math;

import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Урок: кто держит ликвидность в стакане.
///
/// Mock-стакан с тумблерами «маркетмейкер» и «заявки учеников».
/// Уровни от ММ дают ровные плотные края у спреда, заявки учеников —
/// рваный объём внутри. Видно, что без ММ края оголяются.
class LessonMarketMakerReveal extends StatefulWidget {
  const LessonMarketMakerReveal({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonMarketMakerReveal> createState() =>
      _LessonMarketMakerRevealState();
}

class _LessonMarketMakerRevealState extends State<LessonMarketMakerReveal> {
  bool _maker = true;
  bool _students = true;

  // Цена, объём ММ, объём учеников.
  static const List<_Level> _asks = <_Level>[
    _Level(312.40, 180, 0),
    _Level(312.10, 160, 35),
    _Level(311.80, 140, 0),
    _Level(311.50, 150, 70),
  ];
  static const List<_Level> _bids = <_Level>[
    _Level(311.20, 150, 55),
    _Level(310.90, 140, 0),
    _Level(310.60, 160, 90),
    _Level(310.30, 180, 0),
  ];

  static const double _maxVolume = 270;

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
        children: <Widget>[
          Text('Кто держит стакан', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Включай источники и смотри, чей объём стоит у спреда.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: widget.tint,
            value: _maker,
            onChanged: (bool v) => setState(() => _maker = v),
            title: const Text('Маркетмейкер'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: widget.tint,
            value: _students,
            onChanged: (bool v) => setState(() => _students = v),
            title: const Text('Заявки учеников'),
          ),
          const SizedBox(height: 8),
          ..._asks.map((_Level l) => _row(context, l, isAsk: true)),
          _spreadRow(context),
          ..._bids.map((_Level l) => _row(context, l, isAsk: false)),
          const SizedBox(height: 12),
          _legend(context),
        ],
      ),
    );
  }

  double _volumeOf(_Level l) =>
      (_maker ? l.maker : 0) + (_students ? l.students : 0);

  Widget _row(BuildContext context, _Level l, {required bool isAsk}) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final double vol = _volumeOf(l);
    final Color side = isAsk ? AppColors.error : AppColors.success;
    // Источник определяет «характер» бара: ММ ровный, ученики рваные.
    final bool makerOnly = _maker && (!_students || l.students == 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 58,
            child: Text(
              l.price.toStringAsFixed(2),
              style: text.bodySmall?.copyWith(color: side),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 16,
                child: vol == 0
                    ? Container(color: scheme.surfaceContainerHighest)
                    : CustomPaint(
                        painter: _BarPainter(
                          fraction: (vol / _maxVolume).clamp(0.0, 1.0),
                          color: side,
                          ragged: !makerOnly,
                          base: scheme.surfaceContainerHighest,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              vol == 0 ? '—' : vol.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _spreadRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 58),
          Expanded(
            child: Divider(
              color: widget.tint.withValues(alpha: 0.6),
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'спред',
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: <Widget>[
        _legendItem(context, 'ровный край — ММ', false),
        _legendItem(context, 'рваный объём — ученики', true),
        if (!_maker)
          Text(
            'Без ММ края спреда тоньше — ликвидность держал он.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _legendItem(BuildContext context, String label, bool ragged) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 22,
          height: 12,
          child: CustomPaint(
            painter: _BarPainter(
              fraction: 1,
              color: widget.tint,
              ragged: ragged,
              base: scheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: text.bodySmall),
      ],
    );
  }
}

class _Level {
  const _Level(this.price, this.maker, this.students);

  final double price;
  final double maker;
  final double students;
}

class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.fraction,
    required this.color,
    required this.ragged,
    required this.base,
  });

  final double fraction;
  final Color color;
  final bool ragged;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bg = Paint()..color = base;
    canvas.drawRect(Offset.zero & size, bg);
    final double width = size.width * fraction;
    final Paint fg = Paint()..color = color.withValues(alpha: 0.75);
    if (!ragged) {
      canvas.drawRect(Rect.fromLTWH(0, 0, width, size.height), fg);
      return;
    }
    // Рваный правый край: несколько вертикальных полос разной длины.
    const int slices = 7;
    final double sliceW = width / slices;
    for (int i = 0; i < slices; i++) {
      final double jitter = ((i * 53) % 11) / 11 * sliceW * 1.4;
      final double w = (sliceW - 1).clamp(0.0, double.infinity);
      canvas.drawRect(
        Rect.fromLTWH(i * sliceW, 0, w, size.height),
        fg,
      );
      if (i == slices - 1) {
        canvas.drawRect(
          Rect.fromLTWH(width, 0, jitter, size.height),
          fg..color = color.withValues(alpha: 0.4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.ragged != ragged ||
      old.base != base;
}

/// Урок: как макро-события двигают цену.
///
/// Пользователь сначала предсказывает направление стрелкой, затем тап
/// проигрывает анимацию мини-графика и печатает новость, после чего
/// предсказание сверяется.
class LessonMacroShock extends StatefulWidget {
  const LessonMacroShock({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonMacroShock> createState() => _LessonMacroShockState();
}

class _LessonMacroShockState extends State<LessonMacroShock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<_Macro> _events = <_Macro>[
    _Macro('Ставка ЦБ ↑', -1, 'ЦБ поднял ставку — акции дешевеют.'),
    _Macro('Сильный отчёт', 1, 'Прибыль выше ожиданий — спрос растёт.'),
    _Macro('Санкции', -1, 'Новые ограничения — инвесторы выходят.'),
  ];

  int _selected = 0;
  int? _guess; // 1 вверх, -1 вниз
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(int index) {
    setState(() {
      _selected = index;
      _guess = null;
      _revealed = false;
      _controller.reset();
    });
  }

  void _run() {
    if (_guess == null) return;
    setState(() => _revealed = true);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final _Macro ev = _events[_selected];
    final bool correct = _guess == ev.direction;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Новость двигает цену', style: text.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List<Widget>.generate(_events.length, (int i) {
              final bool sel = i == _selected;
              return ChoiceChip(
                label: Text(_events[i].title),
                selected: sel,
                selectedColor: widget.tint.withValues(alpha: 0.25),
                onSelected: (_) => _pick(i),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            'Куда пойдёт цена?',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _guessButton(context, 1, Icons.arrow_upward, 'Вверх'),
              const SizedBox(width: 12),
              _guessButton(context, -1, Icons.arrow_downward, 'Вниз'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(
              painter: _MacroChartPainter(
                progress: _controller.value,
                direction: ev.direction,
                line: widget.tint,
                up: AppColors.success,
                down: AppColors.error,
                grid: scheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: widget.tint),
              onPressed: _guess == null ? null : _run,
              child: const Text('Проиграть событие'),
            ),
          ),
          if (_revealed) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(ev.news, style: text.bodyMedium),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(
                  correct ? Icons.check_circle : Icons.cancel,
                  size: 18,
                  color: correct ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  correct ? 'Предсказание верное' : 'Цена пошла иначе',
                  style: text.bodySmall?.copyWith(
                    color: correct ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _guessButton(
    BuildContext context,
    int dir,
    IconData icon,
    String label,
  ) {
    final bool sel = _guess == dir;
    final Color c = dir > 0 ? AppColors.success : AppColors.error;
    return Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: sel ? c : null,
          side: BorderSide(
            color: sel ? c : Theme.of(context).colorScheme.outlineVariant,
          ),
          backgroundColor: sel ? c.withValues(alpha: 0.12) : null,
        ),
        onPressed: _revealed
            ? null
            : () => setState(() => _guess = dir),
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _Macro {
  const _Macro(this.title, this.direction, this.news);

  final String title;
  final int direction;
  final String news;
}

class _MacroChartPainter extends CustomPainter {
  const _MacroChartPainter({
    required this.progress,
    required this.direction,
    required this.line,
    required this.up,
    required this.down,
    required this.grid,
  });

  final double progress;
  final int direction;
  final Color line;
  final Color up;
  final Color down;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    final double mid = size.height / 2;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), gridPaint);

    final Path path = Path()..moveTo(0, mid);
    final double end = size.width * progress.clamp(0.0, 1.0);
    const int steps = 40;
    for (int i = 1; i <= steps; i++) {
      final double t = i / steps;
      final double x = size.width * t;
      if (x > end) break;
      final double noise = math.sin(t * 9) * 4 * (1 - t);
      final double drift = direction * t * t * (mid - 10);
      path.lineTo(x, mid - drift + noise);
    }
    final Color c = direction > 0 ? up : down;
    final Paint stroke = Paint()
      ..color = progress == 0 ? line.withValues(alpha: 0.5) : c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_MacroChartPainter old) =>
      old.progress != progress || old.direction != direction;
}

/// Урок: путь заявки по статусам.
///
/// Сценарий определяет финальный статус. Чип проходит
/// working → filled/rejected/canceled теми же словами и цветами,
/// под ним человеческое объяснение причины.
class LessonOrderStatusJourney extends StatefulWidget {
  const LessonOrderStatusJourney({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonOrderStatusJourney> createState() =>
      _LessonOrderStatusJourneyState();
}

class _LessonOrderStatusJourneyState extends State<LessonOrderStatusJourney> {
  static const List<_Scenario> _scenarios = <_Scenario>[
    _Scenario(
      'Есть встречная',
      _Status.filled,
      'В стакане нашлась встречная заявка — сделка прошла, заявка исполнена.',
    ),
    _Scenario(
      'Нет встречной',
      _Status.working,
      'Встречной по твоей цене нет — заявка осталась активной и ждёт в стакане.',
    ),
    _Scenario(
      'Мало ПС',
      _Status.rejected,
      'Покупательной способности не хватило — заявка отклонена до выхода в стакан.',
    ),
    _Scenario(
      'Отменил сам',
      _Status.canceled,
      'Ты снял заявку до исполнения — она отменена.',
    ),
  ];

  int _selected = 0;
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final _Scenario sc = _scenarios[_selected];
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Путь заявки', style: text.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: List<Widget>.generate(_scenarios.length, (int i) {
              return ChoiceChip(
                label: Text(_scenarios[i].label),
                selected: i == _selected,
                selectedColor: widget.tint.withValues(alpha: 0.25),
                onSelected: (_) => setState(() {
                  _selected = i;
                  _started = false;
                }),
              );
            }),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _statusChip(context, _Status.working, active: true),
              _arrow(context),
              _statusChip(
                context,
                sc.finalStatus,
                active: _started && sc.finalStatus != _Status.working,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _started
                  ? sc.explanation
                  : 'Выбери сценарий и отправь заявку.',
              style: text.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: widget.tint),
              onPressed: _started ? null : () => setState(() => _started = true),
              child: const Text('Отправить заявку'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(
          Icons.arrow_forward,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  Widget _statusChip(
    BuildContext context,
    _Status status, {
    required bool active,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final Color c = _colorOf(status);
    final bool on = active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: on ? c.withValues(alpha: 0.18) : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: on ? c : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        _labelOf(status),
        style: text.labelMedium?.copyWith(
          color: on ? c : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _labelOf(_Status s) {
    switch (s) {
      case _Status.working:
        return 'Активна';
      case _Status.filled:
        return 'Исполнена';
      case _Status.rejected:
        return 'Отклонена';
      case _Status.canceled:
        return 'Отменена';
    }
  }

  Color _colorOf(_Status s) {
    switch (s) {
      case _Status.working:
        return AppColors.warning;
      case _Status.filled:
        return AppColors.success;
      case _Status.rejected:
        return AppColors.error;
      case _Status.canceled:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }
}

enum _Status { working, filled, rejected, canceled }

class _Scenario {
  const _Scenario(this.label, this.finalStatus, this.explanation);

  final String label;
  final _Status finalStatus;
  final String explanation;
}

/// Урок: покупательная способность и размер заявки.
///
/// Слайдер числа лотов уменьшает полосу ПС. При превышении кнопка
/// «купить» гаснет и появляется объяснение нехватки.
class LessonBuyingPowerMeter extends StatefulWidget {
  const LessonBuyingPowerMeter({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonBuyingPowerMeter> createState() =>
      _LessonBuyingPowerMeterState();
}

class _LessonBuyingPowerMeterState extends State<LessonBuyingPowerMeter> {
  static const double _buyingPower = 50000; // руб.
  static const double _pricePerLot = 3120; // руб. за лот
  static const int _maxLots = 24;

  double _lots = 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final double cost = _lots * _pricePerLot;
    final bool enough = cost <= _buyingPower;
    final double used = (cost / _buyingPower).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Покупательная способность', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Доступно ${_money(_buyingPower)} · ${_pricePerLot.toStringAsFixed(0)} ₽/лот',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Лотов: ${_lots.toInt()}', style: text.bodyMedium),
              Text(
                'к оплате ${_money(cost)}',
                style: text.bodyMedium?.copyWith(
                  color: enough ? scheme.onSurface : AppColors.error,
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
              value: _lots,
              min: 1,
              max: _maxLots.toDouble(),
              divisions: _maxLots - 1,
              onChanged: (double v) => setState(() => _lots = v),
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: CustomPaint(
                painter: _MeterPainter(
                  used: used,
                  over: !enough,
                  ok: widget.tint,
                  bad: AppColors.error,
                  base: scheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Остаток ${_money((_buyingPower - cost).clamp(-1e9, _buyingPower))}',
            style: text.bodySmall?.copyWith(
              color: enough ? scheme.onSurfaceVariant : AppColors.error,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: widget.tint),
              onPressed: enough ? () {} : null,
              child: const Text('Купить'),
            ),
          ),
          if (!enough) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Не хватает покупательной способности',
              style: text.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  String _money(double v) {
    final int rub = v.round();
    final String s = rub.abs().toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(' ');
      out.write(s[i]);
    }
    return '${rub < 0 ? '-' : ''}$out ₽';
  }
}

class _MeterPainter extends CustomPainter {
  const _MeterPainter({
    required this.used,
    required this.over,
    required this.ok,
    required this.bad,
    required this.base,
  });

  final double used;
  final bool over;
  final Color ok;
  final Color bad;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final Paint fill = Paint()..color = (over ? bad : ok).withValues(alpha: 0.8);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * used, size.height),
      fill,
    );
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.used != used || old.over != over;
}

/// Урок: цена входа-выхода через спред.
///
/// Переключатель ликвидный/неликвидный инструмент, покупка по рынку и
/// мгновенная продажа. Счётчик потери = спред × объём; на неликвиде
/// потеря заметно больше.
class LessonSpreadRoundtrip extends StatefulWidget {
  const LessonSpreadRoundtrip({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonSpreadRoundtrip> createState() => _LessonSpreadRoundtripState();
}

class _LessonSpreadRoundtripState extends State<LessonSpreadRoundtrip> {
  // bid, ask, число акций в лоте-пакете для наглядности.
  static const _Instrument _liquid = _Instrument(
    'Ликвидный',
    311.20,
    311.40,
    100,
  );
  static const _Instrument _illiquid = _Instrument(
    'Неликвидный',
    188.00,
    191.20,
    100,
  );

  bool _isLiquid = true;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final _Instrument inst = _isLiquid ? _liquid : _illiquid;
    final double spread = inst.ask - inst.bid;
    final double loss = spread * inst.size;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Цена входа и выхода', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Купи по рынку и сразу продай — спред заберёт своё.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(value: true, label: Text('Ликвидный')),
              ButtonSegment<bool>(value: false, label: Text('Неликвидный')),
            ],
            selected: <bool>{_isLiquid},
            onSelectionChanged: (Set<bool> v) => setState(() {
              _isLiquid = v.first;
              _done = false;
            }),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _priceTag(context, 'Покупка (ask)', inst.ask, AppColors.error),
              _priceTag(context, 'Продажа (bid)', inst.bid, AppColors.success),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Спред: ${spread.toStringAsFixed(2)} ₽ · объём ${inst.size} шт.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: widget.tint),
              onPressed: _done ? null : () => setState(() => _done = true),
              child: const Text('Купить по рынку и сразу продать'),
            ),
          ),
          if (_done) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.trending_down,
                      size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Потеряно на спреде: ${loss.toStringAsFixed(0)} ₽',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isLiquid
                  ? 'На ликвидном спред узкий — потеря небольшая.'
                  : 'На неликвиде спред широкий — потеря заметно больше.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceTag(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(2)} ₽',
          style: text.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _Instrument {
  const _Instrument(this.name, this.bid, this.ask, this.size);

  final String name;
  final double bid;
  final double ask;
  final int size;
}
