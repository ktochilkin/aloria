import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_blocks.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_concepts.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Markdown-тело урока: подставляет inline-линки концепций `[[slug]]`,
/// рендерит текстовые сегменты через [MarkdownBody] со стилем урока, а
/// директивы `:::block` — интерактивными виджетами из реестра блоков.
class LessonMarkdownBody extends ConsumerWidget {
  const LessonMarkdownBody({
    super.key,
    required this.body,
    required this.tint,
  });

  /// Сырое markdown-тело урока.
  final String body;

  /// Акцент раздела — цвет блок-цитат, картинок-фолбэков и блоков.
  final Color tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final catalog = ref.watch(conceptsCatalogProvider).valueOrNull ?? const {};
    // Препроцессинг: [[slug]] или [[slug|видимый текст]] →
    // обычный markdown-линк с уникальной схемой aloria-concept://.
    // Если slug нет в каталоге — оставляем сырой текст без линка.
    final processed = injectConceptLinks(body, catalog);

    // Текстовые сегменты рендерим одинаково; директивы `:::block`
    // превращаются в интерактивные виджеты из реестра. `lead: true` —
    // крупный выделенный вводный абзац (врезка `:::lead`).
    Widget markdown(String data, {bool lead = false}) => MarkdownBody(
          data: data,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: lead
                ? text.bodyMedium?.copyWith(
                    fontSize: 16.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  )
                : text.bodyMedium?.copyWith(height: 1.55),
            h1: text.titleMedium?.copyWith(fontSize: 22),
            h2: text.titleMedium?.copyWith(fontSize: 19),
            h3: text.titleMedium?.copyWith(fontSize: 17),
            blockquote: text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            blockquoteDecoration: BoxDecoration(
              color: tint.withValues(alpha: 0.06),
              border: Border.all(color: tint.withValues(alpha: 0.30)),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
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
              showConceptBiographySheet(context, slug: slug, title: label);
            }
          },
          sizedImageBuilder: (config) => LessonMarkdownImage(
            uri: config.uri,
            alt: config.alt,
            fallbackTint: tint,
          ),
        );

    final segments = parseLessonSegments(processed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final segment in segments)
          if (segment is LessonText)
            markdown(segment.markdown)
          else if (segment is LessonLead)
            Container(
              margin: const EdgeInsets.only(top: 2, bottom: 12),
              padding: const EdgeInsets.fromLTRB(14, 2, 2, 2),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: tint, width: 3)),
              ),
              child: markdown(segment.markdown, lead: true),
            )
          else if (segment is LessonBlock)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: lessonBlockBuilders[segment.name]!(context, tint),
            ),
      ],
    );
  }
}
