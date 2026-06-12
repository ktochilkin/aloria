import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/application/review_providers.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:aloria/features/learn/presentation/review_session_page.dart';
import 'package:aloria/features/learn/presentation/widgets/fading_header.dart';
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
class LearningPage extends ConsumerStatefulWidget {
  const LearningPage({super.key});

  @override
  ConsumerState<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends ConsumerState<LearningPage> {
  /// Прогресс затухания шапки 0..1 по скроллу (0 — вверху, 1 — уехали).
  final ValueNotifier<double> _headerFade = ValueNotifier(0);

  @override
  void dispose() {
    _headerFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(learningSectionsProvider);
    // Тихая синхронизация локального прогресса с сервером.
    ref.watch(learningProgressSyncProvider);
    // Фоновый прогрев кэша тел уроков — чтобы офлайн работал для любого
    // урока, а не только для уже открытых.
    ref.watch(lessonBodiesPrewarmProvider);


    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FadingHeader(
        fade: _headerFade,
        title: const Text('Обучение'),
        actions: [
          IconButton(
            tooltip: 'О Aloria',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showIntro(context),
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) => updateHeaderFade(_headerFade, n),
        child: sectionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Не удалось загрузить контент: $e')),
          data: (sections) => _LearningIndexBody(sections: sections),
        ),
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
    final dueReviews =
        ref.watch(dueReviewsProvider).valueOrNull ?? const <DueReview>[];

    final totalLessons = sections.fold<int>(
      0,
      (sum, s) => sum + s.lessons.length,
    );
    final completedLessons = sections.fold<int>(
      0,
      (sum, s) => sum + progress.readCountInSection(s),
    );

    return ListView(
      // На главной (в shell) Scaffold кладёт в padding.top именно нижнюю
      // границу шапки при extendBodyBehindAppBar — берём его как есть, без
      // добавления kToolbarHeight (иначе задвоение).
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top, 16,
          context.bottomNavBarPadding),
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
        if (dueReviews.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ReviewDueCard(items: dueReviews),
        ],
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Этапы',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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

    // Цельная заливка вместо «карточки с рамкой» — чтобы карта читалась
    // не как ещё один раздел, а как активный экран действия.
    return Material(
      color: section.tint.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        // Двухступенчатая навигация: сначала пушим экран этапа, потом
        // экран урока. Так стек становится [главная] → [этап] → [урок],
        // и кнопка «назад» из урока ведёт на этап, а не на главную.
        onTap: () {
          context.push('/learn/${section.id}');
          context.push('/learn/${section.id}/${lesson.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Большая кнопка-индикатор «играть» — визуальный якорь, что
              // это не раздел, а «продолжить читать».
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: section.tint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Продолжить чтение',
                      style: text.labelMedium?.copyWith(
                        color: section.tint,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lesson.title,
                      style: text.titleMedium?.copyWith(height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${section.title} · $sectionCompleted/$sectionTotal',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    ThinProgressBar(fraction: fraction, tint: section.tint),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: section.tint),
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
        // Двухступенчатая навигация — см. _ContinueCard.
        onTap: () {
          context.push('/learn/${section.id}');
          context.push('/learn/${section.id}/${lesson.id}');
        },
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
// Карточка «К повторению» — открывает сессию разнесённого повторения.
// ---------------------------------------------------------------------------

class _ReviewDueCard extends StatelessWidget {
  const _ReviewDueCard({required this.items});

  final List<DueReview> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => ReviewSessionPage(items: items),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.primary.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.refresh, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('К повторению',
                        style: text.titleMedium?.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(
                      '${items.length} ${_plural(items.length)} ждут разбора',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  String _plural(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'карточка';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'карточки';
    }
    return 'карточек';
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: section.tint.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(section.icon, color: section.tint, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: text.titleMedium?.copyWith(height: 1.15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (section.isOptional) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'опционально',
                              style: text.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          section.goal ?? section.subtitle,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (section.targetMinutes != null || section.practiceTotal > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      if (section.targetMinutes != null) ...[
                        Icon(Icons.schedule, size: 13,
                            color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '~${section.targetMinutes} мин',
                          style: text.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (section.practiceTotal > 0) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.star_outline, size: 13,
                            color: section.tint),
                        const SizedBox(width: 4),
                        Text(
                          section.practiceTotal == 1
                              ? 'главное задание'
                              : 'заданий ×${section.practiceTotal}',
                          style: text.labelSmall?.copyWith(
                            color: section.tint,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ThinProgressBar(fraction: fraction, tint: section.tint),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    completed == 0
                        ? 'Не начат'
                        : completed == total
                            ? 'Раздел пройден'
                            : '$completed из $total',
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
