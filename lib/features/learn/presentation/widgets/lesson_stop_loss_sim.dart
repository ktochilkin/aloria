import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Тренажёр стоп-лосса: купил по 100 ₽, ставишь стоп слайдером и прогоняешь
/// один и тот же стоп через два сценария сразу — «качку» (шумная просадка,
/// потом рост) и «обвал». Виден главный размен: близкий стоп выбивает на
/// шуме и рост проходит мимо, дальний — дороже обходится при обвале,
/// но без стопа обвал стоит ещё дороже.
class LessonStopLossSim extends StatefulWidget {
  const LessonStopLossSim({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonStopLossSim> createState() => _LessonStopLossSimState();
}

class _LessonStopLossSimState extends State<LessonStopLossSim>
    with SingleTickerProviderStateMixin {
  static const double _buy = 100;

  /// «Качка»: шумная просадка до 96.5, затем уверенный рост.
  static const _shake = <double>[100, 99, 97.5, 96.5, 98, 100.5, 102.5, 104.5, 106];

  /// «Обвал»: глубокое падение до 84 с вялым отскоком.
  static const _crash = <double>[100, 99, 97, 95, 92, 88, 84, 85, 86];

  double _stop = 94;
  bool _running = false;
  bool _done = false;

  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _running = false;
            _done = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _run() {
    setState(() {
      _running = true;
      _done = false;
    });
    _anim.forward(from: 0);
  }

  void _reset() {
    _anim.stop();
    setState(() {
      _running = false;
      _done = false;
    });
  }

  /// Цена выхода по сценарию: стоп, если путь его коснулся, иначе финиш.
  ({double exit, bool stopped}) _outcome(List<double> path) {
    for (final p in path) {
      if (p <= _stop) return (exit: _stop, stopped: true);
    }
    return (exit: path.last, stopped: false);
  }

  String _pct(double exit) {
    final pct = (exit - _buy) / _buy * 100;
    final sign = pct > 0 ? '+' : (pct < 0 ? '−' : '');
    return '$sign${pct.abs().toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final progress = _running ? _anim.value : (_done ? 1.0 : 0.0);

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Поставь стоп',
      subtitle: 'Купил по 100 ₽. Один стоп — два варианта будущего.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlockSlider(
            tint: widget.tint,
            label: 'Мой стоп',
            valueLabel: '${_stop.toStringAsFixed(0)} ₽',
            value: _stop,
            min: 86,
            max: 99,
            divisions: 13,
            onChanged: _running
                ? (_) {}
                : (v) => setState(() {
                      _stop = v;
                      _done = false;
                    }),
          ),
          const SizedBox(height: BlockSpacing.m),
          _Scenario(
            title: 'Если рынок просто качнёт',
            path: _shake,
            progress: progress,
            stop: _stop,
            buy: _buy,
            outcome: progress >= 1 ? _outcome(_shake) : null,
            goodWhenStopped: false,
            noStopExit: _shake.last,
            pct: _pct,
            tint: widget.tint,
          ),
          const SizedBox(height: BlockSpacing.m),
          _Scenario(
            title: 'Если случится обвал',
            path: _crash,
            progress: progress,
            stop: _stop,
            buy: _buy,
            outcome: progress >= 1 ? _outcome(_crash) : null,
            goodWhenStopped: true,
            noStopExit: _crash.last,
            pct: _pct,
            tint: widget.tint,
          ),
          const SizedBox(height: BlockSpacing.m),
          if (_done) ...[
            Container(
              padding: const EdgeInsets.all(BlockSpacing.m),
              decoration: BoxDecoration(
                color: BlockTint.soft(widget.tint),
                borderRadius: BlockRadii.innerBr,
              ),
              child: Text(
                'Это и есть размен. Стоп ближе к цене — меньше потеря при '
                'обвале, но чаще выбивает обычным шумом. Стоп дальше — '
                'спокойнее живётся, но и потеря при срабатывании больше. '
                'Идеального уровня нет — есть тот, с которым ты согласен '
                'заранее.',
                style: text.bodySmall?.copyWith(
                  height: 1.45,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: BlockSpacing.s),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Попробовать другой стоп'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  side: BorderSide(color: scheme.outline),
                ),
              ),
            ),
          ] else
            BlockButton(
              tint: widget.tint,
              label: _running ? 'Смотрим…' : 'Прогнать оба сценария',
              icon: Icons.play_arrow,
              onPressed: _running ? null : _run,
            ),
        ],
      ),
    );
  }
}

/// Один сценарий: спарклайн с пунктиром стопа и итоговая строка.
class _Scenario extends StatelessWidget {
  const _Scenario({
    required this.title,
    required this.path,
    required this.progress,
    required this.stop,
    required this.buy,
    required this.outcome,
    required this.goodWhenStopped,
    required this.noStopExit,
    required this.pct,
    required this.tint,
  });

  final String title;
  final List<double> path;
  final double progress;
  final double stop;
  final double buy;
  final ({double exit, bool stopped})? outcome;

  /// true — срабатывание стопа в этом сценарии скорее спасение (обвал),
  /// false — скорее обидное выбивание (качка).
  final bool goodWhenStopped;
  final double noStopExit;
  final String Function(double exit) pct;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final o = outcome;

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
          Text(
            title,
            style: text.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: BlockSpacing.s),
          SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: _StopPathPainter(
                path: path,
                progress: progress,
                stop: stop,
                stopped: o?.stopped ?? false,
                tint: tint,
                muted: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (o != null) ...[
            const SizedBox(height: BlockSpacing.s),
            Row(
              children: [
                BlockChip(
                  text: o.stopped
                      ? 'стоп сработал: ${pct(o.exit)}'
                      : 'доехал до конца: ${pct(o.exit)}',
                  tint: tint,
                  tone: o.stopped
                      ? (goodWhenStopped ? BlockTone.success : BlockTone.error)
                      : (goodWhenStopped ? BlockTone.error : BlockTone.success),
                ),
                const Spacer(),
                Text(
                  'без стопа: ${pct(noStopExit)}',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StopPathPainter extends CustomPainter {
  _StopPathPainter({
    required this.path,
    required this.progress,
    required this.stop,
    required this.stopped,
    required this.tint,
    required this.muted,
  });

  final List<double> path;
  final double progress;
  final double stop;
  final bool stopped;
  final Color tint;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    const lo = 82.0;
    const hi = 108.0;
    double y(double v) => size.height * (1 - (v - lo) / (hi - lo));
    double x(int i) => size.width * i / (path.length - 1);

    // Пунктир стопа.
    final stopY = y(stop);
    final dash = Paint()
      ..color = muted.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    var dx = 0.0;
    while (dx < size.width) {
      canvas.drawLine(Offset(dx, stopY), Offset(dx + 5, stopY), dash);
      dx += 9;
    }

    // Путь цены до точки срабатывания (или весь, если стоп не задет).
    var cutIndex = path.length - 1;
    if (stopped) {
      for (var i = 0; i < path.length; i++) {
        if (path[i] <= stop) {
          cutIndex = i;
          break;
        }
      }
    }
    // После срабатывания основной путь обрывается в точке выхода —
    // дальше идёт только призрачный хвост «что было бы».
    final maxIndex =
        stopped && progress >= 1 ? cutIndex.toDouble() : path.length - 1.0;
    final shownF = ((path.length - 1) * progress).clamp(0, maxIndex);
    final line = Paint()
      ..color = tint
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final p = Path()..moveTo(x(0), y(path[0]));
    final lastFull = shownF.floor();
    for (var i = 1; i <= lastFull && i < path.length; i++) {
      p.lineTo(x(i), y(path[i]));
    }
    final frac = shownF - lastFull;
    if (frac > 0 && lastFull + 1 < path.length) {
      final yv = path[lastFull] + (path[lastFull + 1] - path[lastFull]) * frac;
      p.lineTo(x(lastFull) + (x(lastFull + 1) - x(lastFull)) * frac, y(yv));
    }
    canvas.drawPath(p, line);

    // После срабатывания хвост пути — призрачный («что было бы дальше»).
    if (stopped && progress >= 1 && cutIndex < path.length - 1) {
      final ghost = Paint()
        ..color = muted.withValues(alpha: 0.35)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      final g = Path()..moveTo(x(cutIndex), y(path[cutIndex]));
      for (var i = cutIndex + 1; i < path.length; i++) {
        g.lineTo(x(i), y(path[i]));
      }
      canvas.drawPath(g, ghost);
      // Точка выхода.
      final dot = Paint()..color = tint;
      canvas.drawCircle(Offset(x(cutIndex), y(stop)), 4.5, dot);
    }

    // Подпись стопа.
    final tp = TextPainter(
      text: TextSpan(
        text: 'стоп ${stop.toStringAsFixed(0)}',
        style: TextStyle(
          color: muted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelY = stopY > size.height / 2 ? stopY - tp.height - 2 : stopY + 2;
    tp.paint(canvas, Offset(0, labelY));
  }

  @override
  bool shouldRepaint(_StopPathPainter old) =>
      old.progress != progress || old.stop != stop || old.stopped != stopped;
}
