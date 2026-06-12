import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/settings/application/settings_controller.dart';
import 'package:aloria/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Заголовок страницы портфеля: «Портфель» + кнопки учебного режима,
/// прогресса и настроек.
class PortfolioTitleBar extends ConsumerWidget {
  const PortfolioTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final learningMode = ref.watch(
      settingsControllerProvider.select((s) => s.learningMode),
    );
    return Row(
      children: [
        Text(
          l.portfolioTitle,
          style: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.0,
            letterSpacing: -0.4,
            color: scheme.onSurface,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            tooltip: l.settingsLearningMode,
            padding: EdgeInsets.zero,
            iconSize: 22,
            visualDensity: VisualDensity.compact,
            color: learningMode
                ? AppColors.primary
                : scheme.onSurfaceVariant,
            icon: Icon(
              learningMode ? Icons.school : Icons.school_outlined,
            ),
            onPressed: () => ref
                .read(settingsControllerProvider.notifier)
                .setLearningMode(!learningMode),
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            tooltip: 'Прогресс',
            padding: EdgeInsets.zero,
            iconSize: 22,
            visualDensity: VisualDensity.compact,
            color: scheme.onSurfaceVariant,
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push('/progress'),
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            tooltip: l.settingsTitle,
            padding: EdgeInsets.zero,
            iconSize: 22,
            visualDensity: VisualDensity.compact,
            color: scheme.onSurfaceVariant,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ),
      ],
    );
  }
}
