import 'package:aloria/features/learn/presentation/widgets/lesson_cards.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_markdown_body.dart';
import 'package:flutter/material.dart';

/// Свайп-режим урока: тело разбивается на карточки «одна мысль на экран»
/// (как Stories) — сверху сегментный прогресс, листание горизонтальным
/// свайпом или кнопкой «Далее». Первая карточка — обложка урока, последняя —
/// переданный [outro] (тест/повторение/кнопки завершения).
class SwipeLessonView extends StatefulWidget {
  const SwipeLessonView({
    super.key,
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    required this.body,
    required this.tint,
    required this.outro,
  });

  final String title;
  final String description;
  final int? estimatedMinutes;

  /// Markdown-тело урока.
  final String body;

  /// Акцент раздела.
  final Color tint;

  /// Финальная карточка: тест/повторение/практика + кнопки «дальше/завершить».
  final Widget outro;

  @override
  State<SwipeLessonView> createState() => _SwipeLessonViewState();
}

class _SwipeLessonViewState extends State<SwipeLessonView> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = splitLessonIntoCards(widget.body);
    // Обложка + карточки тела + финал.
    final pages = <Widget>[
      _HeroCard(
        title: widget.title,
        description: widget.description,
        estimatedMinutes: widget.estimatedMinutes,
        tint: widget.tint,
      ),
      for (final c in cards) _BodyCard(markdown: c, tint: widget.tint),
      _OutroCard(child: widget.outro),
    ];
    final total = pages.length;
    final isLast = _page >= total - 1;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: _SegmentBar(total: total, current: _page, tint: widget.tint),
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: pages,
            ),
          ),
          // Кнопка «Далее» — на обложке и карточках тела. На финальной
          // карточке у [outro] свои кнопки завершения.
          if (!isLast)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.tint,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Далее',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Сегментный прогресс сверху (как в Stories): по сегменту на карточку.
class _SegmentBar extends StatelessWidget {
  const _SegmentBar({
    required this.total,
    required this.current,
    required this.tint,
  });

  final int total;
  final int current;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= current
                    ? tint
                    : scheme.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Карточка: центрируем короткий контент, длинный — прокручивается.
class _CardScaffold extends StatelessWidget {
  const _CardScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    required this.tint,
  });

  final String title;
  final String description;
  final int? estimatedMinutes;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return _CardScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (estimatedMinutes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$estimatedMinutes мин',
                style: text.labelMedium?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            title,
            style: text.titleMedium?.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: text.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.swipe, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Листай — по одной мысли за раз',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BodyCard extends StatelessWidget {
  const _BodyCard({required this.markdown, required this.tint});

  final String markdown;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return _CardScaffold(
      child: LessonMarkdownBody(body: markdown, tint: tint, card: true),
    );
  }
}

class _OutroCard extends StatelessWidget {
  const _OutroCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: child,
    );
  }
}
