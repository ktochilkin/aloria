import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learn/domain/learning_content_service.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  final _contentService = LearningContentService();
  late Future<List<LearningSection>> _sectionsFuture;
  late Future<String> _introFuture;

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _contentService.loadSections();
    _introFuture = _contentService.loadIntro();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Обучение')),
      body: FutureBuilder<List<LearningSection>>(
        future: _sectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }

          final sections = snapshot.data ?? [];

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                sliver: SliverList.list(
                  children: [
                    FutureBuilder<String>(
                      future: _introFuture,
                      builder: (context, introSnapshot) {
                        final intro = introSnapshot.data ?? '';
                        return _HeroCard(
                          title: 'Открой мир Aloria',
                          subtitle:
                              'Учебный рынок без риска: заявки, сделки, цены — всё как вживую, только безопасно.',
                          scheme: scheme,
                          body: intro,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    ...sections.map(
                      (section) => _SectionCard(section: section),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LearningSectionPage extends StatefulWidget {
  const LearningSectionPage({super.key, required this.sectionId});

  final String sectionId;

  @override
  State<LearningSectionPage> createState() => _LearningSectionPageState();
}

class _LearningSectionPageState extends State<LearningSectionPage> {
  final _contentService = LearningContentService();
  late Future<LearningSection?> _sectionFuture;

  @override
  void initState() {
    super.initState();
    _sectionFuture = _loadSection();
  }

  Future<LearningSection?> _loadSection() async {
    final sections = await _contentService.loadSections();
    return _contentService.findSectionById(sections, widget.sectionId);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<LearningSection?>(
      future: _sectionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Загрузка...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final section = snapshot.data;
        if (section == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ошибка')),
            body: const Center(child: Text('Раздел не найден')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Назад',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                context.go('/learn');
              },
            ),
            title: Text(section.title),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 1),
            itemCount: section.lessons.length,
            itemBuilder: (context, index) {
              final lesson = section.lessons[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        context.push('/learn/${section.id}/${lesson.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LessonImage(
                          source: lesson.imageUrl,
                          height: 180,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          scheme: scheme,
                          tint: section.tint,
                          icon: section.icon,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lesson.title, style: text.titleMedium),
                              const SizedBox(height: 6),
                              Text(
                                lesson.description,
                                style: text.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class LessonPage extends StatefulWidget {
  const LessonPage({
    super.key,
    required this.sectionId,
    required this.lessonId,
  });

  final String sectionId;
  final String lessonId;

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  final _contentService = LearningContentService();
  late Future<_LessonData?> _lessonFuture;

  @override
  void initState() {
    super.initState();
    _lessonFuture = _loadLesson();
  }

  Future<_LessonData?> _loadLesson() async {
    final sections = await _contentService.loadSections();
    final section = _contentService.findSectionById(sections, widget.sectionId);
    if (section == null) return null;

    final lesson = _contentService.findLessonById(section, widget.lessonId);
    if (lesson == null) return null;

    return _LessonData(section: section, lesson: lesson);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<_LessonData?>(
      future: _lessonFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Загрузка...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ошибка')),
            body: const Center(child: Text('Урок не найден')),
          );
        }

        final section = data.section;
        final lesson = data.lesson;

        void popOrFallback() {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/learn');
          }
        }

        return Scaffold(
          appBar: AppBar(title: Text(lesson.title)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              _LessonImage(
                source: lesson.imageUrl,
                height: 220,
                borderRadius: BorderRadius.circular(16),
                scheme: scheme,
                tint: section.tint,
                icon: section.icon,
              ),
              const SizedBox(height: 16),
              Text(lesson.title, style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(
                lesson.description,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _DefinitionBlock(
                title: 'Академическое определение',
                content: lesson.academicDefinition,
                tint: section.tint,
              ),
              const SizedBox(height: 16),
              MarkdownBody(
                data: lesson.body,
                styleSheet: MarkdownStyleSheet.fromTheme(
                  Theme.of(context),
                ).copyWith(p: text.bodyMedium),
                imageBuilder: (uri, title, alt) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        uri.toString(),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stack) {
                          return Container(
                            height: 200,
                            color: scheme.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  alt ?? 'Изображение не загружено',
                                  style: text.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: popOrFallback,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Вернуться к списку'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LessonData {
  final LearningSection section;
  final Lesson lesson;

  _LessonData({required this.section, required this.lesson});
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.scheme,
    required this.body,
  });
  final String title;
  final String subtitle;
  final ColorScheme scheme;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showIntro(context, title, body, scheme),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              scheme.primary.withValues(alpha: 0.12),
              scheme.secondary.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Подробнее',
                    style: text.labelMedium?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.7),
                ),
              ),
              child: const Icon(
                Icons.emoji_events,
                size: 40,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});
  final LearningSection section;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/learn/${section.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: section.tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(section.icon, color: section.tint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title, style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      section.subtitle,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 18,
                          color: section.tint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${section.lessons.length} урок(ов)',
                          style: text.labelMedium?.copyWith(
                            color: section.tint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

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
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleSmall?.copyWith(color: tint)),
          const SizedBox(height: 6),
          Text(content, style: text.bodyMedium),
        ],
      ),
    );
  }
}

class _LessonImage extends StatelessWidget {
  const _LessonImage({
    required this.source,
    required this.height,
    required this.borderRadius,
    required this.scheme,
    this.tint,
    this.icon,
  });

  final String source;
  final double height;
  final BorderRadius borderRadius;
  final ColorScheme scheme;
  final Color? tint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Для статей без картинки ничего не показываем
    if (source.isEmpty) {
      return const SizedBox.shrink();
    }

    final isRemote = source.startsWith('http');

    Widget fallbackContainer() => Container(
      height: height,
      color: scheme.surfaceContainerHighest,
      child: const Icon(Icons.image_not_supported),
    );

    final image = isRemote
        ? Image.network(
            source,
            height: height,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => fallbackContainer(),
          )
        : Image.asset(
            source,
            height: height,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => fallbackContainer(),
          );

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(height: height, color: Colors.white, child: image),
    );
  }
}

void _showIntro(
  BuildContext context,
  String title,
  String body,
  ColorScheme scheme,
) {
  final text = Theme.of(context).textTheme;
  showModalBottomSheet(
    context: context,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.6,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ListView(
          controller: controller,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: text.titleMedium)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MarkdownBody(
              data: body,
              styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context),
              ).copyWith(p: text.bodyMedium),
              imageBuilder: (uri, title, alt) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      uri.toString(),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stack) {
                        return Container(
                          height: 200,
                          color: scheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.image_not_supported,
                            color: scheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
