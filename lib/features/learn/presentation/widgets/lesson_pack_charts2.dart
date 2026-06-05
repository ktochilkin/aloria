import 'dart:math' as math;

import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Гора глубины стакана: накопленный объём bid и ask склонами от центра.
class LessonDepthMountain extends StatefulWidget {
  const LessonDepthMountain({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonDepthMountain> createState() => _LessonDepthMountainState();
}

class _LessonDepthMountainState extends State<LessonDepthMountain> {
  // Шаги цены от центра наружу и объёмы на каждом уровне (лоты).
  static const List<double> _liquidVolumes = <double>[
    420, 380, 350, 300, 260, 210, 170, 130,
  ];
  static const List<double> _thinVolumes = <double>[
    90, 70, 55, 40, 30, 22, 16, 10,
  ];

  bool _liquid = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final volumes = _liquid ? _liquidVolumes : _thinVolumes;

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
          Text('Глубина стакана', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Накопленный объём от центра: слева покупатели, справа продавцы.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: _DepthPainter(
                volumes: volumes,
                tint: widget.tint,
                gridColor: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _liquid
                      ? 'Ликвидный: крутые склоны, рядом много объёма.'
                      : 'Неликвидный: пологие склоны, объёма мало.',
                  style: text.bodySmall?.copyWith(
                    color: _liquid ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
              Switch(
                value: _liquid,
                activeThumbColor: widget.tint,
                onChanged: (bool v) => setState(() => _liquid = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DepthPainter extends CustomPainter {
  const _DepthPainter({
    required this.volumes,
    required this.tint,
    required this.gridColor,
  });

  final List<double> volumes;
  final Color tint;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final maxCum = _cumulative(volumes).last;

    final centerLine = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), centerLine);

    _drawSide(canvas, size, cx, maxCum, left: true, color: AppColors.success);
    _drawSide(canvas, size, cx, maxCum, left: false, color: AppColors.error);
  }

  void _drawSide(
    Canvas canvas,
    Size size,
    double cx,
    double maxCum, {
    required bool left,
    required Color color,
  }) {
    final cum = _cumulative(volumes);
    final half = size.width / 2;
    final path = Path()..moveTo(cx, size.height);
    for (var i = 0; i < cum.length; i++) {
      final frac = (i + 1) / cum.length;
      final x = left ? cx - half * frac : cx + half * frac;
      final y = size.height - (cum[i] / maxCum) * (size.height - 6);
      path.lineTo(x, y);
    }
    final endX = left ? cx - half : cx + half;
    path
      ..lineTo(endX, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: 0.22),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  List<double> _cumulative(List<double> src) {
    final out = <double>[];
    var acc = 0.0;
    for (final v in src) {
      acc += v;
      out.add(acc);
    }
    return out;
  }

  @override
  bool shouldRepaint(_DepthPainter old) => old.volumes != volumes;
}

/// Зум таймфрейма: один ряд сделок на разных масштабах.
class LessonTimeframeZoom extends StatefulWidget {
  const LessonTimeframeZoom({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonTimeframeZoom> createState() => _LessonTimeframeZoomState();
}

class _LessonTimeframeZoomState extends State<LessonTimeframeZoom> {
  // Базовый «тиковый» ряд цены — мелкие дрожания вокруг тренда.
  static const List<double> _ticks = <double>[
    100, 100.4, 99.8, 100.6, 100.2, 101.1, 100.7, 101.6, 101.0, 102.0,
    101.4, 102.3, 101.7, 102.9, 102.2, 103.1, 102.6, 103.8, 103.1, 104.2,
    103.6, 104.0, 103.2, 104.5, 103.9, 105.0, 104.3, 105.4, 104.7, 106.0,
    105.3, 106.4, 105.8, 107.1, 106.4, 107.6, 106.9, 108.0, 107.3, 108.6,
  ];
  static const List<String> _labels = <String>['минута', 'час', 'день'];

  double _zoom = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final step = <int>[1, 4, 10][_zoom.round()];

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
          Text('Масштаб времени', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Те же сделки, другой масштаб.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _ZoomPainter(
                ticks: _ticks,
                step: step,
                tint: widget.tint,
                gridColor: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: widget.tint,
              thumbColor: widget.tint,
            ),
            child: Slider(
              value: _zoom,
              max: 2,
              divisions: 2,
              onChanged: (double v) => setState(() => _zoom = v),
            ),
          ),
          Center(
            child: Text(
              'Таймфрейм: ${_labels[_zoom.round()]}',
              style: text.bodySmall?.copyWith(color: widget.tint),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomPainter extends CustomPainter {
  const _ZoomPainter({
    required this.ticks,
    required this.step,
    required this.tint,
    required this.gridColor,
  });

  final List<double> ticks;
  final int step;
  final Color tint;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Прореживаем тики по шагу таймфрейма: меньше точек = крупнее движение.
    final sampled = <double>[];
    for (var i = 0; i < ticks.length; i += step) {
      sampled.add(ticks[i]);
    }
    if (sampled.last != ticks.last) {
      sampled.add(ticks.last);
    }
    if (sampled.length < 2) {
      return;
    }

    var lo = sampled.first;
    var hi = sampled.first;
    for (final v in sampled) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    final span = (hi - lo).abs() < 0.01 ? 1.0 : hi - lo;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final path = Path();
    for (var i = 0; i < sampled.length; i++) {
      final x = size.width * i / (sampled.length - 1);
      final y = size.height - ((sampled[i] - lo) / span) * (size.height - 10) - 5;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ZoomPainter old) => old.step != step;
}

/// Близнецы волатильности: одна новость двигает две линии по-разному.
class LessonVolatilityTwin extends StatefulWidget {
  const LessonVolatilityTwin({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonVolatilityTwin> createState() => _LessonVolatilityTwinState();
}

class _LessonVolatilityTwinState extends State<LessonVolatilityTwin>
    with SingleTickerProviderStateMixin {
  // Каждая новость задаёт направление и силу шока (в долях).
  static const List<_NewsItem> _news = <_NewsItem>[
    _NewsItem('Ставка ЦБ без изменений', 0.4),
    _NewsItem('Сильный отчёт по выручке', 1.0),
    _NewsItem('Санкционные риски', -1.0),
    _NewsItem('Дивиденды выше прогноза', 0.7),
  ];

  late final AnimationController _controller;
  int _selected = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(() => setState(() {}));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(int i) {
    setState(() => _selected = i);
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shock = _news[_selected].shock;

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
          Text('Одна новость — разная амплитуда', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Амплитуда реакции и есть волатильность.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (var i = 0; i < _news.length; i++)
                ChoiceChip(
                  label: Text(_news[i].title),
                  selected: _selected == i,
                  selectedColor: widget.tint.withValues(alpha: 0.25),
                  onSelected: (_) => _pick(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _TwinPainter(
                shock: shock,
                progress: _controller.value,
                tint: widget.tint,
                gridColor: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _Legend(color: widget.tint, label: 'Голубая фишка ±0,5%'),
              const SizedBox(width: 16),
              const _Legend(color: AppColors.warning, label: 'Малая компания ±5%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewsItem {
  const _NewsItem(this.title, this.shock);

  final String title;
  final double shock;
}

class _TwinPainter extends CustomPainter {
  const _TwinPainter({
    required this.shock,
    required this.progress,
    required this.tint,
    required this.gridColor,
  });

  final double shock;
  final double progress;
  final Color tint;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final base = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), base);

    // Голубая фишка — мягкая реакция, малая компания — резкая.
    _line(canvas, size, mid, shock * 0.06, tint);
    _line(canvas, size, mid, shock * 0.42, AppColors.warning);
  }

  void _line(Canvas canvas, Size size, double mid, double amp, Color color) {
    final path = Path()..moveTo(0, mid);
    const n = 48;
    for (var i = 1; i <= n; i++) {
      final t = i / n;
      final x = size.width * t;
      // Реакция нарастает к концу окна, ограничена прогрессом анимации.
      final react = math.min(t, progress);
      final y = mid - amp * (size.height / 2) * react;
      path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_TwinPainter old) =>
      old.shock != shock || old.progress != progress;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: text.bodySmall),
      ],
    );
  }
}

/// Лог против линейной: «клюшка» сложного роста выпрямляется в лог-режиме.
class LessonLogVsLinear extends StatefulWidget {
  const LessonLogVsLinear({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonLogVsLinear> createState() => _LessonLogVsLinearState();
}

class _LessonLogVsLinearState extends State<LessonLogVsLinear> {
  // Капитал при стабильной доходности — удвоения через равные периоды.
  static const List<double> _values = <double>[
    100, 141, 200, 283, 400, 566, 800, 1131, 1600, 2263, 3200,
  ];

  bool _log = false;

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
          Text('Линейная и логарифмическая шкала', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            _log
                ? 'Лог-шкала: равные шаги по высоте = удвоения капитала.'
                : 'Линейная шкала: рост выглядит «клюшкой».',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: _LogPainter(
                values: _values,
                log: _log,
                tint: widget.tint,
                gridColor: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _log ? 'Логарифмическая' : 'Линейная',
                  style: text.bodySmall?.copyWith(color: widget.tint),
                ),
              ),
              Switch(
                value: _log,
                activeThumbColor: widget.tint,
                onChanged: (bool v) => setState(() => _log = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogPainter extends CustomPainter {
  const _LogPainter({
    required this.values,
    required this.log,
    required this.tint,
    required this.gridColor,
  });

  final List<double> values;
  final bool log;
  final Color tint;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final mapped = values.map((double v) => log ? math.log(v) : v).toList();
    var lo = mapped.first;
    var hi = mapped.first;
    for (final v in mapped) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    final span = hi - lo;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final path = Path();
    for (var i = 0; i < mapped.length; i++) {
      final x = size.width * i / (mapped.length - 1);
      final y = size.height - ((mapped[i] - lo) / span) * (size.height - 10) - 5;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_LogPainter old) => old.log != log;
}

/// Золото против акций: сценарии перерисовывают две линии.
class LessonGoldVsStocks extends StatefulWidget {
  const LessonGoldVsStocks({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonGoldVsStocks> createState() => _LessonGoldVsStocksState();
}

class _LessonGoldVsStocksState extends State<LessonGoldVsStocks>
    with SingleTickerProviderStateMixin {
  // Для каждого сценария — путь акций и золота (нормировано к 100).
  static const List<_Scenario> _scenarios = <_Scenario>[
    _Scenario(
      'паника',
      <double>[100, 96, 88, 92, 85, 90, 94],
      <double>[100, 103, 108, 106, 111, 109, 112],
      'Акции падают — золото обычно растёт, гасит просадку.',
    ),
    _Scenario(
      'спокойный год',
      <double>[100, 102, 105, 107, 110, 112, 115],
      <double>[100, 100, 101, 100, 102, 101, 103],
      'Рынок растёт — золото стоит на месте, его роль скромна.',
    ),
    _Scenario(
      'системный кризис',
      <double>[100, 90, 78, 70, 74, 68, 72],
      <double>[100, 97, 92, 88, 90, 86, 89],
      'В системном кризисе падает всё — диверсификация слабее.',
    ),
  ];

  late final AnimationController _controller;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() => setState(() {}));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(int i) {
    setState(() => _selected = i);
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = _scenarios[_selected];

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
          Text('Акции и золото в разных сценариях', style: text.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (var i = 0; i < _scenarios.length; i++)
                ChoiceChip(
                  label: Text(_scenarios[i].name),
                  selected: _selected == i,
                  selectedColor: widget.tint.withValues(alpha: 0.25),
                  onSelected: (_) => _pick(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _GoldPainter(
                stocks: s.stocks,
                gold: s.gold,
                progress: _controller.value,
                stockColor: widget.tint,
                gridColor: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _Legend(color: widget.tint, label: 'Акции'),
              const SizedBox(width: 16),
              const _Legend(color: AppColors.warning, label: 'Золото'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.note,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Scenario {
  const _Scenario(this.name, this.stocks, this.gold, this.note);

  final String name;
  final List<double> stocks;
  final List<double> gold;
  final String note;
}

class _GoldPainter extends CustomPainter {
  const _GoldPainter({
    required this.stocks,
    required this.gold,
    required this.progress,
    required this.stockColor,
    required this.gridColor,
  });

  final List<double> stocks;
  final List<double> gold;
  final double progress;
  final Color stockColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    var lo = double.infinity;
    var hi = double.negativeInfinity;
    for (final v in <double>[...stocks, ...gold]) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    final span = hi - lo < 0.01 ? 1.0 : hi - lo;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    _series(canvas, size, stocks, lo, span, stockColor);
    _series(canvas, size, gold, lo, span, AppColors.warning);
  }

  void _series(
    Canvas canvas,
    Size size,
    List<double> data,
    double lo,
    double span,
    Color color,
  ) {
    final visible = (data.length * progress).clamp(1, data.length).toDouble();
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      if (i + 1 > visible) {
        break;
      }
      final x = size.width * i / (data.length - 1);
      final y = size.height - ((data[i] - lo) / span) * (size.height - 10) - 5;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_GoldPainter old) =>
      old.stocks != stocks || old.progress != progress;
}
