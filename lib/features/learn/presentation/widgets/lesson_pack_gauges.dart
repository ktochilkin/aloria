import 'dart:math' as math;

import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Gauge ставки ЦБ: слайдер ставки + предсказание вверх/вниз.
/// Показывает обратную реакцию цены короткой и длинной облигации (дюрация).
/// Собран на block_kit (стиль «воздух»): карточка-обёртка, слайдер — BlockSlider,
/// число-итог — NumberAccent. Сама дуга-датчик рисуется CustomPainter'ом.
class LessonRateMoveGauge extends StatefulWidget {
  const LessonRateMoveGauge({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonRateMoveGauge> createState() => _LessonRateMoveGaugeState();
}

class _LessonRateMoveGaugeState extends State<LessonRateMoveGauge>
    with SingleTickerProviderStateMixin {
  static const double _minRate = 5;
  static const double _maxRate = 21;

  // Дюрации (годы): короткая и длинная облигация.
  static const double _shortDur = 1.2;
  static const double _longDur = 7.5;

  double _rate = 16;
  int _guess = 0; // -1 вниз, 0 нет, 1 вверх
  bool _resolved = false;
  double _delta = 0;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _predict(int dir) {
    setState(() {
      _guess = dir;
      _resolved = false;
    });
  }

  void _apply() {
    if (_guess == 0) {
      return;
    }
    setState(() {
      _delta = _guess * 1.0; // шаг ставки 1 п.п.
      final next = (_rate + _delta).clamp(_minRate, _maxRate);
      _delta = next - _rate;
      _rate = next;
      _resolved = true;
    });
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = _controller.value;

    // Цена облигации обратна ставке: ΔP ≈ -Dur * Δr.
    final shortMove = -_shortDur * _delta * t;
    final longMove = -_longDur * _delta * t;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Ставка ЦБ и цены облигаций',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NumberAccent(
            value: 'Ставка ${_rate.toStringAsFixed(0)}%',
            label: 'ключевая ставка',
            tint: widget.tint,
          ),
          const SizedBox(height: BlockSpacing.s),
          SizedBox(
            height: 96,
            child: CustomPaint(
              size: Size.infinite,
              painter: _RateGaugePainter(
                value: (_rate - _minRate) / (_maxRate - _minRate),
                tint: widget.tint,
                track: scheme.outlineVariant,
              ),
            ),
          ),
          BlockSlider(
            tint: widget.tint,
            label: 'Ставка',
            valueLabel: '${_rate.toStringAsFixed(0)}%',
            value: _rate,
            min: _minRate,
            max: _maxRate,
            divisions: (_maxRate - _minRate).round(),
            onChanged: (v) => setState(() {
              _rate = v;
              _resolved = false;
              _delta = 0;
            }),
          ),
          const SizedBox(height: BlockSpacing.xs),
          Text('Куда пойдёт ставка?', style: text.bodySmall),
          const SizedBox(height: BlockSpacing.s),
          Row(
            children: [
              Expanded(
                child: _DirButton(
                  label: 'Вверх',
                  icon: Icons.arrow_upward,
                  selected: _guess == 1,
                  tint: widget.tint,
                  onTap: () => _predict(1),
                ),
              ),
              const SizedBox(width: BlockSpacing.s),
              Expanded(
                child: _DirButton(
                  label: 'Вниз',
                  icon: Icons.arrow_downward,
                  selected: _guess == -1,
                  tint: widget.tint,
                  onTap: () => _predict(-1),
                ),
              ),
              const SizedBox(width: BlockSpacing.s),
              FilledButton(
                onPressed: _guess == 0 ? null : _apply,
                style: FilledButton.styleFrom(backgroundColor: widget.tint),
                child: const Text('Сдвинуть'),
              ),
            ],
          ),
          const SizedBox(height: BlockSpacing.m),
          _BondReaction(
            title: 'Короткая (дюрация ${_shortDur.toStringAsFixed(1)})',
            move: _resolved ? shortMove : 0,
          ),
          const SizedBox(height: BlockSpacing.s),
          _BondReaction(
            title: 'Длинная (дюрация ${_longDur.toStringAsFixed(1)})',
            move: _resolved ? longMove : 0,
          ),
          const SizedBox(height: BlockSpacing.s),
          Text(
            'Длинная облигация реагирует сильнее: больше дюрация — больше движение цены.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DirButton extends StatelessWidget {
  const _DirButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? tint : scheme.onSurfaceVariant,
        side: BorderSide(
          color: selected ? tint : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
    );
  }
}

class _BondReaction extends StatelessWidget {
  const _BondReaction({required this.title, required this.move});

  final String title;
  final double move; // в процентах

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final up = move >= 0;
    final color = move == 0
        ? scheme.onSurfaceVariant
        : (up ? BlockChartColors.success : BlockChartColors.error);
    final mag = (move.abs() / 60).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: text.bodySmall)),
            Text(
              '${move >= 0 ? '+' : ''}${move.toStringAsFixed(1)}%',
              style: text.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: BlockSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: mag,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _RateGaugePainter extends CustomPainter {
  _RateGaugePainter({
    required this.value,
    required this.tint,
    required this.track,
  });

  final double value;
  final Color tint;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height) - 6;
    const start = math.pi;
    const sweep = math.pi;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, start, sweep, false, trackPaint);

    final valPaint = Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep * value.clamp(0.0, 1.0), false, valPaint);

    final angle = start + sweep * value.clamp(0.0, 1.0);
    final needle = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    final needlePaint = Paint()
      ..color = tint
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needle, needlePaint);
    canvas.drawCircle(center, 5, Paint()..color = tint);
  }

  @override
  bool shouldRepaint(_RateGaugePainter old) =>
      old.value != value || old.tint != tint;
}

/// Реальная доходность: номинальная − инфляция. Gauge уходит в красное,
/// когда инфляция обгоняет доходность. Собран на block_kit: карточка-обёртка,
/// слайдеры — BlockSlider, число-итог — NumberAccent. Полоса-датчик рисуется
/// CustomPainter'ом.
class LessonRealYield extends StatefulWidget {
  const LessonRealYield({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonRealYield> createState() => _LessonRealYieldState();
}

class _LessonRealYieldState extends State<LessonRealYield> {
  double _nominal = 15;
  double _inflation = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final real = _nominal - _inflation;
    final positive = real >= 0;
    final color = positive ? BlockChartColors.success : BlockChartColors.error;

    // Шкала реальной доходности от -10 до +10.
    final norm = ((real + 10) / 20).clamp(0.0, 1.0);

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Реальная доходность',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NumberAccent(
            value: '${real >= 0 ? '+' : ''}${real.toStringAsFixed(1)}%',
            label: 'годовых сверх инфляции',
            tint: color,
          ),
          const SizedBox(height: BlockSpacing.m),
          SizedBox(
            height: 22,
            child: CustomPaint(
              size: Size.infinite,
              painter: _RealYieldBarPainter(
                value: norm,
                positive: positive,
                track: scheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.l),
          BlockSlider(
            tint: widget.tint,
            label: 'Номинальная доходность',
            valueLabel: '${_nominal.toStringAsFixed(0)}%',
            value: _nominal,
            min: 0,
            max: 25,
            divisions: 25,
            onChanged: (v) => setState(() => _nominal = v),
          ),
          BlockSlider(
            tint: AppColors.warning,
            label: 'Инфляция',
            valueLabel: '${_inflation.toStringAsFixed(0)}%',
            value: _inflation,
            min: 0,
            max: 25,
            divisions: 25,
            onChanged: (v) => setState(() => _inflation = v),
          ),
          const SizedBox(height: BlockSpacing.s),
          Text(
            positive
                ? 'Деньги растут быстрее цен — капитал прибавляет.'
                : 'Инфляция обгоняет доход — покупательная способность тает.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _RealYieldBarPainter extends CustomPainter {
  _RealYieldBarPainter({
    required this.value,
    required this.positive,
    required this.track,
  });

  final double value;
  final bool positive;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      radius,
    );
    canvas.drawRRect(bg, Paint()..color = track.withValues(alpha: 0.4));

    final mid = size.width / 2;
    final fill = Paint()
      ..color = positive ? BlockChartColors.success : BlockChartColors.error;
    final x = size.width * value;
    final Rect fillRect;
    if (x >= mid) {
      fillRect = Rect.fromLTRB(mid, 0, x, size.height);
    } else {
      fillRect = Rect.fromLTRB(x, 0, mid, size.height);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(fillRect, radius), fill);

    // Нулевая отметка по центру.
    final zero = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(mid, 0), Offset(mid, size.height), zero);
  }

  @override
  bool shouldRepaint(_RealYieldBarPainter old) =>
      old.value != value || old.positive != positive;
}

/// Две колбы — Рубли и Бумага. Слайдер переливает между ними,
/// сумма сохраняется. Уровень жидкости анимирован. Собран на block_kit:
/// карточка-обёртка, слайдер — BlockSlider. Колбы рисуются CustomPainter'ом.
class LessonRublesPaperFlow extends StatefulWidget {
  const LessonRublesPaperFlow({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonRublesPaperFlow> createState() => _LessonRublesPaperFlowState();
}

class _LessonRublesPaperFlowState extends State<LessonRublesPaperFlow>
    with SingleTickerProviderStateMixin {
  static const double _total = 100000; // рублей всего

  double _paperShare = 0.4; // доля в бумаге
  double _targetShare = 0.4;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 1,
    )..addListener(() {
        setState(() {
          _paperShare = _lerp(_fromShare, _targetShare, _controller.value);
        });
      });
    _fromShare = _paperShare;
  }

  double _fromShare = 0.4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setTarget(double v) {
    _fromShare = _paperShare;
    _targetShare = v;
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paper = _total * _paperShare;
    final cash = _total - paper;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Рубли и бумага',
      subtitle: 'Покупаешь бумагу — рублей становится меньше. Сумма не исчезает.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _Flask(
                    label: 'Рубли',
                    amount: cash,
                    fill: 1 - _paperShare,
                    color: BlockChartColors.success,
                  ),
                ),
                const SizedBox(width: BlockSpacing.xl),
                Icon(Icons.swap_horiz, color: scheme.onSurfaceVariant),
                const SizedBox(width: BlockSpacing.xl),
                Expanded(
                  child: _Flask(
                    label: 'Бумага',
                    amount: paper,
                    fill: _paperShare,
                    color: widget.tint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: BlockSpacing.l),
          BlockSlider(
            tint: widget.tint,
            label: 'Доля в бумаге',
            valueLabel: '${(_targetShare * 100).toStringAsFixed(0)}%',
            value: _targetShare,
            min: 0,
            max: 1,
            divisions: 20,
            onChanged: _setTarget,
          ),
        ],
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _Flask extends StatelessWidget {
  const _Flask({
    required this.label,
    required this.amount,
    required this.fill,
    required this.color,
  });

  final String label;
  final double amount;
  final double fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _FlaskPainter(
              fill: fill.clamp(0.0, 1.0),
              color: color,
              outline: scheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: BlockSpacing.s),
        Text(label, style: text.bodySmall),
        Text(
          '${(amount / 1000).toStringAsFixed(1)} тыс ₽',
          style: text.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FlaskPainter extends CustomPainter {
  _FlaskPainter({
    required this.fill,
    required this.color,
    required this.outline,
  });

  final double fill;
  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      size.width * 0.18,
      4,
      size.width * 0.64,
      size.height - 8,
    );
    final body = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(6),
      topRight: const Radius.circular(6),
      bottomLeft: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );

    canvas.save();
    canvas.clipRRect(body);
    final liquidTop = rect.bottom - rect.height * fill;
    canvas.drawRect(
      Rect.fromLTRB(rect.left, liquidTop, rect.right, rect.bottom),
      Paint()..color = color.withValues(alpha: 0.8),
    );
    // Поверхность жидкости.
    canvas.drawRect(
      Rect.fromLTRB(rect.left, liquidTop, rect.right, liquidTop + 3),
      Paint()..color = color,
    );
    canvas.restore();

    canvas.drawRRect(
      body,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FlaskPainter old) =>
      old.fill != fill || old.color != color;
}

/// Развилка «ничего не делать»: оставить лежать (узкая линия вниз — инфляция)
/// против отдать в работу (веер исходов вверх и вниз). Тап раскрывает ветку.
/// Собран на block_kit: карточка-обёртка, итоги-плашки — BlockChip. Сама
/// развилка-веер рисуется CustomPainter'ом.
class LessonDoNothingFork extends StatefulWidget {
  const LessonDoNothingFork({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonDoNothingFork> createState() => _LessonDoNothingForkState();
}

class _LessonDoNothingForkState extends State<LessonDoNothingFork>
    with SingleTickerProviderStateMixin {
  static const double _amount = 100000;

  // Исходы «в работе» через 3 года, доля от суммы.
  static const List<double> _workOutcomes = [1.45, 1.18, 1.02, 0.88, 0.72];

  // «Лежит» — теряет к инфляции ~9% в год.
  static const double _idleOutcome = 0.75;

  bool _expandIdle = false;
  bool _expandWork = false;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleIdle() {
    setState(() => _expandIdle = !_expandIdle);
    _controller
      ..reset()
      ..forward();
  }

  void _toggleWork() {
    setState(() => _expandWork = !_expandWork);
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Что будет с 100 тыс ₽ за 3 года',
      subtitle: 'Оба варианта несут риск. «Ничего не делать» — тоже выбор.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: Size.infinite,
              painter: _ForkPainter(
                progress: _controller.isAnimating ? _controller.value : 1,
                showIdle: _expandIdle,
                showWork: _expandWork,
                idleOutcome: _idleOutcome,
                workOutcomes: _workOutcomes,
                tint: widget.tint,
                line: scheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.m),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _toggleIdle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                  ),
                  child: Text(_expandIdle ? 'Лежит ✓' : 'Оставить лежать'),
                ),
              ),
              const SizedBox(width: BlockSpacing.s),
              Expanded(
                child: OutlinedButton(
                  onPressed: _toggleWork,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.tint,
                    side: BorderSide(color: widget.tint),
                  ),
                  child: Text(_expandWork ? 'В работе ✓' : 'Отдать в работу'),
                ),
              ),
            ],
          ),
          if (_expandIdle) ...[
            const SizedBox(height: BlockSpacing.m),
            BlockChip(
              text: 'Лежит: ${(_amount * _idleOutcome / 1000).toStringAsFixed(0)} '
                  'тыс ₽ — инфляция тихо съедает четверть.',
              tint: AppColors.warning,
              tone: BlockTone.error,
            ),
          ],
          if (_expandWork) ...[
            const SizedBox(height: BlockSpacing.m),
            BlockChip(
              text: 'В работе: от '
                  '${(_amount * _workOutcomes.last / 1000).toStringAsFixed(0)} до '
                  '${(_amount * _workOutcomes.first / 1000).toStringAsFixed(0)} '
                  'тыс ₽ — шире и вверх, и вниз.',
              tint: widget.tint,
            ),
          ],
        ],
      ),
    );
  }
}

class _ForkPainter extends CustomPainter {
  _ForkPainter({
    required this.progress,
    required this.showIdle,
    required this.showWork,
    required this.idleOutcome,
    required this.workOutcomes,
    required this.tint,
    required this.line,
  });

  final double progress;
  final bool showIdle;
  final bool showWork;
  final double idleOutcome;
  final List<double> workOutcomes;
  final Color tint;
  final Color line;

  double _y(Size size, double mult) {
    // mult=1 -> центр; диапазон 0.7..1.45 раскладываем по высоте.
    final mid = size.height / 2;
    return mid - (mult - 1) * size.height * 0.9;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(8, size.height / 2);
    final forkX = size.width * 0.32;
    final fork = Offset(forkX, size.height / 2);

    final base = Paint()
      ..color = line
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, fork, base);
    canvas.drawCircle(start, 4, Paint()..color = tint);

    final p = progress.clamp(0.0, 1.0);

    // Ветка «лежит» — узкая, медленно вниз.
    if (showIdle) {
      final end = Offset(size.width - 8, _y(size, idleOutcome));
      final cur = Offset.lerp(fork, end, p)!;
      final idlePaint = Paint()
        ..color = AppColors.warning
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(fork.dx, fork.dy)
        ..lineTo(cur.dx, cur.dy);
      canvas.drawPath(path, idlePaint);
      canvas.drawCircle(cur, 4, Paint()..color = AppColors.warning);
    }

    // Ветка «в работе» — широкий веер.
    if (showWork) {
      final fan = Paint()
        ..color = tint.withValues(alpha: 0.85)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (final m in workOutcomes) {
        final end = Offset(size.width - 8, _y(size, m));
        final cur = Offset.lerp(fork, end, p)!;
        canvas.drawLine(fork, cur, fan);
        canvas.drawCircle(cur, 3, Paint()..color = tint);
      }
    }

    canvas.drawCircle(fork, 5, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_ForkPainter old) =>
      old.progress != progress ||
      old.showIdle != showIdle ||
      old.showWork != showWork;
}

/// Утечка капитала на издержках: слайдер числа сделок в месяц,
/// капли утекают в накопитель комиссий и спреда. Собран на block_kit:
/// карточка-обёртка, слайдер — BlockSlider, итог — BlockChip. Бак с каплями
/// рисуется CustomPainter'ом.
class LessonFeeLeak extends StatefulWidget {
  const LessonFeeLeak({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonFeeLeak> createState() => _LessonFeeLeakState();
}

class _LessonFeeLeakState extends State<LessonFeeLeak>
    with SingleTickerProviderStateMixin {
  static const double _capital = 100000;
  static const double _ticketCost = 0.0006; // комиссия+спред за сделку, доля

  double _tradesPerMonth = 10;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )
      ..addListener(() => setState(() {}))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Годовая утечка от оборота.
    final annualLeakShare = _tradesPerMonth * 12 * _ticketCost;
    final annualLeak = _capital * annualLeakShare;
    final remaining = _capital - annualLeak;

    // Интенсивность капель растёт с числом сделок.
    final dropCount = (_tradesPerMonth / 3).clamp(1, 12).round();

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Издержки частой торговли',
      subtitle: 'За год утекает '
          '${(annualLeak / 1000).toStringAsFixed(1)} тыс ₽ '
          '(${(annualLeakShare * 100).toStringAsFixed(1)}% капитала).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: Size.infinite,
              painter: _LeakPainter(
                phase: _controller.value,
                dropCount: dropCount,
                capitalLevel: (remaining / _capital).clamp(0.0, 1.0),
                tint: widget.tint,
                outline: scheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: BlockSpacing.l),
          BlockSlider(
            tint: widget.tint,
            label: 'Сделок в месяц',
            valueLabel: _tradesPerMonth.toStringAsFixed(0),
            value: _tradesPerMonth,
            min: 0,
            max: 60,
            divisions: 60,
            onChanged: (v) => setState(() => _tradesPerMonth = v),
          ),
          const SizedBox(height: BlockSpacing.s),
          BlockChip(
            text: 'Остаётся работать на тебя: '
                '${(remaining / 1000).toStringAsFixed(1)} тыс ₽.',
            tint: AppColors.warning,
            tone: BlockTone.error,
          ),
        ],
      ),
    );
  }
}

class _LeakPainter extends CustomPainter {
  _LeakPainter({
    required this.phase,
    required this.dropCount,
    required this.capitalLevel,
    required this.tint,
    required this.outline,
  });

  final double phase;
  final int dropCount;
  final double capitalLevel;
  final Color tint;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final capRect = Rect.fromLTWH(8, 8, size.width * 0.38, size.height - 16);
    final sinkRect = Rect.fromLTWH(
      size.width * 0.62,
      size.height * 0.45,
      size.width * 0.3,
      size.height * 0.5 - 8,
    );
    const radius = Radius.circular(10);

    // Бак капитала.
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, radius),
      Paint()..color = outline.withValues(alpha: 0.3),
    );
    final capTop = capRect.bottom - capRect.height * capitalLevel;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(capRect, radius));
    canvas.drawRect(
      Rect.fromLTRB(capRect.left, capTop, capRect.right, capRect.bottom),
      Paint()..color = tint.withValues(alpha: 0.8),
    );
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, radius),
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Накопитель издержек.
    canvas.drawRRect(
      RRect.fromRectAndRadius(sinkRect, radius),
      Paint()..color = BlockChartColors.error.withValues(alpha: 0.2),
    );
    final sinkLevel = (1 - capitalLevel).clamp(0.0, 1.0);
    final sinkTop = sinkRect.bottom - sinkRect.height * sinkLevel;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(sinkRect, radius));
    canvas.drawRect(
      Rect.fromLTRB(sinkRect.left, sinkTop, sinkRect.right, sinkRect.bottom),
      Paint()..color = BlockChartColors.error.withValues(alpha: 0.7),
    );
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(sinkRect, radius),
      Paint()
        ..color = BlockChartColors.error
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Капли от бака к накопителю.
    final from = Offset(capRect.right, capRect.center.dy);
    final to = Offset(sinkRect.left, sinkRect.top);
    final dropPaint = Paint()..color = BlockChartColors.error;
    for (var i = 0; i < dropCount; i++) {
      final local = (phase + i / dropCount) % 1.0;
      final pos = Offset.lerp(from, to, local)!;
      final r = 2.5 + 1.5 * math.sin(local * math.pi);
      canvas.drawCircle(pos, r, dropPaint);
    }
  }

  @override
  bool shouldRepaint(_LeakPainter old) =>
      old.phase != phase ||
      old.dropCount != dropCount ||
      old.capitalLevel != capitalLevel;
}
