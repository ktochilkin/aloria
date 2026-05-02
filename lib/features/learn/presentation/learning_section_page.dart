import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/domain/models.dart';
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

class _SectionBody extends ConsumerWidget {
  const _SectionBody({required this.section});

  final LearningSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(learningProgressProvider);
    final completed = progress.readCountInSection(section);
    final total = section.lessons.length;

    final currentIndex = _findCurrentIndex(section, progress);

    return Scaffold(
      appBar: AppBar(
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
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, context.bottomNavBarPadding),
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
            ...List.generate(total, (i) {
              final lesson = section.lessons[i];
              final isRead = progress.isLessonRead(section.id, lesson.id);
              final status = isRead
                  ? RoadmapNodeStatus.completed
                  : i == currentIndex
                      ? RoadmapNodeStatus.current
                      : RoadmapNodeStatus.available;
              return LessonRoadmapNode(
                index: i + 1,
                lesson: lesson,
                tint: section.tint,
                status: status,
                isFirst: i == 0,
                isLast: i == total - 1,
                onTap: () =>
                    context.push('/learn/${section.id}/${lesson.id}'),
              );
            }),
        ],
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
