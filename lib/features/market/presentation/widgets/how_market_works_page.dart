import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Открывает экран-объяснение «Как устроен рынок Aloria».
void openHowMarketWorks(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const HowMarketWorksPage()));
}

/// Рамка для понимания мира: настоящий движок, события + участники, новость как
/// сигнал, сжатое время, разная реакция секторов. Тон — учебный, без советов.
class HowMarketWorksPage extends StatelessWidget {
  const HowMarketWorksPage({super.key});

  static const _blocks = <({IconData icon, String title, String body})>[
    (
      icon: Icons.hub_outlined,
      title: 'Настоящий рынок',
      body:
          'Aloria работает на реальном биржевом движке: заявки учеников и '
          'маркетмейкера встречаются в одном стакане. Это не нарисованный график.',
    ),
    (
      icon: Icons.bolt_outlined,
      title: 'Цену двигают события и люди',
      body:
          'Цена меняется и от макрособытий с новостями, и от реальных заявок '
          'участников. Поэтому рынок непредсказуем — как настоящий.',
    ),
    (
      icon: Icons.lightbulb_outline,
      title: 'Новость — сигнал, не гарантия',
      body:
          'Рынок реагирует на ожидания. Если хорошая новость уже «в цене», она '
          'может и не поднять её — а иногда даже опустить.',
    ),
    (
      icon: Icons.schedule_outlined,
      title: 'Время сжато',
      body:
          'Экономический цикл ≈ 10 дней = условный «год». Дивиденды и купоны '
          'видно быстро, а не через кварталы.',
    ),
    (
      icon: Icons.donut_large_outlined,
      title: 'Секторы реагируют по-разному',
      body:
          'Один и тот же сдвиг — например, ставка вверх — для одних секторов '
          'плюс, для других минус. Единого правила «всё растёт/падает» нет.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Как устроен рынок Aloria')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          for (final b in _blocks)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(b.icon, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            b.title,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          b.body,
                          style: text.bodyMedium?.copyWith(height: 1.4),
                        ),
                      ],
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
