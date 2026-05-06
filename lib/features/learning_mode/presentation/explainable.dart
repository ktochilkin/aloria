import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learning_mode/data/explanations.dart';
import 'package:aloria/features/settings/application/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Обёртка вокруг блока интерфейса, у которого есть объяснение.
///
/// В обычном режиме — прозрачный pass-through.
/// В режиме обучения (см. [SettingsController.setLearningMode]):
///   - подсвечивается мягкой пульсирующей рамкой
///   - в правом верхнем углу появляется бейдж «?»
///   - тапы перехватываются: вместо действия открывается боттом-шит
///     с markdown-объяснением
///
/// Контент берётся из [explanationsRu] по [slug]. Если нет — без подсветки.
class Explainable extends ConsumerWidget {
  const Explainable({
    super.key,
    required this.slug,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final String slug;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      settingsControllerProvider.select((s) => s.learningMode),
    );
    if (!mode) return child;

    final explanation = explanationsRu[slug];
    if (explanation == null) return child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showSheet(context, explanation),
      child: AbsorbPointer(
        child: _Highlight(
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }

  void _showSheet(BuildContext context, Explanation e) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ExplanationSheet(explanation: e),
    );
  }
}

class _Highlight extends StatefulWidget {
  const _Highlight({
    required this.borderRadius,
    required this.child,
  });

  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<_Highlight> createState() => _HighlightState();
}

class _HighlightState extends State<_Highlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        final borderAlpha = 0.30 + 0.30 * t;
        final fillAlpha = 0.04 + 0.06 * t;
        final glowAlpha = 0.12 + 0.10 * t;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                color: AppColors.primary.withValues(alpha: fillAlpha),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: borderAlpha),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: glowAlpha),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: widget.child,
            ),
            Positioned(
              top: -6,
              right: -6,
              child: _HelpBadge(),
            ),
          ],
        );
      },
    );
  }
}

class _HelpBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.40),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.question_mark_rounded,
          color: Colors.white, size: 14),
    );
  }
}

class _ExplanationSheet extends StatelessWidget {
  const _ExplanationSheet({required this.explanation});

  final Explanation explanation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lightbulb_outline,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    explanation.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: explanation.body,
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                    strong: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
