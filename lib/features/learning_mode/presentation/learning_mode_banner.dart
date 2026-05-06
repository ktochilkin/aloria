import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/settings/application/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Тонкая полоска сверху всех экранов, видна только при включённом
/// режиме обучения. Позволяет одним тапом выйти из режима.
class LearningModeBanner extends ConsumerWidget {
  const LearningModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      settingsControllerProvider.select((s) => s.learningMode),
    );
    if (!on) return const SizedBox.shrink();

    return Material(
      color: AppColors.primary,
      child: InkWell(
        onTap: () =>
            ref.read(settingsControllerProvider.notifier).setLearningMode(false),
        child: const SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.school, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Режим обучения интерфейсу · тапни элемент с подсветкой',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Выйти',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.close, size: 14, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
