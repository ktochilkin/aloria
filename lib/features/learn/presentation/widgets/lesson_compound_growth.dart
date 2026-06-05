import 'package:flutter/material.dart';

/// Учебный блок к уроку про сложный процент: анимированная кривая роста
/// 1000 ₽ под 10% годовых за 30 лет. Первые годы линия почти прямая, потом
/// загибается вверх. По нажатию «запустить» считается итог и выделяется
/// «×17 за 30 лет» против ожидаемых ×4 при простом сложении.
class LessonCompoundGrowth extends StatefulWidget {
  const LessonCompoundGrowth({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonCompoundGrowth> createState() => _LessonCompoundGrowthState();
}

class _LessonCompoundGrowthState extends State<LessonCompoundGrowth>
    with SingleTickerProviderStateMixin {
  static const int _years = 30;
  static const double _start = 1000;
  static const double _rate = 0.10;

  late final AnimationController _controller;

  // Сложный процент год за годом.
  late final List<double> _compound = List.generate(
    _years + 1,
    (y) => _start * _pow(1 + _rate, y),
  );

  // Простое сложение «по 100 в год» — для контраста.
  late final List<double> _simple = List.generate(
    _years + 1,
    (y) => _start + _start * _rate * y,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run() => _controller.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = _controller.value;
    final shownYear = (t * _years).round();
    final shownValue = _compound[shownYear];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Legend(color: widget.tint, label: 'сложный процент'),
              _Legend(
                color: scheme.onSurfaceVariant,
                label: 'простое сложение',
                dashed: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.6,
            child: CustomPaint(
              painter: _GrowthPainter(
                compound: _compound,
                simple: _simple,
                progress: t,
                line: widget.tint,
                ghost: scheme.onSurfaceVariant,
                grid: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'через $shownYear ${_yearWord(shownYear)}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${_money(shownValue)} ₽',
                      style: text.titleMedium?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: widget.tint,
                      ),
                    ),
                  ],
                ),
              ),
              if (t > 0.97)
                _AccentChip(text: '×17, а не ×4', color: widget.tint),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(t > 0.97 ? 'Ещё раз' : 'Запустить 30 лет'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.dashed = false});

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 3,
          decoration: BoxDecoration(
            color: dashed ? color.withValues(alpha: 0.5) : color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: text.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AccentChip extends StatelessWidget {
  const _AccentChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: t.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter({
    required this.compound,
    required this.simple,
    required this.progress,
    required this.line,
    required this.ghost,
    required this.grid,
  });

  final List<double> compound;
  final List<double> simple;
  final double progress;
  final Color line;
  final Color ghost;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = compound.last;
    final n = compound.length - 1;

    Offset point(List<double> data, int i) {
      final x = size.width * (i / n);
      final y = size.height * (1 - data[i] / maxV);
      return Offset(x, y);
    }

    // Сетка.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Призрак простого сложения (пунктир, всегда целиком).
    final ghostPaint = Paint()
      ..color = ghost.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final ghostPath = Path()..moveTo(point(simple, 0).dx, point(simple, 0).dy);
    for (var i = 1; i <= n; i++) {
      ghostPath.lineTo(point(simple, i).dx, point(simple, i).dy);
    }
    _drawDashed(canvas, ghostPath, ghostPaint);

    // Кривая сложного процента, раскрывается слева направо.
    final shown = (n * progress).clamp(0, n).toDouble();
    final full = shown.floor();
    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(point(compound, 0).dx, point(compound, 0).dy);
    for (var i = 1; i <= full; i++) {
      path.lineTo(point(compound, i).dx, point(compound, i).dy);
    }
    if (full < n) {
      final frac = shown - full;
      final a = point(compound, full);
      final b = point(compound, full + 1);
      path.lineTo(a.dx + (b.dx - a.dx) * frac, a.dy + (b.dy - a.dy) * frac);
    }
    canvas.drawPath(path, linePaint);

    // Точка на кончике.
    final tip = full < n
        ? Offset(
            point(compound, full).dx +
                (point(compound, full + 1).dx - point(compound, full).dx) *
                    (shown - full),
            point(compound, full).dy +
                (point(compound, full + 1).dy - point(compound, full).dy) *
                    (shown - full),
          )
        : point(compound, n);
    canvas.drawCircle(tip, 4, Paint()..color = line);
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = dist + 5;
        canvas.drawPath(
          metric.extractPath(dist, next.clamp(0, metric.length)),
          paint,
        );
        dist = next + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_GrowthPainter old) => old.progress != progress;
}

double _pow(double base, int exp) {
  var r = 1.0;
  for (var i = 0; i < exp; i++) {
    r *= base;
  }
  return r;
}

String _money(double v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _yearWord(int y) {
  final m10 = y % 10;
  final m100 = y % 100;
  if (m100 >= 11 && m100 <= 14) return 'лет';
  if (m10 == 1) return 'год';
  if (m10 >= 2 && m10 <= 4) return 'года';
  return 'лет';
}
