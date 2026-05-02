import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:aloria/features/learn/presentation/widgets/learning_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Главный экран раздела «Обучение».
///
/// Структура сверху вниз:
///   1. Краткое приветствие + кнопка «О Aloria» (открывает intro.md в шторке).
///   2. Карточка «Продолжить» — последний открытый урок (если был).
///      Если ещё ничего не открывалось — карточка «Начать с первого урока».
///   3. Панели разделов с кольцом прогресса и кратким списком тем.
class LearningPage extends ConsumerWidget {
  const LearningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(learningSectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Обучение'),
        actions: [
          IconButton(
            tooltip: 'О Aloria',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showIntro(context),
          ),
        ],
      ),
      body: sectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Не удалось загрузить контент: $e')),
        data: (sections) =>
            _LearningIndexBody(sections: sections),
      ),
    );
  }

  void _showIntro(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _IntroSheet(),
    );
  }
}

class _LearningIndexBody extends ConsumerWidget {
  const _LearningIndexBody({required this.sections});

  final List<LearningSection> sections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(learningProgressProvider);
    final lastVisited = ref.watch(lastVisitedLessonProvider);
    final hint = ref.watch(nextLessonHintProvider);

    final totalLessons = sections.fold<int>(
      0,
      (sum, s) => sum + s.lessons.length,
    );
    final completedLessons = sections.fold<int>(
      0,
      (sum, s) => sum + progress.readCountInSection(s),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, context.bottomNavBarPadding),
      children: [
        _OverviewHeader(
          completed: completedLessons,
          total: totalLessons,
        ),
        const SizedBox(height: 16),
        if (lastVisited != null)
          _ContinueCard(
            section: lastVisited.section,
            lesson: lastVisited.lesson,
            sectionCompleted:
                progress.readCountInSection(lastVisited.section),
            sectionTotal: lastVisited.section.lessons.length,
          )
        else if (hint != null)
          _StartCard(section: hint.section, lesson: hint.lesson),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Разделы',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
          ),
        ),
        ...sections.map((section) {
          final completed = progress.readCountInSection(section);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SectionPanel(
              section: section,
              completed: completed,
              total: section.lessons.length,
            ),
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Шапка с общим прогрессом по обучению.
// ---------------------------------------------------------------------------

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final fraction = total == 0 ? 0.0 : completed / total;
    final percent = (fraction * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.18),
            scheme.tertiary.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Твой прогресс', style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                    )),
                    const SizedBox(height: 4),
                    Text(
                      '$completed из $total уроков',
                      style: text.titleMedium?.copyWith(fontSize: 22),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outline),
                ),
                child: Text(
                  '$percent%',
                  style: text.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ThinProgressBar(fraction: fraction, tint: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            'В Aloria сначала разбираешься, как устроен рынок, '
            'а потом применяешь это в учебной торговле без риска.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка «Продолжить» — открывает последний просмотренный урок.
// ---------------------------------------------------------------------------

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.section,
    required this.lesson,
    required this.sectionCompleted,
    required this.sectionTotal,
  });

  final LearningSection section;
  final Lesson lesson;
  final int sectionCompleted;
  final int sectionTotal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fraction = sectionTotal == 0 ? 0.0 : sectionCompleted / sectionTotal;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/learn/${section.id}/${lesson.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: section.tint.withValues(alpha: 0.55)),
          ),
          child: Column(
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
                      'Продолжить',
                      style: text.labelMedium?.copyWith(
                        color: section.tint,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      section.title,
                      style: text.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(lesson.title, style: text.titleMedium),
              if (lesson.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  lesson.description,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ThinProgressBar(
                      fraction: fraction,
                      tint: section.tint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$sectionCompleted/$sectionTotal',
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.chevron_right, color: section.tint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.section, required this.lesson});

  final LearningSection section;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/learn/${section.id}/${lesson.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: section.tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.play_arrow, color: section.tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Начать с первого урока',
                        style: text.titleMedium?.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(
                      '${section.title} · ${lesson.title}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Панель раздела.
// ---------------------------------------------------------------------------

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.section,
    required this.completed,
    required this.total,
  });

  final LearningSection section;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fraction = total == 0 ? 0.0 : completed / total;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/learn/${section.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: section.tint.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(section.icon, color: section.tint),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section.title, style: text.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          section.subtitle,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SectionProgressRing(
                    completed: completed,
                    total: total,
                    tint: section.tint,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ThinProgressBar(fraction: fraction, tint: section.tint),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    completed == 0
                        ? 'Не начат'
                        : completed == total
                            ? 'Раздел пройден'
                            : 'В процессе',
                    style: text.labelMedium?.copyWith(
                      color: completed == total && total > 0
                          ? AppColors.success
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'К урокам',
                    style: text.labelMedium?.copyWith(
                      color: section.tint,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: section.tint, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Шторка с вступительным текстом (intro.md).
// ---------------------------------------------------------------------------

class _IntroSheet extends ConsumerWidget {
  const _IntroSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final introAsync = ref.watch(learningIntroProvider);
    final text = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ListView(
          controller: controller,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('О Aloria', style: text.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            introAsync.when(
              loading: () =>
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )),
              error: (e, _) => Text('Не удалось загрузить вступление: $e'),
              data: (intro) => MarkdownBody(
                data: intro,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(p: text.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
