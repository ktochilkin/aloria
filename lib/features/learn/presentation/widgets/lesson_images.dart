import 'package:flutter/material.dart';

/// Обложка урока: сетевая или ассетная картинка фиксированной высоты,
/// при ошибке загрузки — плашка с иконкой раздела в его акцентном цвете.
class LessonImage extends StatelessWidget {
  const LessonImage({
    super.key,
    required this.source,
    required this.fallbackTint,
    required this.fallbackIcon,
  });

  /// Путь к ассету или http(s)-URL.
  final String source;

  /// Акцент раздела — цвет фолбэк-плашки.
  final Color fallbackTint;

  /// Иконка раздела — содержимое фолбэк-плашки.
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRemote = source.startsWith('http');

    Widget fallback() => Container(
          height: 200,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fallbackTint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fallbackTint.withValues(alpha: 0.3)),
          ),
          child: Icon(fallbackIcon, color: fallbackTint, size: 36),
        );

    final image = isRemote
        ? Image.network(
            source,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          )
        : Image.asset(
            source,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200,
        color: scheme.surfaceContainerHighest,
        child: image,
      ),
    );
  }
}

/// Картинка внутри markdown-тела урока (ассет) со скруглением и
/// плашкой-заглушкой при ошибке загрузки.
class LessonMarkdownImage extends StatelessWidget {
  const LessonMarkdownImage({
    super.key,
    required this.uri,
    required this.alt,
    required this.fallbackTint,
  });

  /// URI ассета из markdown.
  final Uri uri;

  /// Альтернативный текст — показывается в заглушке.
  final String? alt;

  /// Акцент раздела (зарезервирован для оформления заглушки).
  final Color fallbackTint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          uri.toString(),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, _, _) => Container(
            height: 160,
            alignment: Alignment.center,
            color: scheme.surfaceContainerHighest,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported,
                    color: scheme.onSurfaceVariant),
                const SizedBox(height: 6),
                Text(
                  alt ?? 'Изображение не загружено',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
