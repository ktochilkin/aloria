import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Регулярка для inline-линков на концепцию в markdown: `[[slug]]` или
/// `[[slug|видимый текст]]`. Slug = латиница/цифры/дефисы.
final _conceptLinkRegExp = RegExp(r'\[\[([a-z0-9_-]+)(?:\|([^\]]+))?\]\]');

/// Подставляет в markdown-тело урока ссылки на концепции. `[[slug]]`
/// заменяется на стандартный markdown-линк `[Название](aloria-concept://slug)`,
/// который ловится в `onTapLink`. Если slug нет в каталоге — оставляется
/// сырой текст без декорации.
String injectConceptLinks(
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

/// Открывает bottom sheet с биографией концепции — и из inline-линка
/// `[[slug]]`, и из бейджей концепций в шапке урока.
void showConceptBiographySheet(
  BuildContext context, {
  required String slug,
  required String title,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ConceptBiographySheet(slug: slug, title: title),
  );
}

/// Бейджи концепций урока: «Знакомлюсь / Углубляю / Применяю на практике».
/// Кликабельны — открывают bottom sheet с биографией концепции.
class LessonConceptBadges extends StatelessWidget {
  const LessonConceptBadges({
    super.key,
    required this.lesson,
    required this.tint,
  });

  /// Урок, чьи возвращающиеся концепции показываем.
  final Lesson lesson;

  /// Акцент раздела.
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget chip(LessonConceptRef ref, String roleLabel, IconData icon) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showConceptBiographySheet(
          context,
          slug: ref.slug,
          title: ref.title,
        ),
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
}

/// Bottom sheet с биографией концепции: где введена, где углубляется,
/// где применяется. Грузит данные с /api/v1/concepts/{slug}.
class ConceptBiographySheet extends ConsumerWidget {
  const ConceptBiographySheet({
    super.key,
    required this.slug,
    required this.title,
  });

  /// Slug концепции в каталоге.
  final String slug;

  /// Заголовок шторки (название концепции).
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
                              const TextSpan(
                                  text: 'Подробно разбирается в уроке '),
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
