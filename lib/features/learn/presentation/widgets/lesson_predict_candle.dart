import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Учебный блок-игра: «куда пойдёт следующая свеча?». Пользователь смотрит на
/// несколько свечей и угадывает направление следующей. После ответа свеча
/// раскрывается. Урок: на коротком окне это почти монетка — про случайность
/// краткосрочного результата (наблюдение за рынком, сложный процент).
class LessonPredictCandle extends StatefulWidget {
  const LessonPredictCandle({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonPredictCandle> createState() => _LessonPredictCandleState();
}

class _LessonPredictCandleState extends State<LessonPredictCandle> {
  // (open, close, high, low). Последняя — «загадка», раскрывается после ответа.
  static const _known = <_C>[
    _C(100, 102, 103, 99),
    _C(102, 101, 103, 100),
    _C(101, 103, 104, 100),
    _C(103, 102, 104, 101),
    _C(102, 104, 105, 101),
  ];
  static const _next = _C(104, 100, 105, 99); // вниз — вопреки «тренду вверх»

  bool? _guessUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final answered = _guessUp != null;
    final actualUp = _next.close >= _next.open;
    final correct = answered && _guessUp == actualUp;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _CandlesPainter(
                known: _known,
                next: _next,
                revealNext: answered,
                grid: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!answered)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _guessUp = true),
                    icon: const Icon(Icons.trending_up, size: 18),
                    label: const Text('Вверх'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                    onPressed: () => setState(() => _guessUp = false),
                    icon: const Icon(Icons.trending_down, size: 18),
                    label: const Text('Вниз'),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Text(
                  correct ? 'Угадал — но это везение.' : 'Не угадал — и это норма.',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: correct ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'На одной свече направление — почти монетка. Угадать пару раз '
                  'легко, делать это стабильно — нет. Поэтому короткий результат '
                  'это шум, а не умение.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _guessUp = null),
                  child: const Text('Ещё раз'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _C {
  const _C(this.open, this.close, this.high, this.low);
  final double open;
  final double close;
  final double high;
  final double low;
}

class _CandlesPainter extends CustomPainter {
  _CandlesPainter({
    required this.known,
    required this.next,
    required this.revealNext,
    required this.grid,
  });

  final List<_C> known;
  final _C next;
  final bool revealNext;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...known, next];
    final hi = all.map((c) => c.high).reduce((a, b) => a > b ? a : b) + 1;
    final lo = all.map((c) => c.low).reduce((a, b) => a < b ? a : b) - 1;
    final n = all.length;
    final slot = size.width / n;
    final bw = slot * 0.5;

    double y(double v) => size.height * (1 - (v - lo) / (hi - lo));

    final gridPaint = Paint()..color = grid..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final yy = size.height * i / 3;
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), gridPaint);
    }

    for (var i = 0; i < n; i++) {
      final isNext = i == n - 1;
      final cx = slot * i + slot / 2;
      if (isNext && !revealNext) {
        // Зона вопроса.
        final qPaint = Paint()
          ..color = grid
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, size.height / 2),
                width: bw,
                height: size.height * 0.7),
            const Radius.circular(4),
          ),
          qPaint..color = grid.withValues(alpha: 0.5),
        );
        final tp = TextPainter(
          text: const TextSpan(
            text: '?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, size.height / 2 - tp.height / 2));
        continue;
      }
      final c = all[i];
      final up = c.close >= c.open;
      final color = up ? AppColors.success : AppColors.error;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      // Тень.
      canvas.drawLine(Offset(cx, y(c.high)), Offset(cx, y(c.low)), paint);
      // Тело.
      final top = y(up ? c.close : c.open);
      final bot = y(up ? c.open : c.close);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - bw / 2, top, cx + bw / 2, bot == top ? top + 1 : bot),
          const Radius.circular(2),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_CandlesPainter old) => old.revealNext != revealNext;
}
