import 'package:aloria/core/theme/canvas_switch.dart';
import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:aloria/features/learn/presentation/widgets/fading_header.dart';
import 'package:aloria/features/learn/presentation/widgets/learning_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Экран одного раздела обучения. Показывает вертикальную дорожку уроков:
/// слева — соединительная линия и статус-кружок (число / галочка),
/// справа — карточка урока с метаданными (длительность, наличие теста).
class LearningSectionPage extends ConsumerWidget {
  const LearningSectionPage({super.key, required this.sectionId});

  final String sectionId;

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
        body: Center(child: Text('Не удалось загрузить раздел: $e')),
      ),
      data: (sections) {
        final section = _findSection(sections, sectionId);
        if (section == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Раздел не найден')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось найти раздел «$sectionId».',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _SectionBody(section: section);
      },
    );
  }

  static LearningSection? _findSection(
    List<LearningSection> sections,
    String id,
  ) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }
}

class _SectionBody extends ConsumerStatefulWidget {
  const _SectionBody({required this.section});

  final LearningSection section;

  @override
  ConsumerState<_SectionBody> createState() => _SectionBodyState();
}

class _SectionBodyState extends ConsumerState<_SectionBody> {
  final ValueNotifier<double> _headerFade = ValueNotifier(0);

  @override
  void dispose() {
    _headerFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final progress = ref.watch(learningProgressProvider);
    final completed = progress.readCountInSection(section);
    final total = section.lessons.length;

    final currentIndex = _findCurrentIndex(section, progress);
    final learnBg = Theme.of(context).brightness == Brightness.light
        ? ref.watch(canvasColorProvider)
        : null;

    return Scaffold(
      backgroundColor: learnBg,
      extendBodyBehindAppBar: true,
      appBar: FadingHeader(
        fade: _headerFade,
        baseColor: learnBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Назад',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/learn');
            }
          },
        ),
        title: Text(section.title),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) => updateHeaderFade(_headerFade, n),
        child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, fadingHeaderTopInset(context), 16, context.bottomNavBarPadding),
        children: [
          _SectionHeaderCard(
            section: section,
            completed: completed,
            total: total,
          ),
          const SizedBox(height: 16),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'В разделе пока нет уроков.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ..._buildRoadmap(context, section, progress, currentIndex),
          if (section.practice.isNotEmpty) ...[
            const SizedBox(height: 20),
            _StagePracticeBlock(section: section),
          ],
        ],
        ),
      ),
    );
  }

  int _findCurrentIndex(
    LearningSection section,
    LearningProgressState progress,
  ) {
    for (var i = 0; i < section.lessons.length; i++) {
      if (!progress.isLessonRead(section.id, section.lessons[i].id)) return i;
    }
    return -1; // всё пройдено
  }

  /// Строит дорожку уроков с заголовками-главами. Уроки с непустым
  /// [Lesson.group] объединяются под общим заголовком; на границе главы линия
  /// дорожки прерывается. Если глав нет (group пуст у всех) — обычная сплошная
  /// дорожка, как раньше.
  List<Widget> _buildRoadmap(
    BuildContext context,
    LearningSection section,
    LearningProgressState progress,
    int currentIndex,
  ) {
    final lessons = section.lessons;
    final total = lessons.length;
    final children = <Widget>[];

    for (var i = 0; i < total; i++) {
      final lesson = lessons[i];
      final group = (lesson.group ?? '').trim();
      final prevGroup = i == 0 ? null : (lessons[i - 1].group ?? '').trim();
      final nextGroup =
          i == total - 1 ? null : (lessons[i + 1].group ?? '').trim();
      final firstInGroup = i == 0 || group != prevGroup;
      final lastInGroup = i == total - 1 || group != nextGroup;

      if (group.isNotEmpty && firstInGroup) {
        children.add(_ChapterHeader(
          title: group,
          tint: section.tint,
          isFirst: i == 0,
        ));
      }

      final isRead = progress.isLessonRead(section.id, lesson.id);
      final status = isRead
          ? RoadmapNodeStatus.completed
          : i == currentIndex
              ? RoadmapNodeStatus.current
              : RoadmapNodeStatus.available;

      children.add(LessonRoadmapNode(
        index: i + 1,
        lesson: lesson,
        tint: section.tint,
        status: status,
        isFirst: firstInGroup,
        isLast: lastInGroup,
        onTap: () => context.push('/learn/${section.id}/${lesson.id}'),
      ));
    }
    return children;
  }
}

/// Блок «Закрепить на рынке» — список требований практики этапа с пометкой,
/// что уже выполнено. Это спиральный капстоун: этап считается полностью
/// пройденным, когда выполнены все обязательные требования.
class _StagePracticeBlock extends StatelessWidget {
  const _StagePracticeBlock({required this.section});

  final LearningSection section;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tint = section.tint;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: tint.withValues(alpha: 0.06),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt, color: tint),
              const SizedBox(width: 8),
              Text(
                'Закрепить на рынке',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Чтобы закрыть этап, попробуй это вживую на учебном счёте. '
            'Сделка засчитается автоматически — деньги учебные, риска нет.',
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          for (final p in section.practice) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.fulfilled
                          ? AppColors.success.withValues(alpha: 0.18)
                          : tint.withValues(alpha: 0.12),
                      border: Border.all(
                        color: p.fulfilled ? AppColors.success : tint,
                        width: 1.4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: p.fulfilled
                        ? const Icon(Icons.check,
                            size: 16, color: AppColors.success)
                        : Icon(Icons.circle_outlined, size: 12, color: tint),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.title,
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  decoration: p.fulfilled
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: p.fulfilled
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                            if (p.isOptional) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'опц.',
                                  style: text.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (p.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            p.description,
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (section.practice.any((p) => !p.fulfilled)) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.go('/market'),
                icon: const Icon(Icons.arrow_outward, size: 16),
                label: const Text('Открыть рынок'),
                style: TextButton.styleFrom(foregroundColor: tint),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeaderCard extends StatelessWidget {
  const _SectionHeaderCard({
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
    final isDone = total > 0 && completed == total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            section.tint.withValues(alpha: 0.18),
            section.tint.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: section.tint.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: section.tint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: section.tint.withValues(alpha: 0.4)),
                ),
                child: Icon(section.icon, color: section.tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title, style: text.titleMedium?.copyWith(
                      fontSize: 20,
                    )),
                    const SizedBox(height: 4),
                    Text(
                      section.subtitle,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                '$completed/$total',
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDone
                      ? AppColors.success
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isDone
                ? 'Раздел пройден. Можно вернуться к любому уроку.'
                : completed == 0
                    ? 'В разделе $total ${_lessonWord(total)}. Начни с первого.'
                    : 'Осталось ${total - completed} ${_lessonWord(total - completed)}.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static String _lessonWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'урок';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return 'урока';
    }
    return 'уроков';
  }
}

/// Заголовок-глава внутри дорожки раздела: маркер цвета раздела + название.
class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({
    required this.title,
    required this.tint,
    required this.isFirst,
  });

  final String title;
  final Color tint;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 20, bottom: 6, left: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: text.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: tint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
