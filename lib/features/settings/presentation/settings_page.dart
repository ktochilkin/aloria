import 'package:aloria/features/auth/application/auth_controller.dart';
import 'package:aloria/features/settings/application/settings_controller.dart';
import 'package:aloria/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final auth = ref.read(authControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.settingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(title: l.settingsTheme),
          _ThemeOption(
            label: l.settingsThemeSystem,
            mode: ThemeMode.system,
            selected: settings.themeMode,
            onTap: controller.setThemeMode,
          ),
          _ThemeOption(
            label: l.settingsThemeLight,
            mode: ThemeMode.light,
            selected: settings.themeMode,
            onTap: controller.setThemeMode,
          ),
          _ThemeOption(
            label: l.settingsThemeDark,
            mode: ThemeMode.dark,
            selected: settings.themeMode,
            onTap: controller.setThemeMode,
          ),

          const Divider(height: 32),
          _SectionHeader(title: l.settingsLanguage),
          _LocaleOption(
            label: l.settingsLanguageSystem,
            tag: null,
            selected: settings.localeTag,
            onTap: controller.setLocaleTag,
          ),
          _LocaleOption(
            label: l.settingsLanguageRu,
            tag: 'ru',
            selected: settings.localeTag,
            onTap: controller.setLocaleTag,
          ),
          _LocaleOption(
            label: l.settingsLanguageEn,
            tag: 'en',
            selected: settings.localeTag,
            onTap: controller.setLocaleTag,
          ),

          const Divider(height: 32),
          SwitchListTile(
            title: Text(l.settingsLearningMode),
            subtitle: Text(l.settingsLearningModeHint),
            value: settings.learningMode,
            onChanged: controller.setLearningMode,
          ),

          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l.settingsLogout),
            onTap: () async {
              await auth.logout();
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: text.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final ThemeMode mode;
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == mode;
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => onTap(mode),
    );
  }
}

class _LocaleOption extends StatelessWidget {
  const _LocaleOption({
    required this.label,
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? tag;
  final String? selected;
  final ValueChanged<String?> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == tag;
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => onTap(tag),
    );
  }
}
