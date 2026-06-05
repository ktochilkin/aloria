import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Набор простых (нестейтовых) учебных блоков: врезки, крупное число,
/// карточки-сравнения, схема-поток, таймлайн. Все на демо-данных — это
/// кандидаты для встраивания в уроки, оформление можно параметризовать позже.

/// Три варианта врезки-выноски: пояснение, предупреждение, «в Aloria».
class LessonCalloutDemo extends StatelessWidget {
  const LessonCalloutDemo({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Callout(
          icon: Icons.lightbulb_outline,
          color: tint,
          title: 'Важно',
          text: 'Короткая мысль, которую нужно выделить из потока текста.',
        ),
        const SizedBox(height: 10),
        const _Callout(
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
          title: 'Осторожно',
          text: 'Предупреждение о риске или частой ошибке новичка.',
        ),
        const SizedBox(height: 10),
        const _Callout(
          icon: Icons.school_outlined,
          color: AppColors.success,
          title: 'В Aloria',
          text: 'Как это устроено в учебной среде: деньги учебные, рынок живой.',
        ),
      ],
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: t.bodySmall?.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Крупное выделенное число с подписью — выносит ключевую цифру из абзаца.
class LessonNumberAccent extends StatelessWidget {
  const LessonNumberAccent({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          Text(
            '70–90%',
            style: t.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: tint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'активных фондов проигрывают индексу на горизонте 5–10 лет',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Две карточки бок о бок для сравнения (демо: акция vs облигация).
class LessonCompareCards extends StatelessWidget {
  const LessonCompareCards({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(
            child: _CompareCard(
              accent: AppColors.success,
              title: 'Акция',
              subtitle: 'доля в бизнесе',
              rows: [
                ('Доход', 'рост цены + дивиденды'),
                ('Риск', 'выше'),
                ('Срок', 'бессрочно'),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CompareCard(
              accent: tint,
              title: 'Облигация',
              subtitle: 'долг компании',
              rows: const [
                ('Доход', 'купоны'),
                ('Риск', 'ниже'),
                ('Срок', 'до погашения'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  final Color accent;
  final String title;
  final String subtitle;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border(top: BorderSide(color: accent, width: 3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: t.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            subtitle,
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final r in rows) ...[
            Text(
              r.$1,
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text(
              r.$2,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Схема-поток: цепочка из боксов со стрелками (демо: ты → брокер → биржа).
class LessonFlowBroker extends StatelessWidget {
  const LessonFlowBroker({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Node(icon: Icons.person, label: 'Ты', color: tint),
          _Arrow(color: scheme.onSurfaceVariant),
          _Node(icon: Icons.account_balance_wallet, label: 'Брокер', color: tint),
          _Arrow(color: scheme.onSurfaceVariant),
          _Node(icon: Icons.account_balance, label: 'Биржа', color: tint),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.arrow_forward, size: 18, color: color);
  }
}

/// Горизонтальный таймлайн (демо: режим расчётов T → T+1).
class LessonTimelineTplus extends StatelessWidget {
  const LessonTimelineTplus({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              _Stop(
                color: tint,
                day: 'T',
                title: 'Сделка',
                sub: 'заявка исполнена',
              ),
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 26),
                  color: tint.withValues(alpha: 0.4),
                ),
              ),
              const _Stop(
                color: AppColors.success,
                day: 'T+1',
                title: 'Расчёт',
                sub: 'деньги свободны',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Между «сделка прошла» и «всё рассчитано» — один рабочий день.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.color,
    required this.day,
    required this.title,
    required this.sub,
  });

  final Color color;
  final String day;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            day,
            style: t.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(title, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
        Text(
          sub,
          style: t.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
