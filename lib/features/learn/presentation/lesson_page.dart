import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/core/widgets/state_placeholder.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/learn/data/learning_content_cache.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:aloria/features/learn/presentation/widgets/fading_header.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_bottom_actions.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_concepts.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_images.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_info_cards.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_markdown_body.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_progress_header.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_quiz_block.dart';
import 'package:aloria/features/learn/presentation/widgets/recall_card.dart';
import 'package:aloria/features/learn/presentation/widgets/server_quiz_block.dart';
import 'package:flutter/material.dart';
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
        appBar: AppBar(),
        body: StatePlaceholder(
          framed: false,
          icon: Icons.cloud_off_outlined,
          title: 'Не получилось загрузить урок',
          message: 'Проверь соединение и попробуй ещё раз.',
          actionLabel: 'Обновить',
          onAction: () => ref.invalidate(learningSectionsProvider),
        ),
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

  /// Затухание шапки урока по скроллу (0 — вверху, 1 — уехали).
  final ValueNotifier<double> _headerFade = ValueNotifier(0);

  @override
  void dispose() {
    _headerFade.dispose();
    super.dispose();
  }

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
      extendBodyBehindAppBar: true,
      appBar: FadingHeader(
        fade: _headerFade,
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
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) => updateHeaderFade(_headerFade, n),
        child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, fadingHeaderTopInset(context), 16, context.bottomNavBarPadding),
        children: [
          LessonProgressHeader(
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
              child: LessonImage(
                source: _effectiveLesson.imageUrl,
                fallbackTint: widget.section.tint,
                fallbackIcon: widget.section.icon,
              ),
            ),
          if (_effectiveLesson.isCapstone)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LessonCapstoneBadge(tint: widget.section.tint),
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
            LessonConceptBadges(
              lesson: _effectiveLesson,
              tint: widget.section.tint,
            ),
          ],
          if (_effectiveLesson.academicDefinition.isNotEmpty) ...[
            const SizedBox(height: 14),
            LessonDefinitionBlock(
              title: 'Академическое определение',
              content: _effectiveLesson.academicDefinition,
              tint: widget.section.tint,
            ),
          ],
          const SizedBox(height: 18),
          LessonMarkdownBody(
            body: _effectiveLesson.body,
            tint: widget.section.tint,
          ),
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
            LessonPracticeCard(
              tint: widget.section.tint,
              text: _effectiveLesson.practiceText!.trim(),
              symbol: _effectiveLesson.practiceSymbol,
            ),
          ],
          const SizedBox(height: 22),
          LessonBottomActions(
            section: widget.section,
            lessonIndex: widget.index,
            hasNext: hasNext,
          ),
          const SizedBox(height: 12),
        ],
        ),
      ),
    );
  }
}
