import 'dart:math' as math;

import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Гонка процентов: линейный рост (+100/год) против сложного (×1.1/год).
class LessonCompoundRace extends StatefulWidget {
  const LessonCompoundRace({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonCompoundRace> createState() => _LessonCompoundRaceState();
}

class _LessonCompoundRaceState extends State<LessonCompoundRace>
    with SingleTickerProviderStateMixin {
  static const int _maxYears = 30;
  static const double _start = 1000;

  late final AnimationController _controller;
  int _year = 0;
  bool _auto = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..addListener(() {
        setState(() {
          _year = (_controller.value * _maxYears).round();
        });
      });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _auto = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_auto) return;
    setState(() {
      if (_year >= _maxYears) {
        _year = 0;
      } else {
        _year++;
      }
    });
  }

  void _toggleAuto() {
    setState(() {
      _auto = !_auto;
      if (_auto) {
        _controller
          ..value = _year / _maxYears
          ..forward();
      } else {
        _controller.stop();
      }
    });
  }

  double get _linear => _start + 100 * _year;

  double get _compound => _start * math.pow(1.1, _year).toDouble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LessonBlockCard(
      tint: widget.tint,
      title: 'Простой против сложного процента',
      subtitle: 'Год $_year из $_maxYears',
      footer: Row(
        children: [
          Expanded(
            child: BlockButton(
              tint: widget.tint,
              label: 'Следующий год',
              onPressed: _auto ? null : _next,
            ),
          ),
          const SizedBox(width: BlockSpacing.s),
          IconButton.filledTonal(
            onPressed: _toggleAuto,
            icon: Icon(_auto ? Icons.pause : Icons.play_arrow),
            style: IconButton.styleFrom(
              foregroundColor: widget.tint,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _RacePainter(
                progress: _year / _maxYears,
                linearColor: BlockChartColors.neutral(scheme),
                compoundColor: widget.tint,
                gridColor: BlockChartColors.grid(scheme),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          Row(
            children: [
              _Legend(
                color: BlockChartColors.neutral(scheme),
                label: '+100/год',
                value: _linear,
              ),
              const SizedBox(width: BlockSpacing.l),
              _Legend(
                color: widget.tint,
                label: '×1,1/год',
                value: _compound,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  '${value.round()} ₽',
                  style: text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RacePainter extends CustomPainter {
  _RacePainter({
    required this.progress,
    required this.linearColor,
    required this.compoundColor,
    required this.gridColor,
  });

  final double progress;
  final Color linearColor;
  final Color compoundColor;
  final Color gridColor;

  static const double _start = 1000;
  static const int _maxYears = 30;
  static final double _max = _start * math.pow(1.1, _maxYears).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final shownYears = (progress * _maxYears).clamp(0, _maxYears).toDouble();
    double mapY(double v) => size.height - (v / _max) * size.height;
    double mapX(double y) => (y / _maxYears) * size.width;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final linPath = Path()..moveTo(0, mapY(_start));
    for (var y = 0.0; y <= shownYears; y += 1) {
      linPath.lineTo(mapX(y), mapY(_start + 100 * y));
    }
    canvas.drawPath(linPath, linePaint..color = linearColor);

    final compPath = Path()..moveTo(0, mapY(_start));
    for (var y = 0.0; y <= shownYears; y += 0.5) {
      compPath.lineTo(
        mapX(y),
        mapY(_start * math.pow(1.1, y).toDouble()),
      );
    }
    canvas.drawPath(compPath, linePaint..color = compoundColor);

    if (shownYears > 0) {
      final cx = mapX(shownYears);
      canvas.drawCircle(
        Offset(cx, mapY(_start + 100 * shownYears)),
        3.5,
        Paint()..color = linearColor,
      );
      canvas.drawCircle(
        Offset(cx, mapY(_start * math.pow(1.1, shownYears).toDouble())),
        3.5,
        Paint()..color = compoundColor,
      );
    }
  }

  @override
  bool shouldRepaint(_RacePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Нормировка к 100%: дорогая и дешёвая бумага в рублях и в процентах.
class LessonNormalize100 extends StatefulWidget {
  const LessonNormalize100({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonNormalize100> createState() => _LessonNormalize100State();
}

class _LessonNormalize100State extends State<LessonNormalize100> {
  // Дорогая бумага: высокая цена, скромный рост (+25%).
  static const List<double> _expensive = [
    5000,
    5100,
    5300,
    5250,
    5500,
    5800,
    6100,
    6250,
  ];
  // Дешёвая бумага: низкая цена, сильный рост (+70%).
  static const List<double> _cheap = [
    120,
    128,
    140,
    138,
    155,
    172,
    190,
    204,
  ];

  bool _normalized = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LessonBlockCard(
      tint: widget.tint,
      title: 'Кто на самом деле вырос сильнее',
      subtitle: _normalized
          ? 'Старт = 100%. Видно реальный рост.'
          : 'В рублях дорогая бумага просто выше.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 170,
            child: CustomPaint(
              painter: _NormalizePainter(
                expensive: _expensive,
                cheap: _cheap,
                normalized: _normalized,
                expensiveColor: BlockChartColors.neutral(scheme),
                cheapColor: widget.tint,
                gridColor: BlockChartColors.grid(scheme),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          BlockLegend(items: [
            (BlockChartColors.neutral(scheme), 'Дорогая'),
            (widget.tint, 'Дешёвая'),
          ]),
          const SizedBox(height: BlockSpacing.m),
          Row(
            children: [
              Expanded(
                child: Text(
                  _normalized ? 'Нормировка к 100%' : 'Рубли',
                  style: text.bodyMedium,
                ),
              ),
              Switch(
                value: _normalized,
                activeThumbColor: widget.tint,
                onChanged: (v) => setState(() => _normalized = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NormalizePainter extends CustomPainter {
  _NormalizePainter({
    required this.expensive,
    required this.cheap,
    required this.normalized,
    required this.expensiveColor,
    required this.cheapColor,
    required this.gridColor,
  });

  final List<double> expensive;
  final List<double> cheap;
  final bool normalized;
  final Color expensiveColor;
  final Color cheapColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final exp = _series(expensive);
    final ch = _series(cheap);
    final maxV = [...exp, ...ch].reduce(math.max);
    final minV = [...exp, ...ch].reduce(math.min);
    final range = (maxV - minV).abs() < 1e-6 ? 1 : maxV - minV;

    Path build(List<double> s) {
      final p = Path();
      for (var i = 0; i < s.length; i++) {
        final x = size.width * i / (s.length - 1);
        final y = size.height - ((s[i] - minV) / range) * size.height;
        if (i == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      return p;
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(build(exp), stroke..color = expensiveColor);
    canvas.drawPath(build(ch), stroke..color = cheapColor);
  }

  List<double> _series(List<double> raw) {
    if (!normalized) return raw;
    final base = raw.first;
    return raw.map((e) => e / base * 100).toList();
  }

  @override
  bool shouldRepaint(_NormalizePainter oldDelegate) =>
      oldDelegate.normalized != normalized;
}

/// «Подводный» график просадок: глубже с ростом доли акций.
class LessonDrawdownUnderwater extends StatefulWidget {
  const LessonDrawdownUnderwater({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonDrawdownUnderwater> createState() =>
      _LessonDrawdownUnderwaterState();
}

class _LessonDrawdownUnderwaterState extends State<LessonDrawdownUnderwater> {
  // Базовый профиль просадок портфеля из 100% акций (в долях).
  static const List<double> _equityDrawdown = [
    0,
    -0.04,
    -0.02,
    -0.11,
    -0.18,
    -0.09,
    -0.05,
    -0.22,
    -0.14,
    -0.06,
    -0.01,
    -0.08,
    0,
  ];

  double _equityShare = 0.6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxDd =
        _equityDrawdown.reduce(math.min) * _equityShare;
    return LessonBlockCard(
      tint: widget.tint,
      title: 'Как глубоко портфель уходит «под воду»',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlockChip(
            text: 'Максимальная просадка: ${(maxDd * 100).toStringAsFixed(0)}%',
            tint: widget.tint,
            tone: BlockTone.error,
          ),
          const SizedBox(height: BlockSpacing.m),
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _UnderwaterPainter(
                drawdown: _equityDrawdown,
                share: _equityShare,
                zeroLineColor: scheme.outlineVariant,
                fillColor: BlockChartColors.error,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          BlockSlider(
            tint: widget.tint,
            label: 'Доля акций',
            valueLabel: '${(_equityShare * 100).round()}%',
            value: _equityShare,
            min: 0,
            max: 1,
            onChanged: (v) => setState(() => _equityShare = v),
          ),
        ],
      ),
    );
  }
}

class _UnderwaterPainter extends CustomPainter {
  _UnderwaterPainter({
    required this.drawdown,
    required this.share,
    required this.zeroLineColor,
    required this.fillColor,
  });

  final List<double> drawdown;
  final double share;
  final Color zeroLineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    const zeroY = 0.0; // ноль наверху, просадки идут вниз
    const maxDepth = 0.30; // нижняя граница шкалы

    double mapX(int i) => size.width * i / (drawdown.length - 1);
    double mapY(double dd) {
      final v = (dd * share).clamp(-maxDepth, 0.0);
      return zeroY + (-v / maxDepth) * size.height;
    }

    final fill = Path()..moveTo(0, 0);
    for (var i = 0; i < drawdown.length; i++) {
      fill.lineTo(mapX(i), mapY(drawdown[i]));
    }
    fill
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(
      fill,
      Paint()..color = fillColor.withValues(alpha: 0.25),
    );

    final line = Path();
    for (var i = 0; i < drawdown.length; i++) {
      final x = mapX(i);
      final y = mapY(drawdown[i]);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = fillColor,
    );

    canvas.drawLine(
      const Offset(0, 0.5),
      Offset(size.width, 0.5),
      Paint()
        ..color = zeroLineColor
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_UnderwaterPainter oldDelegate) =>
      oldDelegate.share != share;
}

/// Карта риск/доходность: точки инструментов + зона мошенников.
class LessonRiskReturnMap extends StatefulWidget {
  const LessonRiskReturnMap({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonRiskReturnMap> createState() => _LessonRiskReturnMapState();
}

class _RiskPoint {
  const _RiskPoint(this.label, this.risk, this.ret);

  final String label;
  final double risk; // 0..1
  final double ret; // 0..1
}

class _LessonRiskReturnMapState extends State<LessonRiskReturnMap> {
  static const List<_RiskPoint> _points = [
    _RiskPoint('Вклад', 0.05, 0.12),
    _RiskPoint('ОФЗ', 0.22, 0.28),
    _RiskPoint('Голубая фишка', 0.55, 0.55),
    _RiskPoint('Малая акция', 0.85, 0.82),
  ];

  int? _selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LessonBlockCard(
      tint: widget.tint,
      title: 'Риск и доходность ходят вместе',
      subtitle: _selected == null
          ? 'Тапни по точке, чтобы увидеть инструмент.'
          : _points[_selected!].label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.4,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return GestureDetector(
                  onTapDown: (d) => _handleTap(d.localPosition, size),
                  child: CustomPaint(
                    painter: _RiskReturnPainter(
                      points: _points,
                      selected: _selected,
                      tint: widget.tint,
                      axisColor: scheme.outlineVariant,
                      labelColor: scheme.onSurfaceVariant,
                      scamColor: BlockChartColors.error,
                      pointColor: scheme.onSurface,
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: BlockSpacing.s),
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: BlockChartColors.error),
              const SizedBox(width: BlockSpacing.s),
              Expanded(
                child: Text(
                  'Заштрихованный угол — доход без риска. Так не бывает.',
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleTap(Offset pos, Size size) {
    const pad = 24.0;
    final plotW = size.width - pad * 2;
    final plotH = size.height - pad * 2;
    int? hit;
    var best = double.infinity;
    for (var i = 0; i < _points.length; i++) {
      final p = _points[i];
      final cx = pad + p.risk * plotW;
      final cy = size.height - pad - p.ret * plotH;
      final d = (Offset(cx, cy) - pos).distance;
      if (d < 26 && d < best) {
        best = d;
        hit = i;
      }
    }
    setState(() => _selected = hit);
  }
}

class _RiskReturnPainter extends CustomPainter {
  _RiskReturnPainter({
    required this.points,
    required this.selected,
    required this.tint,
    required this.axisColor,
    required this.labelColor,
    required this.scamColor,
    required this.pointColor,
  });

  final List<_RiskPoint> points;
  final int? selected;
  final Color tint;
  final Color axisColor;
  final Color labelColor;
  final Color scamColor;
  final Color pointColor;

  static const double _pad = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final plotW = size.width - _pad * 2;
    final plotH = size.height - _pad * 2;
    final origin = Offset(_pad, size.height - _pad);

    // Зона мошенников: верхне-левый угол (низкий риск, высокая доходность).
    final scamRect = Rect.fromLTWH(
      _pad,
      _pad,
      plotW * 0.45,
      plotH * 0.45,
    );
    final hatch = Paint()
      ..color = scamColor.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(scamRect);
    for (var x = scamRect.left - scamRect.height;
        x < scamRect.right;
        x += 8) {
      canvas.drawLine(
        Offset(x, scamRect.bottom),
        Offset(x + scamRect.height, scamRect.top),
        hatch,
      );
    }
    canvas.restore();
    canvas.drawRect(
      scamRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = scamColor.withValues(alpha: 0.5),
    );

    // Оси.
    final axis = Paint()
      ..color = axisColor
      ..strokeWidth = 1.5;
    canvas.drawLine(origin, Offset(size.width - _pad, origin.dy), axis);
    canvas.drawLine(origin, const Offset(_pad, _pad), axis);

    // Диагональ «справедливой» зависимости.
    canvas.drawLine(
      origin,
      Offset(size.width - _pad, _pad),
      Paint()
        ..color = axisColor.withValues(alpha: 0.6)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Подписи осей.
    _label(canvas, 'риск →', Offset(size.width - _pad - 40, origin.dy + 6),
        labelColor);
    _label(canvas, 'доход ↑', const Offset(_pad - 18, _pad - 4), labelColor);

    // Точки.
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final cx = _pad + p.risk * plotW;
      final cy = size.height - _pad - p.ret * plotH;
      final isSel = i == selected;
      canvas.drawCircle(
        Offset(cx, cy),
        isSel ? 8 : 6,
        Paint()..color = isSel ? tint : pointColor,
      );
      if (isSel) {
        canvas.drawCircle(
          Offset(cx, cy),
          12,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = tint.withValues(alpha: 0.5),
        );
        _label(canvas, p.label, Offset(cx + 10, cy - 18), tint);
      }
    }
  }

  void _label(Canvas canvas, String s, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_RiskReturnPainter oldDelegate) =>
      oldDelegate.selected != selected;
}

/// Тепловая карта корреляций: похожие бумаги = одна ставка.
class LessonCorrelationHeatmap extends StatefulWidget {
  const LessonCorrelationHeatmap({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonCorrelationHeatmap> createState() =>
      _LessonCorrelationHeatmapState();
}

class _Asset {
  const _Asset(this.ticker, this.factor);

  /// Тикер бумаги.
  final String ticker;

  /// Скрытый «фактор» — близкие факторы дают высокую корреляцию.
  final double factor;
}

class _LessonCorrelationHeatmapState
    extends State<LessonCorrelationHeatmap> {
  static const List<_Asset> _all = [
    _Asset('SBER', 0.10),
    _Asset('VTBR', 0.16),
    _Asset('LKOH', 0.70),
    _Asset('ROSN', 0.74),
    _Asset('GAZP', 0.55),
  ];

  final Set<int> _enabled = {0, 1, 2, 3};

  List<_Asset> get _active =>
      [for (var i = 0; i < _all.length; i++) if (_enabled.contains(i)) _all[i]];

  double _corr(_Asset a, _Asset b) {
    if (identical(a, b)) return 1;
    final d = (a.factor - b.factor).abs();
    return (1 - d).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final active = _active;
    return LessonBlockCard(
      tint: widget.tint,
      title: 'Тепловая карта корреляций',
      subtitle: 'Две похожие бумаги = одна ставка.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: BlockSpacing.xl),
              child: Text(
                'Выбери хотя бы две бумаги.',
                style: text.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            )
          else
            AspectRatio(
              aspectRatio: 1.25,
              child: CustomPaint(
                painter: _HeatmapPainter(
                  assets: active,
                  corr: _corr,
                  labelColor: scheme.onSurface,
                  lowColor: BlockChartColors.success,
                  highColor: BlockChartColors.error,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          const SizedBox(height: BlockSpacing.m),
          Wrap(
            spacing: BlockSpacing.s,
            runSpacing: BlockSpacing.xs,
            children: [
              for (var i = 0; i < _all.length; i++)
                FilterChip(
                  label: Text(_all[i].ticker),
                  selected: _enabled.contains(i),
                  selectedColor: widget.tint.withValues(alpha: 0.25),
                  checkmarkColor: widget.tint,
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _enabled.add(i);
                    } else {
                      _enabled.remove(i);
                    }
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.assets,
    required this.corr,
    required this.labelColor,
    required this.lowColor,
    required this.highColor,
  });

  final List<_Asset> assets;
  final double Function(_Asset, _Asset) corr;
  final Color labelColor;
  final Color lowColor;
  final Color highColor;

  @override
  void paint(Canvas canvas, Size size) {
    final n = assets.length;
    const labelGap = 34.0;
    final grid = size.width - labelGap;
    final cell = math.min(grid / n, (size.height - labelGap) / n);
    const left = labelGap;
    const top = labelGap;

    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final v = corr(assets[r], assets[c]);
        final color = Color.lerp(lowColor, highColor, v)!;
        final rect = Rect.fromLTWH(
          left + c * cell + 1,
          top + r * cell + 1,
          cell - 2,
          cell - 2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = color.withValues(alpha: 0.85),
        );
        _text(
          canvas,
          v.toStringAsFixed(1),
          rect.center,
          Colors.white,
          centered: true,
        );
      }
    }

    for (var i = 0; i < n; i++) {
      _text(
        canvas,
        assets[i].ticker,
        Offset(left + i * cell + cell / 2, top - 16),
        labelColor,
        centered: true,
      );
      _text(
        canvas,
        assets[i].ticker,
        Offset(left - 4, top + i * cell + cell / 2 - 6),
        labelColor,
        rightAlign: true,
      );
    }
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    Color color, {
    bool centered = false,
    bool rightAlign = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    var dy = at.dy;
    if (centered) {
      dx -= tp.width / 2;
      dy -= tp.height / 2;
    } else if (rightAlign) {
      dx -= tp.width;
    }
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_HeatmapPainter oldDelegate) =>
      oldDelegate.assets.length != assets.length ||
      !identical(oldDelegate.assets, assets);
}
