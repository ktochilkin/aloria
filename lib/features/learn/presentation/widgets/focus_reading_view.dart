import 'package:aloria/features/learn/presentation/widgets/lesson_beats.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_markdown_body.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Урок как «фокус-скролл»: воздушная подача без визуальной нагрузки.
///
/// На открытии — заголовок и главная мысль крупно и свободно. По мере
/// прокрутки то, что уходит за края экрана, **затухает**, а в центре —
/// читаемый «светлый» пояс. Интерактивный блок, когда доходишь до него,
/// занимает почти весь экран, а соседи гаснут.
class FocusReadingView extends StatefulWidget {
  const FocusReadingView({
    super.key,
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    required this.body,
    required this.tint,
    required this.tail,
  });

  final String title;
  final String description;
  final int? estimatedMinutes;

  /// Markdown-тело урока.
  final String body;

  /// Акцент раздела.
  final Color tint;

  /// Хвост урока: тест/повторение/практика/кнопки — без затухания.
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

  @override
  Widget build(BuildContext context) {
    final beats = splitLessonIntoBeats(widget.body);
    final screenH = MediaQuery.sizeOf(context).height;

    return ListView(
      controller: _controller,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + kToolbarHeight,
        20,
        40,
      ),
      children: [
        _FocusItem(tick: _tick, child: _hero(context, screenH)),
        for (final b in beats)
          _FocusItem(
            tick: _tick,
            child: beatIsBlock(b)
                ? _blockBeat(b, screenH)
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    child: LessonMarkdownBody(
                      body: b,
                      tint: widget.tint,
                      big: true,
                    ),
                  ),
          ),
        const SizedBox(height: 12),
        ...widget.tail,
      ],
    );
  }

  /// Обложка: заголовок и главная мысль, свободно — занимает ~половину экрана.
  Widget _hero(BuildContext context, double screenH) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: screenH * 0.46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.estimatedMinutes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${widget.estimatedMinutes} мин',
                style: text.labelMedium?.copyWith(
                  color: widget.tint,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 16),
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
              style: text.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
                fontSize: 18,
              ),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Icon(Icons.keyboard_arrow_down,
                  size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'листай — без спешки',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Интерактивный блок «на весь экран»: даём ему высоту почти во весь экран,
  /// чтобы при прокрутке он становился единственным в фокусе.
  Widget _blockBeat(String beat, double screenH) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: screenH * 0.7),
      child: Center(
        child: LessonMarkdownBody(body: beat, tint: widget.tint, big: true),
      ),
    );
  }
}

/// Обёртка с затуханием по положению в экране: ярко в центральном поясе,
/// гаснет к верхнему и нижнему краю.
class _FocusItem extends StatefulWidget {
  const _FocusItem({required this.tick, required this.child});

  final ValueListenable<int> tick;
  final Widget child;

  @override
  State<_FocusItem> createState() => _FocusItemState();
}

class _FocusItemState extends State<_FocusItem> {
  double _opacity = 1;

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

    // Светлый «пояс чтения» в середине экрана; у краёв — затухание.
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
    final o = 0.16 + 0.84 * t;
    if ((o - _opacity).abs() > 0.012) {
      setState(() => _opacity = o);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(opacity: _opacity, child: widget.child);
  }
}
