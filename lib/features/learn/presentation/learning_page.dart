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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: section.lessons.length,
        itemBuilder: (context, index) {
          final lesson = section.lessons[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/learn/${section.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
            errorBuilder: (_, __, ___) => fallbackContainer(),
          )
        : Image.asset(
            source,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallbackContainer(),
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
        title: 'Что такое заявка',
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
        title: 'Что такое сделка',
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
