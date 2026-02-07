import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LearningPage extends StatelessWidget {
  const LearningPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Обучение')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            sliver: SliverList.list(
              children: [
                _HeroCard(
                  title: 'Открой мир Aloria',
                  subtitle:
                      'Учебный рынок без риска: заявки, сделки, цены — всё как вживую, только безопасно.',
                  scheme: scheme,
                  body: _alloriaIntro,
                ),
                const SizedBox(height: 16),
                ...learningSections.map(
                  (section) => _SectionCard(section: section),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LearningSectionPage extends StatelessWidget {
  const LearningSectionPage({super.key, required this.section});

  final LearningSection section;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Назад',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/learn');
          },
        ),
        title: Text(section.title),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 1),
        itemCount: section.lessons.length,
        itemBuilder: (context, index) {
          final lesson = section.lessons[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/learn/${section.id}/${lesson.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LessonImage(
                      source: lesson.imageUrl,
                      height: 180,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      scheme: scheme,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lesson.title, style: text.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            lesson.description,
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.menu_book_outlined,
                                size: 18,
                                color: section.tint,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Открыть урок',
                                style: text.labelMedium?.copyWith(
                                  color: section.tint,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LessonPage extends StatelessWidget {
  const LessonPage({super.key, required this.section, required this.lesson});

  final LearningSection section;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    void popOrFallback() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/learn');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
        actions: [
          IconButton(
            onPressed: popOrFallback,
            icon: const Icon(Icons.close),
            tooltip: 'Закрыть',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _LessonImage(
            source: lesson.imageUrl,
            height: 220,
            borderRadius: BorderRadius.circular(16),
            scheme: scheme,
          ),
          const SizedBox(height: 16),
          Text(lesson.title, style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            lesson.description,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _DefinitionBlock(
            title: 'Академическое определение',
            content: lesson.academicDefinition,
            tint: section.tint,
          ),
          const SizedBox(height: 16),
          ...lesson.body.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(p, style: text.bodyMedium),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: popOrFallback,
            style: FilledButton.styleFrom(
              backgroundColor: section.tint,
              foregroundColor: AppColors.onPrimary,
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Понятно!'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: popOrFallback,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Вернуться к списку'),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.scheme,
    required this.body,
  });
  final String title;
  final String subtitle;
  final ColorScheme scheme;
  final List<String> body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showIntro(context, title, body, scheme),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              scheme.primary.withValues(alpha: 0.12),
              scheme.secondary.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Подробнее',
                    style: text.labelMedium?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.7),
                ),
              ),
              child: const Icon(
                Icons.emoji_events,
                size: 40,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});
  final LearningSection section;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/learn/${section.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: section.tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(section.icon, color: section.tint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title, style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      section.subtitle,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 18,
                          color: section.tint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${section.lessons.length} урок(ов)',
                          style: text.labelMedium?.copyWith(
                            color: section.tint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefinitionBlock extends StatelessWidget {
  const _DefinitionBlock({
    required this.title,
    required this.content,
    required this.tint,
  });

  final String title;
  final String content;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.school_outlined, color: tint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall?.copyWith(color: tint)),
                const SizedBox(height: 6),
                Text(content, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonImage extends StatelessWidget {
  const _LessonImage({
    required this.source,
    required this.height,
    required this.borderRadius,
    required this.scheme,
  });

  final String source;
  final double height;
  final BorderRadius borderRadius;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isRemote = source.startsWith('http');

    Widget fallbackContainer() => Container(
      height: height,
      color: scheme.surfaceContainerHighest,
      child: const Icon(Icons.image_not_supported),
    );

    final image = isRemote
        ? Image.network(
            source,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => fallbackContainer(),
          )
        : Image.asset(
            source,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => fallbackContainer(),
          );

    return ClipRRect(borderRadius: borderRadius, child: image);
  }
}

void _showIntro(
  BuildContext context,
  String title,
  List<String> body,
  ColorScheme scheme,
) {
  final text = Theme.of(context).textTheme;
  showModalBottomSheet(
    context: context,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.6,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ListView(
          controller: controller,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: text.titleMedium)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...body.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(p, style: text.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class LearningSection {
  const LearningSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.lessons,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final List<Lesson> lessons;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.academicDefinition,
    required this.imageUrl,
    required this.body,
  });

  final String id;
  final String title;
  final String description;
  final String academicDefinition;
  final String imageUrl;
  final List<String> body;
}

LearningSection? findSectionById(String id) {
  for (final section in learningSections) {
    if (section.id == id) return section;
  }
  return null;
}

Lesson? findLessonById(LearningSection section, String lessonId) {
  for (final lesson in section.lessons) {
    if (lesson.id == lessonId) return lesson;
  }
  return null;
}

const learningSections = <LearningSection>[
  LearningSection(
    id: 'trading-basics',
    title: 'Основы',
    subtitle: 'Как устроена биржа, заявки и первые шаги в стакане.',
    icon: Icons.flash_on,
    tint: AppColors.primary,
    lessons: [
      Lesson(
        id: 'orders',
        title: 'Что такое биржа?',
        description: 'Рынок покупок и продаж: как встречаются цена и сделка.',
        academicDefinition:
            'Биржа — это организованная торговая площадка, которая обеспечивает взаимодействие участников рынка и предоставляет инфраструктуру для заключения сделок с финансовыми инструментами по установленным правилам.',
        imageUrl: 'assets/images/lesson1_exchange.jpg',
        body: [
          'Представь обычный рынок: один человек продаёт, другой покупает. Продавец хочет дороже, покупатель — дешевле. Это нормальное напряжение спроса и предложения.',
          'Продавец может сказать: «Продам за 120». Покупатель отвечает: «Куплю только за 100». Пока цены не совпали, сделки нет — все просто продолжают искать варианты.',
          'Со временем появляются другие участники. Кто-то готов купить по 120, или продавец соглашается на 100, или обе стороны делают шаг навстречу. Когда цена устраивает обоих, появляется сделка — не потому что цена “правильная”, а потому что сошлись интересы.',
          'На бирже всё то же, только без разговоров: люди отправляют заявки с ценой и объёмом. Система сопоставляет эти заявки между собой.',
          'Как только находятся встречные заявки по одной цене, сделка происходит автоматически — иногда за доли секунды.',
          'Биржа не выбирает, кто прав, она лишь площадка, где заявки встречаются и превращаются в сделки.',
          'Именно этот процесс лежит в основе любого рынка — и реального, и мира Aloria. Здесь ты учишься понимать, как из множества разных желаний рождается одна конкретная цена.',
        ],
      ),
      Lesson(
        id: 'orderbook',
        title: 'Что такое заявка?',
        description: 'Лимитная и рыночная: ждать свою цену или брать сразу.',
        academicDefinition:
            'Заявка — это распоряжение участника торгов на покупку или продажу финансового инструмента, содержащее условия сделки, включая цену и объём, и направляемое в торговую систему биржи.',
        imageUrl: 'assets/images/lesson2_order.jpg',
        body: [
          'Продавец выходит и говорит: «Продам за 120». Он назвал цену и не готов дешевле — это лимитная заявка: четкое условие сделки.',
          'Покупатель отвечает: «Куплю за 100». Это другая лимитная заявка. Цены не совпали — сделки нет, рынок просто ждет совпадения.',
          'Лимитные заявки говорят рынку: «Готов купить/продать, но только по этой цене». Сделка случится, когда появится встречная заявка с такой же ценой.',
          'Иногда кто-то не хочет ждать: «Хочу купить прямо сейчас, по любой лучшей цене». Это рыночная заявка — согласие на текущие условия рынка.',
          'То же может сделать продавец: продать немедленно по лучшей доступной цене. Рыночная заявка почти всегда исполняется сразу.',
          'Лимитная — контроль цены и ожидание. Рыночная — скорость исполнения. На любом рынке, в том числе в Aloria, сделки появляются именно из этого выбора.',
        ],
      ),
      Lesson(
        id: 'margin',
        title: 'Что такое сделка?',
        description: 'Момент совпадения заявок: цена устроила обе стороны.',
        academicDefinition:
            'Сделка — это результат исполнения заявок, при котором между покупателем и продавцом возникает обязательство по передаче финансового инструмента и денежных средств на согласованных условиях.',
        imageUrl: 'assets/images/lesson3_trade.jpg',
        body: [
          'Сделка — это момент, когда рынок перестаёт обсуждать и начинает действовать: заявки совпали по цене и объёму.',
          'Продавец выставил лимитную заявку «Продам за 120». Сделки нет, пока никто не готов купить за эту цену.',
          'Появляется покупатель, который соглашается на 120, или отправляет рыночную заявку и берёт лучшую доступную цену. Заявки совпадают — сделка случается.',
          'Сделка — не обещание и не желание, а свершившийся факт: товар у покупателя, деньги у продавца, рынок фиксирует результат.',
          'Рынок не оценивает, была ли цена «выгодной». Он лишь фиксирует, что две стороны договорились.',
          'В Aloria каждая сделка — результат твоего выбора: ждать свою цену лимитной заявкой или действовать сразу рыночной. Ошибки — часть обучения, а осознанные сделки учат понимать рынок.',
        ],
      ),
      Lesson(
        id: 'position',
        title: 'Что такое позиция?',
        description: 'Результат сделок: сколько и чего у тебя есть сейчас.',
        academicDefinition:
            'Позиция — это текущее количество финансового инструмента, находящееся у участника торгов в результате совершённых сделок, с указанием объёма, средней цены и направления (длинная или короткая).',
        imageUrl: 'assets/images/lesson4_position.jpg',
        body: [
          'Пока есть только заявки — ничего не произошло. Ты выразил намерение, но рынок на него ещё не ответил.',
          'Когда заявка исполняется и появляется сделка, возникает результат. Этот результат и называется позицией.',
          'Проще говоря, позиция — это ответ на вопрос: «Что у меня есть прямо сейчас?»',
          'Если ты купил 10 акций — у тебя позиция +10. Если продал 5 из них — позиция стала +5. Если продал больше, чем было, — позиция может стать отрицательной.',
          'Позиция — это не прошлое и не планы. Это текущее состояние твоего портфеля в данный момент времени.',
          'Она формируется автоматически из сделок. Биржа не думает о твоих целях или стратегии — она просто считает результат.',
          'Важно понимать: позиция меняется только сделками. Выставление или отмена заявок на неё не влияет.',
          'В интерфейсе Aloria позиция показывает, какие инструменты у тебя есть, в каком количестве и по какой средней цене они появились.',
          'Дальше ты будешь учиться читать позицию и понимать, как твои действия в стакане и через заявки постепенно превращаются в конкретный результат.',
        ],
      ),
      Lesson(
        id: 'orderbook_view',
        title: 'Что такое стакан?',
        description:
            'Где видно, по каким ценам рынок готов покупать и продавать.',
        academicDefinition:
            'Стакан — это отображение активных заявок на покупку и продажу финансового инструмента, сгруппированных по ценам и объёмам, показывающее текущий баланс спроса и предложения.',
        imageUrl: 'assets/images/lesson5_orderbook.jpg',
        body: [
          'Когда ты отправляешь заявку, она не исчезает и не теряется. Она попадает в общее пространство рынка.',
          'Стакан показывает все активные заявки, которые сейчас ждут исполнения. Кто хочет купить, по какой цене и в каком количестве. И кто хочет продать на каких условиях.',
          'Обычно стакан разделён на две части. С одной стороны заявки на покупку. С другой заявки на продажу.',
          'В каждой строке указана цена и объём. Цена показывает, по какой стоимости участник готов совершить сделку. Объём показывает, сколько инструмента он хочет купить или продать.',
          'Самые близкие цены друг к другу находятся в центре стакана. Здесь рынок ближе всего к сделке.',
          'Если появляется рыночная заявка, она сразу исполняется по ближайшим ценам из стакана. Именно поэтому стакан определяет, по какой цене совершается сделка.',
          'Стакан не предсказывает будущее и не подсказывает, куда пойдёт цена. Он лишь показывает текущие намерения участников.',
          'Каждая новая заявка может изменить картину. Кто то добавил объём. Кто то убрал свою заявку. Баланс постоянно меняется.',
          'Когда ты смотришь на стакан, ты видишь рынок в настоящем моменте. Не историю и не ожидания, а текущий спрос и предложение.',
          'В Aloria стакан работает так же, как на реальной бирже. Из него рождается цена, сделки и в итоге твоя позиция.',
        ],
      ),
      Lesson(
        id: 'chart_basics',
        title: 'Что такое график?',
        description:
            'Как рынок выглядит во времени и что на самом деле показывает цена.',
        academicDefinition:
            'График — это визуальное представление изменения цены финансового инструмента во времени, построенное на основе совершённых сделок.',
        imageUrl: 'assets/images/lesson6_chart.jpg',
        body: [
          'Когда сделки происходят одна за другой, рынок оставляет след. Этот след и есть график.',
          'График не показывает намерения и ожидания участников. Он фиксирует только то, что уже произошло.',
          'Каждая точка на графике отражает цену сделки в определённый момент времени.',
          'Если сделки проходят всё дороже, линия на графике поднимается. Если дешевле, опускается.',
          'Важно понимать, что график не управляет рынком. Он лишь отражает результат действий покупателей и продавцов.',
          'Смотря на график, легко забыть, что за каждым движением цены стоят конкретные сделки и конкретные решения.',
          'График удобен тем, что позволяет увидеть рынок не в одном моменте, а в развитии. Как цена менялась и как быстро это происходило.',
          'Один и тот же рынок может выглядеть по разному в зависимости от масштаба времени.',
          'На коротком промежутке цена может сильно колебаться. На длинном выглядеть более плавно.',
          'Поэтому график всегда нужно воспринимать как способ взгляда на рынок, а не как его объяснение.',
        ],
      ),
      Lesson(
        id: 'candles_timeframes',
        title: 'Японские свечи и время',
        description: 'Как читать движение цены за выбранный период.',
        academicDefinition:
            'Японская свеча — это форма отображения ценового движения за заданный интервал времени, показывающая цену открытия, закрытия, максимальное и минимальное значение.',
        imageUrl: 'assets/images/lesson7_candles.jpg',
        body: [
          'Чаще всего график показывают не одной линией, а отдельными отрезками времени. Эти отрезки называют свечами.',
          'Каждая свеча описывает, что происходило с ценой за выбранный промежуток времени.',
          'У свечи есть начало и конец. Цена в начале периода называется ценой открытия. Цена в конце ценой закрытия.',
          'Также у свечи есть верхняя и нижняя граница. Они показывают максимальную и минимальную цену сделок за этот период.',
          'Если цена закрытия выше цены открытия, свеча выглядит как рост. Если ниже, как снижение.',
          'Размер свечи показывает, насколько активно менялась цена за это время.',
          'Время, которое описывает одна свеча, называют таймфреймом.',
          'Свеча может отражать одну минуту, один час, один день или любой другой интервал.',
          'Один и тот же рынок будет выглядеть по разному на разных таймфреймах, хотя сделки одни и те же.',
          'Меняя масштаб времени, ты не меняешь рынок. Ты лишь выбираешь, на каком уровне детализации на него смотреть.',
        ],
      ),
      Lesson(
        id: 'market_observation',
        title: 'Наблюдение за рынком',
        description: 'Как действия отражаются в заявках, сделках и позиции.',
        academicDefinition:
            'Наблюдение рынка — это анализ текущего состояния торгов через интерфейс, включая заявки, сделки, цену и позицию, без изменения торговых условий.',
        imageUrl: 'assets/images/lesson8_market_overview.jpg',
        body: [
          'Открой обзор рынка и выбери любой инструмент. Не важно какой именно.',
          'Сначала ничего не делай. Просто посмотри на цену, стакан и график.',
          'Обрати внимание, что цена на графике и цены в стакане связаны между собой. График показывает прошлые сделки, стакан текущие заявки.',
          'Теперь попробуй выставить заявку на покупку по цене ниже текущей.',
          'Заявка появится в стакане. Сделки не произойдёт. Позиция не изменится.',
          'Ты увидишь, что рынок знает о твоём намерении, но не обязан на него отвечать.',
          'Отмени заявку. Она исчезнет из стакана. Ничего больше не изменится.',
          'Теперь попробуй купить по текущей цене.',
          'Появится сделка. Изменится позиция. Цена на графике может сдвинуться.',
          'Попробуй продать часть купленного инструмента.',
          'Посмотри, как это отразится в списке заявок, в сделках и в позиции.',
          'Здесь нет правильных или неправильных действий. Есть только связь между решением и результатом.',
          'Рынок не объясняет, что произошло. Он просто показывает последствия.',
        ],
      ),
    ],
  ),
  LearningSection(
    id: 'investing-basics',
    title: 'Основы инвестиций',
    subtitle: 'Долгосрочные стратегии, дивиденды и спокойный сон.',
    icon: Icons.park,
    tint: AppColors.success,
    lessons: [
      Lesson(
        id: 'dividends',
        title: 'Дивидендные стратегии',
        description: 'Доход от дивидендов, даты отсечек и налоговые нюансы.',
        academicDefinition:
            'Дивиденды — это часть прибыли акционерного общества, распределяемая между акционерами пропорционально количеству их акций в соответствии с решением общего собрания.',
        imageUrl:
            'https://images.unsplash.com/photo-1508387024700-9fe5c0b37f79?auto=format&fit=crop&w=900&q=80',
        body: [
          'Дивиденды выплачиваются по итогам собрания акционеров. Важно знать дату закрытия реестра, чтобы попасть под выплату.',
          'Дивидендные «якоря» поддерживают цену, но после отсечки возможен технический гэп вниз.',
          'Сравнивайте дивдоходность с риском и стабильностью бизнеса, а не только с текущей ценой.',
        ],
      ),
      Lesson(
        id: 'portfolio',
        title: 'Долгосрочный портфель',
        description: 'Диверсификация, ребаланс и выбор долей.',
        academicDefinition:
            'Инвестиционный портфель — совокупность финансовых инструментов, сформированная инвестором для достижения заданных целей с учётом допустимого уровня риска и необходимой доходности.',
        imageUrl:
            'https://images.unsplash.com/photo-1508387024700-9fe5c0b37f79?auto=format&fit=crop&w=900&q=80&sat=-50',
        body: [
          'Разделяйте капитал по секторам и валютам, чтобы снизить влияние одного события на весь портфель.',
          'Ребалансируйте по календарю или порогу отклонения долей, возвращая риск-профиль к целевому.',
          'Избегайте концентрации в одной идее — даже качественные компании переживают просадки.',
        ],
      ),
      Lesson(
        id: 'etf',
        title: 'ETF и индексы',
        description: 'Пассивное инвестирование и что внутри фонда.',
        academicDefinition:
            'ETF (exchange-traded fund) — биржевой инвестиционный фонд, доли которого обращаются на бирже и который стремится повторять структуру и динамику базового индекса или корзины активов.',
        imageUrl:
            'https://images.unsplash.com/photo-1504615755583-2916b52192dc?auto=format&fit=crop&w=900&q=80',
        body: [
          'ETF позволяют купить корзину активов одной сделкой. Смотрите на комиссию фонда и трекинг ошибки.',
          'Индексные стратегии снижают риск выбора отдельных бумаг, но зависят от динамики всего рынка.',
          'Уточняйте валюту фонда и налоговые условия по дивидендам внутри ETF.',
        ],
      ),
    ],
  ),
];

const _alloriaIntro = <String>[
  'Добро пожаловать в Aloria.',
  'Aloria — это вымышленный экономический мир, созданный для обучения торговле и инвестиционному мышлению без риска потерять реальные деньги.',
  'Здесь всё устроено как на настоящем рынке: есть заявки, сделки, цены и изменения спроса. Но вместо реальных денег используется внутренняя валюта, которая отражает твой уровень подготовки и ответственности.',
  'В Aloria ты сначала изучаешь, как работает рынок, а затем применяешь знания на практике. Ошибки здесь — часть обучения, а не повод для потерь.',
  'Обучение и торговля — это два разных режима, связанных между собой. Чем лучше ты понимаешь принципы рынка, тем больше возможностей открывается.',
  'Aloria — это безопасное место, чтобы: разобраться, как работают биржи и инструменты; научиться принимать решения и управлять риском; подготовиться к реальной торговле шаг за шагом.',
  'Начни с обучения — и постепенно открой для себя весь мир Aloria.',
];
