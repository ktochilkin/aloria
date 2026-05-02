import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:aloria/features/learn/presentation/widgets/learning_widgets.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_quiz_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Экран урока. Структура:
///   1. Шапка-индикатор: «Урок i из N» + переключатели на пред./след. урок.
///   2. Картинка урока (если есть).
///   3. Заголовок + краткое описание.
///   4. Академическое определение в выделенном блоке.
///   5. Markdown-тело урока.
///   6. Опциональный мини-тест (LessonQuizBlock).
///   7. Нижний CTA: «Отметить пройденным» / «Следующий урок» / «Завершить».
class LessonPage extends ConsumerWidget {
  const LessonPage({
    super.key,
    required this.sectionId,
    required this.lessonId,
  });

  final String sectionId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(learningSectionsProvider);

    return sectionsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Загрузка...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(child: Text('Не удалось загрузить урок: $e')),
      ),
      data: (sections) {
        final pair = _findSectionAndLesson(sections, sectionId, lessonId);
        if (pair == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Урок не найден')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось найти урок «$sectionId/$lessonId».',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _LessonView(
          section: pair.section,
          lesson: pair.lesson,
          index: pair.index,
        );
      },
    );
  }

  ({LearningSection section, Lesson lesson, int index})? _findSectionAndLesson(
    List<LearningSection> sections,
    String sectionId,
    String lessonId,
  ) {
    for (final section in sections) {
      if (section.id != sectionId) continue;
      for (var i = 0; i < section.lessons.length; i++) {
        if (section.lessons[i].id == lessonId) {
          return (section: section, lesson: section.lessons[i], index: i);
        }
      }
    }
    return null;
  }
}

class _LessonView extends ConsumerStatefulWidget {
  const _LessonView({
    required this.section,
    required this.lesson,
    required this.index,
  });

  final LearningSection section;
  final Lesson lesson;
  final int index;

  @override
  ConsumerState<_LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends ConsumerState<_LessonView> {
  bool _markedThisOpen = false;

  @override
  void initState() {
    super.initState();
    // Помечаем урок как «открытый» один раз за визит, чтобы карточка
    // «Продолжить» вела на самый последний открытый урок.
    // Репозиторий прогресса инициализируется асинхронно (SharedPreferences),
    // поэтому ждём его готовности и только потом фиксируем переход.
    Future.microtask(() async {
      try {
        await ref.read(learningProgressRepositoryProvider.future);
      } catch (_) {
        // Если хранилище недоступно — продолжаем без записи прогресса,
        // экран всё равно должен открыться.
        return;
      }
      if (!mounted) return;
      await ref.read(learningProgressProvider.notifier).markRead(
            widget.section.id,
            widget.lesson.id,
          );
      if (!mounted) return;
      setState(() => _markedThisOpen = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final progress = ref.watch(learningProgressProvider);
    final entry = progress.entryFor(widget.section.id, widget.lesson.id);
    final isRead = entry?.read ?? _markedThisOpen;
    final total = widget.section.lessons.length;
    final hasNext = widget.index + 1 < total;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/learn/${widget.section.id}');
            }
          },
        ),
        title: Text(
          widget.section.title,
          style: text.titleMedium?.copyWith(fontSize: 16),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, context.bottomNavBarPadding),
        children: [
          _LessonProgressHeader(
            section: widget.section,
            index: widget.index,
            total: total,
            estimatedMinutes: widget.lesson.estimatedMinutes,
            isRead: isRead,
          ),
          const SizedBox(height: 14),
          if (widget.lesson.imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _LessonImage(
                source: widget.lesson.imageUrl,
                fallbackTint: widget.section.tint,
                fallbackIcon: widget.section.icon,
              ),
            ),
          Text(widget.lesson.title, style: text.headlineMedium),
          if (widget.lesson.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.lesson.description,
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (widget.lesson.academicDefinition.isNotEmpty) ...[
            const SizedBox(height: 14),
            _DefinitionBlock(
              title: 'Академическое определение',
              content: widget.lesson.academicDefinition,
              tint: widget.section.tint,
            ),
          ],
          const SizedBox(height: 18),
          MarkdownBody(
            data: widget.lesson.body,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: text.bodyMedium?.copyWith(height: 1.55),
              h1: text.titleMedium?.copyWith(fontSize: 22),
              h2: text.titleMedium?.copyWith(fontSize: 19),
              h3: text.titleMedium?.copyWith(fontSize: 17),
              blockquote: text.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              blockquoteDecoration: BoxDecoration(
                color: widget.section.tint.withValues(alpha: 0.08),
                border: Border(
                  left: BorderSide(color: widget.section.tint, width: 3),
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              listBullet: text.bodyMedium,
            ),
            imageBuilder: (uri, title, alt) => _MarkdownImage(
              uri: uri,
              alt: alt,
              fallbackTint: widget.section.tint,
            ),
          ),
          if (widget.lesson.hasQuiz) ...[
            const SizedBox(height: 22),
            LessonQuizBlock(
              questions: widget.lesson.quiz,
              tint: widget.section.tint,
              onCompleted: (score, total) {
                ref.read(learningProgressProvider.notifier).saveQuizResult(
                      sectionId: widget.section.id,
                      lessonId: widget.lesson.id,
                      score: score,
                      total: total,
                    );
              },
            ),
          ],
          const SizedBox(height: 22),
          _BottomActions(
            section: widget.section,
            lessonIndex: widget.index,
            hasNext: hasNext,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Шапка позиции в разделе.
// ---------------------------------------------------------------------------

class _LessonProgressHeader extends StatelessWidget {
  const _LessonProgressHeader({
    required this.section,
    required this.index,
    required this.total,
    required this.estimatedMinutes,
    required this.isRead,
  });

  final LearningSection section;
  final int index;
  final int total;
  final int? estimatedMinutes;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: section.tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Урок ${index + 1} из $total',
                style: text.labelMedium?.copyWith(
                  color: section.tint,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (estimatedMinutes != null) ...[
              Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '$estimatedMinutes мин',
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
            const Spacer(),
            if (isRead)
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Пройдено',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        ThinProgressBar(
          fraction: (index + 1) / total,
          tint: section.tint,
          height: 4,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Нижний блок действий.
// ---------------------------------------------------------------------------

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.section,
    required this.lessonIndex,
    required this.hasNext,
  });

  final LearningSection section;
  final int lessonIndex;
  final bool hasNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    void goNext() {
      if (!hasNext) return;
      final next = section.lessons[lessonIndex + 1];
      context.pushReplacement('/learn/${section.id}/${next.id}');
    }

    void goToSection() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/learn/${section.id}');
      }
    }

    return Column(
      children: [
        if (hasNext)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: goNext,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Следующий урок'),
              style: ElevatedButton.styleFrom(
                backgroundColor: section.tint,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: goToSection,
              icon: const Icon(Icons.list),
              label: const Text('К списку раздела'),
              style: ElevatedButton.styleFrom(
                backgroundColor: section.tint,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: goToSection,
                icon: const Icon(Icons.list_alt),
                label: const Text('Все уроки'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  side: BorderSide(color: scheme.outline),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Блок академического определения.
// ---------------------------------------------------------------------------

class _DefinitionBlock extends StatelessWidget {
  const _DefinitionBlock({
    required this.title,
    required this.content,
    required this.tint,
  });

  final String title;
  final String content;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, size: 16, color: tint),
              const SizedBox(width: 6),
              Text(
                title,
                style: text.labelMedium?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(content, style: text.bodyMedium),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Изображение урока.
// ---------------------------------------------------------------------------

class _LessonImage extends StatelessWidget {
  const _LessonImage({
    required this.source,
    required this.fallbackTint,
    required this.fallbackIcon,
  });

  final String source;
  final Color fallbackTint;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRemote = source.startsWith('http');

    Widget fallback() => Container(
          height: 200,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fallbackTint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fallbackTint.withValues(alpha: 0.3)),
          ),
          child: Icon(fallbackIcon, color: fallbackTint, size: 36),
        );

    final image = isRemote
        ? Image.network(
            source,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          )
        : Image.asset(
            source,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200,
        color: scheme.surfaceContainerHighest,
        child: image,
      ),
    );
  }
}

class _MarkdownImage extends StatelessWidget {
  const _MarkdownImage({
    required this.uri,
    required this.alt,
    required this.fallbackTint,
  });

  final Uri uri;
  final String? alt;
  final Color fallbackTint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          uri.toString(),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            height: 160,
            alignment: Alignment.center,
            color: scheme.surfaceContainerHighest,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported,
                    color: scheme.onSurfaceVariant),
                const SizedBox(height: 6),
                Text(
                  alt ?? 'Изображение не загружено',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
