import 'dart:math' as math;

import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Урок: начни раньше — сила времени и сложного процента.
class LessonStartEarly extends StatefulWidget {
  const LessonStartEarly({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonStartEarly> createState() => _LessonStartEarlyState();
}

class _LessonStartEarlyState extends State<LessonStartEarly> {
  static const double _rate = 0.10;
  static const int _retireYear = 60;

  double _amount = 5000;
  double _startYear = 25;

  double _grow(double monthly, int years) {
    // Сложный процент: годовые взносы под _rate.
    final yearly = monthly * 12;
    var total = 0.0;
    for (var i = 0; i < years; i++) {
      total = (total + yearly) * (1 + _rate);
    }
    return total;
  }

  String _money(double v) {
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)} млн ₽';
    }
    return '${(v / 1000).toStringAsFixed(0)} тыс ₽';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final earlyYears = (_retireYear - _startYear).round();
    final lateYears = (_retireYear - (_startYear + 10)).round().clamp(0, 100);

    final earlyTotal = _grow(_amount, earlyYears);
    // Поздний старт: вкладывает вдвое больше, но на 10 лет меньше.
    final lateTotal = _grow(_amount * 2, lateYears);
    final maxTotal = math.max(earlyTotal, lateTotal).clamp(1, double.infinity);

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
          Text('Сила времени', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Маленькая ранняя сумма обгоняет крупную позднюю.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _sliderRow(
            context,
            label: 'Взнос в месяц',
            value: '${(_amount / 1000).toStringAsFixed(0)} тыс ₽',
            slider: Slider(
              value: _amount,
              min: 1000,
              max: 15000,
              divisions: 14,
              onChanged: (v) => setState(() => _amount = v),
            ),
          ),
          _sliderRow(
            context,
            label: 'Старт в возрасте',
            value: '${_startYear.round()} лет',
            slider: Slider(
              value: _startYear,
              min: 20,
              max: 40,
              divisions: 20,
              onChanged: (v) => setState(() => _startYear = v),
            ),
          ),
          const SizedBox(height: 12),
          _bar(
            context,
            title: 'Ранний старт · ${_amount ~/ 1000} тыс/мес · $earlyYears лет',
            value: earlyTotal,
            max: maxTotal.toDouble(),
            color: widget.tint,
          ),
          const SizedBox(height: 10),
          _bar(
            context,
            title:
                'Поздний старт · ${(_amount * 2) ~/ 1000} тыс/мес · $lateYears лет',
            value: lateTotal,
            max: maxTotal.toDouble(),
            color: scheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            earlyTotal >= lateTotal
                ? 'Ранний обгоняет, даже вкладывая вдвое меньше: ${_money(earlyTotal)} против ${_money(lateTotal)}. Время важнее суммы.'
                : 'Поздний догнал за счёт удвоенного взноса, но платит дороже. Раньше — дешевле.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(
    BuildContext context, {
    required String label,
    required String value,
    required Slider slider,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: text.bodySmall),
            Text(
              value,
              style: text.bodySmall?.copyWith(
                color: widget.tint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: widget.tint,
            thumbColor: widget.tint,
            inactiveTrackColor: scheme.outlineVariant,
          ),
          child: slider,
        ),
      ],
    );
  }

  Widget _bar(
    BuildContext context, {
    required String title,
    required double value,
    required double max,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: text.bodySmall)),
            const SizedBox(width: 8),
            Text(
              _money(value),
              style: text.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (value / max).clamp(0, 1).toDouble(),
            minHeight: 12,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// Урок: ликвидность — телефон против гаража при срочной продаже.
class LessonPhoneVsGarage extends StatefulWidget {
  const LessonPhoneVsGarage({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonPhoneVsGarage> createState() => _LessonPhoneVsGarageState();
}

class _LessonPhoneVsGarageState extends State<LessonPhoneVsGarage> {
  static const double _phoneFair = 60000;
  static const double _garageFair = 1200000;

  // 0 = есть месяц, 1 = неделя, 2 = завтра, 3 = через час.
  double _urgency = 0;

  static const List<String> _labels = [
    'есть месяц',
    'за неделю',
    'нужно завтра',
    'через час',
  ];

  /// Телефон ликвиден: цена почти не падает при спешке.
  double _phonePrice() {
    const discounts = [0.0, 0.03, 0.07, 0.12];
    return _phoneFair * (1 - discounts[_urgency.round()]);
  }

  /// Гараж неликвиден: при спешке цена проваливается.
  double _garagePrice() {
    const discounts = [0.0, 0.10, 0.30, 0.55];
    return _garageFair * (1 - discounts[_urgency.round()]);
  }

  String _money(double v) => '${(v / 1000).toStringAsFixed(0)} тыс ₽';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final idx = _urgency.round();

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
          Text('Ликвидность', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Как срочно нужны деньги — и почём удастся продать.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Срочность', style: text.bodySmall),
              Text(
                _labels[idx],
                style: text.bodySmall?.copyWith(
                  color: widget.tint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: widget.tint,
              thumbColor: widget.tint,
              inactiveTrackColor: scheme.outlineVariant,
            ),
            child: Slider(
              value: _urgency,
              max: 3,
              divisions: 3,
              label: _labels[idx],
              onChanged: (v) => setState(() => _urgency = v),
            ),
          ),
          const SizedBox(height: 8),
          _assetRow(
            context,
            name: 'Телефон',
            hint: 'ликвидный — держит цену',
            fair: _phoneFair,
            now: _phonePrice(),
            good: true,
          ),
          const SizedBox(height: 10),
          _assetRow(
            context,
            name: 'Гараж',
            hint: 'неликвидный — проваливается',
            fair: _garageFair,
            now: _garagePrice(),
            good: false,
          ),
          const SizedBox(height: 12),
          Text(
            'Чем быстрее нужны деньги, тем дороже спешка для неликвидного актива. Телефон продашь почти по цене, гараж — со скидкой ${_money(_garageFair - _garagePrice())}.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _assetRow(
    BuildContext context, {
    required String name,
    required String hint,
    required double fair,
    required double now,
    required bool good,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ratio = (now / fair).clamp(0, 1).toDouble();
    final color = good ? AppColors.success : AppColors.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(name, style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(width: 6),
            Text(
              hint,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            Text(
              _money(now),
              style: text.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 12,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// Урок: сборка портфеля под срок, просадку и подушку.
class LessonPortfolioMixer extends StatefulWidget {
  const LessonPortfolioMixer({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonPortfolioMixer> createState() => _LessonPortfolioMixerState();
}

class _LessonPortfolioMixerState extends State<LessonPortfolioMixer> {
  double _horizon = 10; // лет
  double _drawdown = 25; // % переносимой просадки
  double _cushion = 15; // % подушки

  static const List<_Slice> _palette = [
    _Slice('Акции', AppColors.error),
    _Slice('Облигации', AppColors.success),
    _Slice('Металл', AppColors.warning),
    _Slice('Деньги', Color(0xFF6C8EBF)),
  ];

  /// Возвращает доли [акции, облигации, металл, деньги], сумма = 100.
  List<double> _allocation() {
    // Чем дольше горизонт и выше терпимость к просадке — больше акций.
    var stocks = (_horizon * 2 + _drawdown * 0.8).clamp(5, 70).toDouble();
    final cash = _cushion.clamp(5, 50).toDouble();
    final metal = (15 - _drawdown * 0.15).clamp(5, 15).toDouble();
    var bonds = 100 - stocks - cash - metal;
    if (bonds < 5) {
      final deficit = 5 - bonds;
      stocks = (stocks - deficit).clamp(5, 100).toDouble();
      bonds = 5;
    }
    return [stocks, bonds, metal, cash];
  }

  /// Оценка просадки портфеля в плохой год (грубая модель).
  double _badYear(List<double> a) {
    // Акции -45%, облигации -8%, металл -15%, деньги 0.
    final loss = a[0] * 0.45 + a[1] * 0.08 + a[2] * 0.15;
    return loss / 100;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final alloc = _allocation();
    final bad = _badYear(alloc);

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
          Text('Сборка портфеля', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Подвигай параметры — раскладка перестроится.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _slider(context, 'Срок', '${_horizon.round()} лет', _horizon, 1, 30,
              29, (v) => setState(() => _horizon = v)),
          _slider(context, 'Переносимая просадка', '${_drawdown.round()} %',
              _drawdown, 5, 50, 9, (v) => setState(() => _drawdown = v)),
          _slider(context, 'Подушка', '${_cushion.round()} %', _cushion, 5, 50,
              9, (v) => setState(() => _cushion = v)),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(painter: _DonutPainter(alloc, _palette)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _palette.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _palette[i].color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_palette[i].name, style: text.bodySmall),
                            const Spacer(),
                            Text(
                              '${alloc[i].round()} %',
                              style: text.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
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
          const SizedBox(height: 10),
          Text(
            'Как просядет в плохой год: около −${(bad * 100).toStringAsFixed(0)} %. Больше акций — выше рост и глубже провал.',
            style: text.bodySmall?.copyWith(color: AppColors.warning),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    BuildContext context,
    String label,
    String value,
    double v,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: text.bodySmall),
            Text(
              value,
              style: text.bodySmall?.copyWith(
                color: widget.tint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: widget.tint,
            thumbColor: widget.tint,
            inactiveTrackColor: scheme.outlineVariant,
          ),
          child: Slider(
            value: v,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _Slice {
  const _Slice(this.name, this.color);

  final String name;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.slices);

  final List<double> values;
  final List<_Slice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      return;
    }
    var start = -math.pi / 2;
    final stroke = radius * 0.42;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - stroke / 2,
    );
    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = slices[i].color;
      canvas.drawArc(rect, start, sweep - 0.02, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values;
}

/// Урок: дрейф долей и ребалансировка к плану 60/40.
class LessonRebalanceDrift extends StatefulWidget {
  const LessonRebalanceDrift({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonRebalanceDrift> createState() => _LessonRebalanceDriftState();
}

class _LessonRebalanceDriftState extends State<LessonRebalanceDrift> {
  static const double _planStocks = 60;
  static const double _planBonds = 40;

  double _stockGrowth = 25; // % рост рынка акций за год
  bool _rebalanced = false;

  /// Текущие доли после роста акций (или после ребаланса).
  List<double> _current() {
    if (_rebalanced) {
      return [_planStocks, _planBonds];
    }
    // Стартовый капитал 100: 60 акций, 40 облигаций.
    final stocksValue = _planStocks * (1 + _stockGrowth / 100);
    const bondsValue = _planBonds * 1.06; // облигации +6%
    final total = stocksValue + bondsValue;
    return [stocksValue / total * 100, bondsValue / total * 100];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cur = _current();

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
          Text('Ребалансировка', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'План 60/40. Рынок растёт — доли уезжают сами.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Рост акций за год', style: text.bodySmall),
              Text(
                '+${_stockGrowth.round()} %',
                style: text.bodySmall?.copyWith(
                  color: widget.tint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: widget.tint,
              thumbColor: widget.tint,
              inactiveTrackColor: scheme.outlineVariant,
            ),
            child: Slider(
              value: _stockGrowth,
              max: 60,
              divisions: 12,
              onChanged: (v) => setState(() {
                _stockGrowth = v;
                _rebalanced = false;
              }),
            ),
          ),
          const SizedBox(height: 4),
          _stacked(context, 'План', _planStocks, _planBonds, muted: true),
          const SizedBox(height: 8),
          _stacked(
            context,
            _rebalanced ? 'После ребаланса' : 'Сейчас (дрейф)',
            cur[0],
            cur[1],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: _rebalanced
                    ? null
                    : () => setState(() => _rebalanced = true),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.tint.withValues(alpha: 0.18),
                  foregroundColor: widget.tint,
                ),
                child: const Text('Ребалансировать'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _rebalanced
                      ? 'Продали выросшие акции, докупили облигации — снова 60/40.'
                      : 'Акции стали ${cur[0].toStringAsFixed(0)} % — риск выше плана.',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stacked(
    BuildContext context,
    String title,
    double stocks,
    double bonds, {
    bool muted = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final stockColor =
        muted ? scheme.outline : AppColors.error;
    final bondColor =
        muted ? scheme.outlineVariant : AppColors.success;
    final total = stocks + bonds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title · акции ${stocks.toStringAsFixed(0)} / облигации ${bonds.toStringAsFixed(0)}',
          style: text.bodySmall,
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 16,
            child: Row(
              children: [
                Expanded(
                  flex: (stocks / total * 1000).round(),
                  child: ColoredBox(color: stockColor),
                ),
                Expanded(
                  flex: (bonds / total * 1000).round(),
                  child: ColoredBox(color: bondColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Урок: чтение ленты — кто агрессор, покупатель или продавец.
class LessonReadTheTape extends StatefulWidget {
  const LessonReadTheTape({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonReadTheTape> createState() => _LessonReadTheTapeState();
}

class _Trade {
  const _Trade(this.price, this.size, this.buyerAggressor);

  final double price;
  final int size;

  /// true — покупатель бьёт по аску (зелёный), false — продавец по биду.
  final bool buyerAggressor;
}

class _LessonReadTheTapeState extends State<LessonReadTheTape>
    with SingleTickerProviderStateMixin {
  static const List<_Trade> _feed = [
    _Trade(312.40, 120, true),
    _Trade(312.38, 80, false),
    _Trade(312.42, 200, true),
    _Trade(312.42, 50, true),
    _Trade(312.36, 150, false),
    _Trade(312.44, 90, true),
    _Trade(312.40, 60, false),
    _Trade(312.46, 300, true),
    _Trade(312.45, 40, false),
    _Trade(312.48, 110, true),
    _Trade(312.43, 70, false),
    _Trade(312.50, 180, true),
  ];

  late final AnimationController _controller;
  final Set<int> _tapped = {};
  int _hits = 0;
  int _misses = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )
      ..addListener(() => setState(() {}))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (_tapped.contains(index)) {
      return;
    }
    setState(() {
      _tapped.add(index);
      if (_feed[index].buyerAggressor) {
        _hits++;
      } else {
        _misses++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Какие сделки видны в окне: прокручиваем через смещение.
    final offset = (_controller.value * _feed.length).floor();
    final visible = <int>[];
    for (var i = 0; i < 6; i++) {
      visible.add((offset + i) % _feed.length);
    }

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
          Row(
            children: [
              Text('Чтение ленты', style: text.titleMedium),
              const Spacer(),
              Text(
                'Попаданий: $_hits',
                style: text.bodySmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Мимо: $_misses',
                style: text.bodySmall?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Тапай сделки, где агрессор — покупатель (бьёт по аску).',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final i in visible) _tradeRow(context, i),
          const SizedBox(height: 6),
          Text(
            'Зелёный — покупатель снимает ask, цена вверх. Красный — продавец льёт в bid, цена вниз.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _tradeRow(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final trade = _feed[index];
    final isTapped = _tapped.contains(index);
    final color =
        trade.buyerAggressor ? AppColors.success : AppColors.error;

    Color bg;
    if (isTapped) {
      bg = trade.buyerAggressor
          ? AppColors.success.withValues(alpha: 0.22)
          : AppColors.error.withValues(alpha: 0.22);
    } else {
      bg = scheme.surface.withValues(alpha: 0.4);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _onTap(index),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isTapped
                  ? color.withValues(alpha: 0.6)
                  : scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                trade.buyerAggressor
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 10),
              Text(
                trade.price.toStringAsFixed(2),
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                '${trade.size} лот',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              if (isTapped)
                Icon(
                  trade.buyerAggressor ? Icons.check : Icons.close,
                  size: 16,
                  color: color,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
