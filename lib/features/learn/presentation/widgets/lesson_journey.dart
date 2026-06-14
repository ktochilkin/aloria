import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Наглядная карта пути обучения для блока «Куда пойдём»: вертикальный
/// степпер. Первый шаг — «ты здесь», остальные — впереди. Чистый вектор,
/// без внешних картинок.
class LessonJourney extends StatelessWidget {
  const LessonJourney({super.key, required this.tint});

  final Color tint;

  /// (заголовок, пояснение) по порядку прохождения.
  static const _steps = <(String, String)>[
    ('Ты здесь', 'Освоиться и перестать бояться рынка'),
    ('Зачем вкладывать', 'Почему деньги в покое теряют ценность'),
    ('Риск и доходность', 'Как не лезть в риск вслепую'),
    ('Как устроена биржа', 'Где встречаются цена и сделка'),
    ('Первая сделка', 'Покупаешь прямо здесь и видишь результат'),
  ];

  @override
  Widget build(BuildContext context) {
    return LessonBlockCard(
      tint: tint,
      title: 'Куда пойдём',
      subtitle: 'Потихоньку, от простого к сложному.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _steps.length; i++)
            _Step(
              number: i,
              isFirst: i == 0,
              isLast: i == _steps.length - 1,
              title: _steps[i].$1,
              subtitle: _steps[i].$2,
              tint: tint,
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.isFirst,
    required this.isLast,
    required this.title,
    required this.subtitle,
    required this.tint,
  });

  final int number;
  final bool isFirst;
  final bool isLast;
  final String title;
  final String subtitle;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Колонка «узел + соединительная линия».
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFirst ? tint : Colors.transparent,
                  border: Border.all(
                    color: isFirst ? tint : tint.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: isFirst
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '$number',
                        style: text.labelSmall?.copyWith(
                          color: tint,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: tint.withValues(alpha: 0.22),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isFirst ? tint : scheme.onSurface,
                          ),
                        ),
                      ),
                      if (isFirst) ...[
                        const SizedBox(width: 6),
                        _NowTag(tint: tint),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NowTag extends StatelessWidget {
  const _NowTag({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'сейчас',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tint,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}
