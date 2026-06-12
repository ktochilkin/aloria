import 'package:aloria/features/learn/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Нижний блок действий урока: CTA «Следующий урок» / «К списку раздела»
/// и кнопка возврата ко всем урокам.
class LessonBottomActions extends StatelessWidget {
  const LessonBottomActions({
    super.key,
    required this.section,
    required this.lessonIndex,
    required this.hasNext,
  });

  /// Раздел текущего урока.
  final LearningSection section;

  /// Индекс текущего урока в разделе.
  final int lessonIndex;

  /// Есть ли следующий урок в разделе.
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
