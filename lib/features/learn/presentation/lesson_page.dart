import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/learn/data/learning_content_cache.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:aloria/features/learn/presentation/widgets/learning_widgets.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_blocks.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_quiz_block.dart';
import 'package:aloria/features/learn/presentation/widgets/recall_card.dart';
import 'package:aloria/features/learn/presentation/widgets/server_quiz_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Слитая версия урока: метаданные из списка + body, academicDefinition,
  /// recall* подгружаются отдельным запросом в [_loadedLesson]. Бэк не
  /// присылает body в /stages/{slug}, поэтому тело подгружается лениво.
  Lesson get _effectiveLesson {
    final loaded = _loadedLesson;
    if (loaded == null) return widget.lesson;
    return Lesson(
      id: widget.lesson.id,
      title: loaded.title.isNotEmpty ? loaded.title : widget.lesson.title,
      description: loaded.description.isNotEmpty
          ? loaded.description
          : widget.lesson.description,
      academicDefinition: loaded.academicDefinition,
      imageUrl: loaded.imageUrl.isNotEmpty ? loaded.imageUrl : widget.lesson.imageUrl,
      body: loaded.body,
      estimatedMinutes: loaded.estimatedMinutes ?? widget.lesson.estimatedMinutes,
      practiceSymbol: loaded.practiceSymbol,
      practiceText: loaded.practiceText,
      recallPrompt: loaded.recallPrompt,
      recallAnswer: loaded.recallAnswer,
      group: loaded.group ?? widget.lesson.group,
      quiz: widget.lesson.quiz,
      serverId: widget.lesson.serverId,
      serverQuizId: loaded.serverQuizId ?? widget.lesson.serverQuizId,
      serverCompleted: widget.lesson.serverCompleted,
      introduces: widget.lesson.introduces,
      deepens: widget.lesson.deepens,
      applies: widget.lesson.applies,
      isCapstone: widget.lesson.isCapstone,
      roleHint: widget.lesson.roleHint,
      practiceRequirementCode: widget.lesson.practiceRequirementCode,
    );
  }

  Lesson? _loadedLesson;

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
            _effectiveLesson.id,
          );
      if (!mounted) return;
      setState(() => _markedThisOpen = true);

      // Параллельно отмечаем прохождение на сервере (без блокировки UI).
      final serverId = _effectiveLesson.serverId;
      if (serverId != null) {
        try {
          final client = ref.read(learningApiClientProvider);
          final portfolioId = ref.read(aloriaPortfolioIdProvider);
          await client.markLessonComplete(
            lessonId: serverId,
            portfolioId: portfolioId,
          );
        } catch (_) {
          // Прогресс на сервере — best-effort; локальная отметка уже стоит.
        }
      }
    });

    // Подгружаем тело урока: бэк отдаёт body/academicDefinition/recall*
    // только в /api/v1/learning/lessons/{id}, а в списке /stages/{slug}
    // приходят только метаданные. Сначала показываем кэшированное (если
    // есть) — даёт мгновенный рендер без сети. Потом обновляем со свежими
    // данными в фоне.
    final fetchId = widget.lesson.serverId;
    if (fetchId != null) {
      Future.microtask(() async {
        // 1) Кэш — сразу, без сети.
        try {
          final prefs = await SharedPreferences.getInstance();
          final cache = LearningContentCache(prefs);
          final cached = cache.loadLessonBody(fetchId);
          if (cached != null && cached.body.isNotEmpty && mounted) {
            setState(() => _loadedLesson = cached);
          }
        } catch (_) {
          // Кэш — вспомогательный, его сбой не критичен.
        }

        // 2) Сеть — обновляем кэш и UI, если тело пришло.
        try {
          final service = ref.read(learningContentServiceProvider);
          final full = await service.loadLesson(fetchId);
          if (!mounted || full == null) return;
          setState(() => _loadedLesson = full);
          try {
            final prefs = await SharedPreferences.getInstance();
            await LearningContentCache(prefs).saveLessonBody(fetchId, full);
          } catch (_) {
            // best-effort
          }
        } catch (_) {
          // Если тело не пришло — UI остаётся с кэшем или метаданными.
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final progress = ref.watch(learningProgressProvider);
    final entry = progress.entryFor(widget.section.id, _effectiveLesson.id);
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
            estimatedMinutes: _effectiveLesson.estimatedMinutes,
            isRead: isRead,
          ),
          const SizedBox(height: 14),
          if (_effectiveLesson.imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _LessonImage(
                source: _effectiveLesson.imageUrl,
                fallbackTint: widget.section.tint,
                fallbackIcon: widget.section.icon,
              ),
            ),
          if (_effectiveLesson.isCapstone)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.section.tint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14, color: widget.section.tint),
                    const SizedBox(width: 4),
                    Text(
                      'Главное задание этапа',
                      style: text.labelMedium?.copyWith(
                        color: widget.section.tint,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Text(
            _effectiveLesson.title,
            style: text.titleMedium?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          if (_effectiveLesson.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _effectiveLesson.description,
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_effectiveLesson.returningConcepts.isNotEmpty) ...[
            const SizedBox(height: 14),
            _LessonConceptBadges(lesson: _effectiveLesson, tint: widget.section.tint),
          ],
          if (_effectiveLesson.academicDefinition.isNotEmpty) ...[
            const SizedBox(height: 14),
            _DefinitionBlock(
              title: 'Академическое определение',
              content: _effectiveLesson.academicDefinition,
              tint: widget.section.tint,
            ),
          ],
          const SizedBox(height: 18),
          Consumer(builder: (context, ref, _) {
            final catalog =
                ref.watch(conceptsCatalogProvider).valueOrNull ?? const {};
            // Препроцессинг: [[slug]] или [[slug|видимый текст]] →
            // обычный markdown-линк с уникальной схемой aloria-concept://.
            // Если slug нет в каталоге — оставляем сырой текст без линка.
            final processed = _injectConceptLinks(
              _effectiveLesson.body,
              catalog,
            );
            // Текстовые сегменты рендерим одинаково; директивы `:::block`
            // превращаются в интерактивные виджеты из реестра.
            Widget markdown(String data) => MarkdownBody(
                  data: data,
                  selectable: true,
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
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
                    // Ненавязчивая ссылка: обычный цвет текста, заметное, но
                    // мягкое подчёркивание приглушённым цветом — намёк
                    // «можно нажать» без яркого акцента.
                    a: TextStyle(
                      color: scheme.onSurface,
                      decoration: TextDecoration.underline,
                      decorationColor: scheme.onSurfaceVariant,
                      decorationThickness: 2,
                    ),
                  ),
                  onTapLink: (label, href, _) {
                    if (href == null) return;
                    const linkScheme = 'aloria-concept://';
                    if (href.startsWith(linkScheme)) {
                      final slug = href.substring(linkScheme.length);
                      _showConceptSheet(context, slug, label);
                    }
                  },
                  sizedImageBuilder: (config) => _MarkdownImage(
                    uri: config.uri,
                    alt: config.alt,
                    fallbackTint: widget.section.tint,
                  ),
                );

            final segments = parseLessonSegments(processed);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final segment in segments)
                  if (segment is LessonText)
                    markdown(segment.markdown)
                  else if (segment is LessonBlock)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: lessonBlockBuilders[segment.name]!(
                        context,
                        widget.section.tint,
                      ),
                    ),
              ],
            );
          }),
          if (_effectiveLesson.hasServerQuiz) ...[
            const SizedBox(height: 22),
            ServerQuizBlock(
              quizId: _effectiveLesson.serverQuizId!,
              tint: widget.section.tint,
              onPassed: (result) {
                ref.read(learningProgressProvider.notifier).saveQuizResult(
                      sectionId: widget.section.id,
                      lessonId: _effectiveLesson.id,
                      score: result.correctCount,
                      total: result.totalQuestions,
                    );
              },
            ),
          ] else if (_effectiveLesson.quiz.isNotEmpty) ...[
            const SizedBox(height: 22),
            LessonQuizBlock(
              questions: _effectiveLesson.quiz,
              tint: widget.section.tint,
              onCompleted: (score, total) {
                ref.read(learningProgressProvider.notifier).saveQuizResult(
                      sectionId: widget.section.id,
                      lessonId: _effectiveLesson.id,
                      score: score,
                      total: total,
                    );
              },
            ),
          ],
          if ((_effectiveLesson.recallPrompt ?? '').trim().isNotEmpty &&
              _effectiveLesson.serverId != null) ...[
            const SizedBox(height: 22),
            RecallCard(
              prompt: _effectiveLesson.recallPrompt!.trim(),
              answer: _effectiveLesson.recallAnswer,
              tint: widget.section.tint,
              onGrade: (remembered) {
                final client = ref.read(learningApiClientProvider);
                final portfolioId = ref.read(aloriaPortfolioIdProvider);
                return client.gradeReview(
                  lessonId: _effectiveLesson.serverId!,
                  remembered: remembered,
                  portfolioId: portfolioId,
                );
              },
            ),
          ],
          if ((_effectiveLesson.practiceText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 22),
            _PracticeCard(
              tint: widget.section.tint,
              text: _effectiveLesson.practiceText!.trim(),
              symbol: _effectiveLesson.practiceSymbol,
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
// Карточка «Попробуй вживую» — deep-link в рынок.
// ---------------------------------------------------------------------------

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.tint,
    required this.text,
    this.symbol,
  });

  final Color tint;
  final String text;
  final String? symbol;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline, color: tint, size: 20),
              const SizedBox(width: 8),
              Text(
                'Попробуй вживую',
                style: t.labelLarge?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: t.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final s = symbol?.trim() ?? '';
                context.push(s.isNotEmpty ? '/market/$s' : '/market');
              },
              style: FilledButton.styleFrom(
                backgroundColor: tint,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.show_chart, size: 18),
              label: const Text('Открыть рынок'),
            ),
          ),
        ],
      ),
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
            errorBuilder: (_, _, _) => fallback(),
          )
        : Image.asset(
            source,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
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
          errorBuilder: (_, _, _) => Container(
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

/// Регулярка для inline-линков на концепцию в markdown: `[[slug]]` или
/// `[[slug|видимый текст]]`. Slug = латиница/цифры/дефисы.
final _conceptLinkRegExp = RegExp(r'\[\[([a-z0-9_-]+)(?:\|([^\]]+))?\]\]');

/// Подставляет в markdown-тело урока ссылки на концепции. `[[slug]]`
/// заменяется на стандартный markdown-линк `[Название](aloria-concept://slug)`,
/// который ловится в `onTapLink`. Если slug нет в каталоге — оставляется
/// сырой текст без декорации.
String _injectConceptLinks(
  String body,
  Map<String, Map<String, dynamic>> catalog,
) {
  return body.replaceAllMapped(_conceptLinkRegExp, (m) {
    final slug = (m.group(1) ?? '').toLowerCase();
    final visible = m.group(2);
    final concept = catalog[slug];
    if (concept == null) {
      // Концепции нет — показываем сырое слово (без квадратных скобок).
      return visible ?? slug;
    }
    final label = visible ?? (concept['title'] as String? ?? slug);
    return '[$label](aloria-concept://$slug)';
  });
}

/// Открывает bottom sheet с биографией концепции из inline-линка
/// `[[slug]]`. Переиспользует тот же `_ConceptBiographySheet`, что и
/// бейджи концепций в шапке урока.
void _showConceptSheet(BuildContext context, String slug, String label) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ConceptBiographySheet(slug: slug, title: label),
  );
}

/// Бейджи концепций урока: «Знакомлюсь / Углубляю / Применяю на практике».
/// Кликабельны — открывают bottom sheet с биографией концепции.
class _LessonConceptBadges extends StatelessWidget {
  const _LessonConceptBadges({required this.lesson, required this.tint});

  final Lesson lesson;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget chip(LessonConceptRef ref, String roleLabel, IconData icon) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showConceptSheet(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tint.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: tint),
              const SizedBox(width: 6),
              Text(
                ref.title,
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                roleLabel,
                style: text.labelSmall?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Introduce-бейджи не показываем: первая встреча с концепцией —
    // это и есть весь урок про неё, дополнительная метка лишняя.
    // Бейджи появляются только когда концепция возвращается (Deepen)
    // или применяется на практике (Apply) — это и есть спираль.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in lesson.deepens)
          chip(c, 'уже встречал', Icons.tune),
        for (final c in lesson.applies)
          chip(c, 'на практике', Icons.task_alt),
      ],
    );
  }

  void _showConceptSheet(BuildContext context, LessonConceptRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ConceptBiographySheet(slug: ref.slug, title: ref.title),
    );
  }
}

/// Bottom sheet с биографией концепции: где введена, где углубляется,
/// где применяется. Грузит данные с /api/v1/concepts/{slug}.
class _ConceptBiographySheet extends ConsumerWidget {
  const _ConceptBiographySheet({required this.slug, required this.title});

  final String slug;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final client = ref.read(learningApiClientProvider);
    final portfolioId = ref.read(aloriaPortfolioIdProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => FutureBuilder<Map<String, dynamic>>(
        future: client.fetchConcept(slug, portfolioId: portfolioId),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          final shortDef = (data['shortDefinition'] as String?) ?? '';
          final introductions = (data['introductions'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();

          // Где термин реально разбирается — берём первое «введение».
          // Это и есть тот урок, где концепция раскрывается как тема.
          // Показываем только информационно, без перехода: открытие урока
          // отсюда ломало бы стек навигации.
          final intro = introductions.isNotEmpty ? introductions.first : null;
          final introStage = (intro?['stageTitle'] as String?) ?? '';
          final introLesson = (intro?['lessonTitle'] as String?) ?? '';

          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(title, style: text.titleLarge)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (shortDef.isNotEmpty)
                Text(
                  shortDef,
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onSurface, height: 1.5),
                ),
              if (intro != null && introLesson.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: text.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            children: [
                              const TextSpan(text: 'Подробно разбирается в уроке '),
                              TextSpan(
                                text: '«$introLesson»',
                                style: text.bodySmall?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (introStage.isNotEmpty)
                                TextSpan(text: ' — этап «$introStage»'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

}
