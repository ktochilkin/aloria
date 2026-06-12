import 'package:flutter/material.dart';

/// Заглушка состояния «пусто / не получилось»: мягкая иконка в круге,
/// человеческий заголовок, необязательное пояснение и действие.
/// Используется вместо сырых `Text('Ошибка: $e')` по §6.3 — причину
/// объясняем словами, без технических деталей.
class StatePlaceholder extends StatelessWidget {
  const StatePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.framed = true,
  });

  /// Иконка состояния (например, [Icons.cloud_off_outlined]).
  final IconData icon;

  /// Короткий человеческий заголовок («Не получилось загрузить позиции»).
  final String title;

  /// Пояснение или подсказка, что делать.
  final String? message;

  /// Подпись кнопки действия (обычно «Обновить»).
  final String? actionLabel;

  /// Обработчик действия; вместе с [actionLabel] включает кнопку.
  final VoidCallback? onAction;

  /// Рисовать ли карточную рамку вокруг (для встраивания в список);
  /// false — голый центрированный контент (для целого экрана).
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 26, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(actionLabel!),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface,
              side: BorderSide(color: scheme.outline),
            ),
          ),
        ],
      ],
    );

    if (!framed) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(32), child: content),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
      ),
      child: content,
    );
  }
}
