import 'package:aloria/core/push/push_categories.dart';
import 'package:aloria/core/push/push_controller.dart';
import 'package:aloria/core/push/push_prefs_controller.dart';
import 'package:aloria/core/push/push_service.dart';
import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Состояние системного разрешения на уведомления. Читаем только там,
/// где push-канал подключён (сейчас iOS) — см. [isPushPlatformReady].
final _permissionProvider = FutureProvider.autoDispose<PushPermission>(
  (ref) => ref.watch(pushServiceProvider).permissionStatus(),
);

/// Экран «Уведомления»: статус системного разрешения и тумблеры категорий.
///
/// Тумблеры работают на всех платформах: маска сохраняется локально и
/// синхронизируется на бэк, даже если сами пуши на платформе ещё не подключены.
class PushSettingsPage extends ConsumerWidget {
  const PushSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mask = ref.watch(pushPrefsProvider);
    final prefs = ref.read(pushPrefsProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Уведомления'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _StatusCard(),
          const SizedBox(height: 20),
          const _SectionLabel(text: 'Что присылать'),
          _Card(
            children: [
              for (final (i, category) in PushCategory.values.indexed) ...[
                if (i != 0) const _Sep(),
                _CategoryTile(
                  category: category,
                  value: category.enabledIn(mask),
                  onChanged: (v) => prefs.toggle(category, v),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Карточка со статусом уведомлений: на iOS — реальное состояние системного
/// разрешения, на остальных платформах — честная строка о том, что канал
/// ещё не подключён.
class _StatusCard extends ConsumerWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isPushPlatformReady) {
      return const _StatusCardBody(
        icon: Icons.notifications_paused_outlined,
        title: 'На этой платформе пуши появятся позже',
        subtitle: 'Уведомления здесь пока не приходят — платформа ещё '
            'подключается. Выбор категорий уже сохраняется и применится '
            'автоматически.',
      );
    }
    final permission = ref.watch(_permissionProvider);
    return permission.when(
      loading: () => const _StatusCardBody(
        icon: Icons.notifications_outlined,
        title: 'Проверяем разрешение',
        subtitle: 'Смотрим, разрешены ли уведомления в системе.',
      ),
      error: (_, _) => const _StatusCardBody(
        icon: Icons.notifications_outlined,
        title: 'Не удалось проверить разрешение',
        subtitle: 'Выбор категорий всё равно сохраняется.',
      ),
      data: (status) => switch (status) {
        PushPermission.granted => const _StatusCardBody(
            icon: Icons.notifications_active_outlined,
            title: 'Уведомления разрешены',
            subtitle: 'Присылаем только то, что включено ниже.',
          ),
        PushPermission.denied => const _StatusCardBody(
            icon: Icons.notifications_off_outlined,
            title: 'Уведомления выключены в системе',
            subtitle: 'Чтобы пуши приходили, разреши уведомления для Aloria '
                'в настройках устройства.',
          ),
        PushPermission.notDetermined => const _StatusCardBody(
            icon: Icons.notifications_outlined,
            title: 'Разрешение ещё не запрошено',
            subtitle: 'Система спросит разрешение при следующем входе '
                'в приложение.',
          ),
      },
    );
  }
}

class _StatusCardBody extends StatelessWidget {
  const _StatusCardBody({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.palette.heroBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Тумблер одной категории пушей с коротким описанием.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.value,
    required this.onChanged,
  });

  final PushCategory category;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      title: Text(
        category.title,
        style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          category.description,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.palette.heroBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(height: 1, color: context.palette.heroBorder),
    );
  }
}
