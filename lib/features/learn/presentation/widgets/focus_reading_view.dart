import 'package:aloria/features/learn/presentation/widgets/lesson_beats.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_markdown_body.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Урок как «фокус-скролл»: воздушная подача без визуальной нагрузки.
///
/// Начало: заголовок, главная мысль и «Листай» — вплотную, компактно. Как
/// только начинаешь листать, «Листай» плавно гаснет, а текст занимает его
/// место; заголовок с описанием не затухают — просто уезжают вверх вместе со
/// всем. Дальше по тексту работает «пояс чтения»: бит в центре экрана яркий, а
/// к краям мягко притухает (но не пропадает — белого листа нет).
class FocusReadingView extends StatefulWidget {
  const FocusReadingView({
    super.key,
    required this.title,
    required this.description,
    required this.body,
    required this.tint,
    required this.tail,
  });

  final String title;
  final String description;

  /// Markdown-тело урока.
  final String body;

  /// Акцент раздела.
  final Color tint;

  /// Хвост урока: тест/повторение/практика/кнопки.
  final List<Widget> tail;

  @override
  State<FocusReadingView> createState() => _FocusReadingViewState();
}

class _FocusReadingViewState extends State<FocusReadingView> {
  final _controller = ScrollController();
  final _tick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() => _tick.value++;

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    _tick.dispose();
    super.dispose();
  }

  static const double _hPad = 20;

  @override
  Widget build(BuildContext context) {
    final beats = splitLessonIntoBeats(widget.body);
    final topInset = MediaQuery.viewPaddingOf(context).top + kToolbarHeight;

    return ListView(
      controller: _controller,
      padding: EdgeInsets.only(top: topInset, bottom: 40),
      children: [
        // Обложка компактная и скроллится как обычно (НЕ затухает) — тело идёт
        // сразу за ней, без разрыва; гаснет только «Листай».
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _hPad),
          child: _hero(context),
        ),
        for (final b in beats)
          _FocusItem(
            tick: _tick,
            controller: _controller,
            child: beatIsBlock(b)
                // Интерактив шире (меньше боковой отступ) и без мёртвого
                // пространства — «весомее», но без больших пустот.
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(8, 30, 8, 30),
                    child: LessonMarkdownBody(
                      body: b,
                      tint: widget.tint,
                      big: true,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _hPad,
                      vertical: 26,
                    ),
                    child: LessonMarkdownBody(
                      body: b,
                      tint: widget.tint,
                      big: true,
                    ),
                  ),
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _hPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.tail,
          ),
        ),
      ],
    );
  }

  /// Обложка: заголовок и главная мысль, под ними вплотную — «Листай». Тело
  /// урока идёт сразу за обложкой, поэтому текст приходит без разрыва и
  /// задержки. Сама обложка не затухает — просто уезжает вверх со всем вместе.
  Widget _hero(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: text.titleMedium?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          if (widget.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              widget.description,
              style: text.bodyMedium?.copyWith(
                fontSize: 18,
                height: 1.5,
                color: scheme.onSurface,
              ),
            ),
          ],
          const SizedBox(height: 30),
          // Гаснет, как только пошёл скролл — текст занимает его место.
          _ScrollFadeOut(
            tick: _tick,
            controller: _controller,
            distance: 80,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 24,
                    color: scheme.onSurfaceVariant,
                  ),
                  Text(
                    'Листай',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Листай»: видно в начале статьи, плавно гаснет за первые [distance] пикселей
/// прокрутки — и больше не возвращается мешать.
class _ScrollFadeOut extends StatefulWidget {
  const _ScrollFadeOut({
    required this.tick,
    required this.controller,
    required this.child,
    required this.distance,
  });

  final ValueListenable<int> tick;
  final ScrollController controller;
  final Widget child;
  final double distance;

  @override
  State<_ScrollFadeOut> createState() => _ScrollFadeOutState();
}

class _ScrollFadeOutState extends State<_ScrollFadeOut> {
  double _opacity = 1;

  @override
  void initState() {
    super.initState();
    widget.tick.addListener(_recompute);
  }

  @override
  void dispose() {
    widget.tick.removeListener(_recompute);
    super.dispose();
  }

  void _recompute() {
    if (!mounted) return;
    final off = widget.controller.hasClients ? widget.controller.offset : 0.0;
    final o = (1 - off / widget.distance).clamp(0.0, 1.0);
    if ((o - _opacity).abs() > 0.012) {
      setState(() => _opacity = o);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _opacity,
      child: IgnorePointer(ignoring: _opacity < 0.05, child: widget.child),
    );
  }
}

/// Обёртка с «поясом чтения»: бит в центре экрана яркий, к верхнему и нижнему
/// краю мягко притухает — но не в ноль (минимум видимости остаётся, без
/// «белого листа» в момент перехода между битами).
///
/// Плюс «проявление по скроллу»: пока статья не тронута (offset 0), всё тело
/// скрыто — на первом экране только обложка. Как только пошёл скролл, тело за
/// [_revealDistance] пикселей плавно проявляется на своих местах (без разрыва).
class _FocusItem extends StatefulWidget {
  const _FocusItem({
    required this.tick,
    required this.controller,
    required this.child,
  });

  final ValueListenable<int> tick;
  final ScrollController controller;
  final Widget child;

  @override
  State<_FocusItem> createState() => _FocusItemState();
}

class _FocusItemState extends State<_FocusItem> {
  static const double _revealDistance = 110;

  // Старт скрыт: на открытии видна только обложка.
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    widget.tick.addListener(_recompute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
  }

  @override
  void dispose() {
    widget.tick.removeListener(_recompute);
    super.dispose();
  }

  void _recompute() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final screenH = MediaQuery.sizeOf(context).height;
    final centerY = box.localToGlobal(Offset(0, box.size.height / 2)).dy;

    final top = screenH * 0.20;
    final bottom = screenH * 0.80;
    double t;
    if (centerY >= top && centerY <= bottom) {
      t = 1;
    } else if (centerY < top) {
      t = (centerY / top).clamp(0.0, 1.0);
    } else {
      t = ((screenH - centerY) / (screenH - bottom)).clamp(0.0, 1.0);
    }

    // Множитель проявления: 0 в самом верху статьи → 1 после первого движения.
    final off = widget.controller.hasClients ? widget.controller.offset : 0.0;
    final reveal = (off / _revealDistance).clamp(0.0, 1.0);

    final o = (0.16 + 0.84 * t) * reveal;
    if ((o - _opacity).abs() > 0.012) {
      setState(() => _opacity = o);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _opacity,
      // Невидимый (ещё не проявленный) бит не ловит тапы — нельзя случайно
      // нажать скрытый интерактив на первом экране.
      child: IgnorePointer(ignoring: _opacity < 0.05, child: widget.child),
    );
  }
}
