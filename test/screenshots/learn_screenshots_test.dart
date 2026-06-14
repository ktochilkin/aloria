import 'package:aloria/core/theme/app_theme.dart';
import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/application/review_providers.dart';
import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:aloria/features/learn/presentation/learning_index_page.dart';
import 'package:aloria/features/learn/presentation/learning_section_page.dart';
import 'package:aloria/features/learn/presentation/lesson_page.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_markdown_body.dart';
import 'package:aloria/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shot_kit.dart';

/// Скриншот-харнесс страниц обучения: дорожка этапов, список уроков,
/// страница урока с интерактивным блоком. Все данные — фикстуры.
/// Запуск: flutter test test/screenshots/learn_screenshots_test.dart

const _outDir = 'build/learn_shots';
const _phone = Size(430, 932);

// ── Фикстуры ────────────────────────────────────────────────────────────────

Lesson _lesson(
  String id,
  String title, {
  String? group,
  int minutes = 4,
  String body = '',
  String? recallPrompt,
  String? recallAnswer,
}) =>
    Lesson(
      id: id,
      title: title,
      description: 'Короткое описание урока для дорожки.',
      academicDefinition: '',
      imageUrl: '',
      body: body,
      estimatedMinutes: minutes,
      group: group,
      recallPrompt: recallPrompt,
      recallAnswer: recallAnswer,
      serverId: recallPrompt == null ? null : 'fixture-42',
    );

final _whyMarket = LearningSection(
  id: 'why-market',
  title: 'С чего начать',
  subtitle: 'Зачем вообще инвестировать и как не попасть в обман на старте.',
  icon: Icons.lightbulb_outline,
  tint: AppColors.accentBlue,
  goal:
      'Понять, что деньги в покое теряют ценность, и какие риски ждут на входе.',
  targetMinutes: 22,
  status: LearningStageStatus.completed,
  lessonsTotal: 5,
  lessonsCompleted: 5,
  lessons: [
    _lesson('welcome', 'Добро пожаловать', group: 'Старт'),
    _lesson('why_invest', 'Зачем инвестировать', group: 'Старт'),
    _lesson('inflation', 'Инфляция', group: 'Доходность'),
    _lesson('compound_interest', 'Сложный процент и время',
        group: 'Доходность', minutes: 6),
    _lesson('scam_safety', 'Мошенничество и пирамиды', group: 'Стратегия'),
  ],
);

final _basics = LearningSection(
  id: 'basics',
  title: 'Основы инвестиций',
  subtitle: 'Риск, ликвидность, доходность — три оси любой инвестиции.',
  icon: Icons.balance,
  tint: AppColors.accentBlue,
  goal: 'Разобрать базовый каркас оценки инвестиции.',
  targetMinutes: 22,
  status: LearningStageStatus.inProgress,
  lessonsTotal: 5,
  lessonsCompleted: 2,
  lessons: [
    _lesson('three_params', 'Три вопроса к инвестиции', group: 'Основы'),
    _lesson('risk_basics', 'Что такое риск и доходность', group: 'Риск',
        minutes: 5),
    _lesson('risk_types', 'Какие бывают риски', group: 'Риск', minutes: 5,
        body: _riskBody,
        recallPrompt:
            'Ты держишь акцию небольшой редкой компании. Какие минимум два вида риска тут особенно заметны?',
        recallAnswer:
            'Рыночный (цена сильно ходит) и ликвидности (трудно выйти, не уступив в цене).'),
    _lesson('liquidity', 'Ликвидность', group: 'Ликвидность'),
    _lesson('yield', 'Что такое доходность', group: 'Доходность', minutes: 5),
  ],
);

final _firstTrade = LearningSection(
  id: 'first-trade',
  title: 'Как устроены торги',
  subtitle: 'Совершить первую сделку и понять, что произошло на счёте.',
  icon: Icons.rocket_launch,
  tint: AppColors.accentBlue,
  goal: 'Совершить первую безопасную сделку.',
  targetMinutes: 18,
  lessonsTotal: 5,
  lessons: [
    _lesson('exchange', 'Что такое биржа'),
    _lesson('order_basics', 'Что такое заявка'),
    _lesson('first_trade', 'Первая сделка'),
    _lesson('position', 'Что такое позиция'),
    _lesson('pnl', 'Что значит «в плюсе»'),
  ],
);

const _riskBody = '''
Раньше мы говорили про риск в общем: будущее неизвестно, поэтому результат может разойтись с ожиданиями. Но «риск» — это не одна штука. У него несколько лиц, и пугают они по-разному.

## Рыночный риск

Самый знакомый. Цена ходит вверх-вниз вслед за настроением рынка, новостями, ставками. Даже у крепкой компании акция может просесть просто потому, что сегодня падает весь рынок. **Спрятаться от него полностью нельзя.**

Проверь интуицию — расставь инструменты по уровню риска:

:::sort-by-risk

## Кредитный риск

**Риск, что тот, кому ты дал денег, их не вернёт.** Особенно важен для облигаций: покупая их, ты по сути одалживаешь компании или государству.

> Смысл не в том, чтобы найти «безрисковый» вариант — его нет.
''';

final _sections = [_whyMarket, _basics, _firstTrade];

/// Фейковый API-клиент: страница урока дёргает markLessonComplete и
/// fetchConcept — в скриншотах сеть не нужна.
class _FakeLearningApi implements LearningApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.value();
}

List<Override> _learnOverrides() => [
      learningSectionsProvider.overrideWith((ref) => Future.value(_sections)),
      dueReviewsProvider
          .overrideWith((ref) => Future.value(const <DueReview>[])),
      learningIntroProvider
          .overrideWith((ref) => Future.value('Добро пожаловать!')),
      conceptsCatalogProvider.overrideWith(
        (ref) => Future.value(const <String, Map<String, dynamic>>{}),
      ),
      lessonBodiesPrewarmProvider.overrideWith((ref) {}),
      learningProgressSyncProvider.overrideWith((ref) {}),
      learningApiClientProvider.overrideWithValue(_FakeLearningApi()),
    ];

Widget _app(Widget home) => ProviderScope(
      overrides: _learnOverrides(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget home, {
  double height = 932,
  Future<void> Function(WidgetTester)? act,
}) async {
  await tester.binding.setSurfaceSize(Size(_phone.width, height));
  tester.view.devicePixelRatio = 1.0;
  const key = ValueKey('screen-boundary');
  await tester.pumpWidget(RepaintBoundary(key: key, child: _app(home)));
  // Много мелких кадров: входные анимации блоков стартуют пост-фреймом,
  // и одиночный длинный pump их не проигрывает.
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
  if (act != null) {
    await act(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }
  await snapKey(tester, key, '$_outDir/$name.png');
  await tester.binding.setSurfaceSize(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadShotFonts();
  });

  testWidgets('обучение — дорожка этапов', (tester) async {
    await _shoot(tester, 'learn_index', const LearningPage(),
        height: 1400);
  });

  testWidgets('обучение — список уроков этапа', (tester) async {
    await _shoot(
      tester,
      'learn_section',
      const LearningSectionPage(sectionId: 'basics'),
      height: 1400,
    );
  });

  testWidgets('обучение — страница урока с блоком', (tester) async {
    await _shoot(
      tester,
      'lesson_page',
      const LessonPage(sectionId: 'basics', lessonId: 'risk_types'),
      height: 2400,
    );
  });

  testWidgets('обучение — лид-врезка', (tester) async {
    await _shoot(
      tester,
      'lesson_lead',
      Scaffold(
        backgroundColor: AppTheme.light.scaffoldBackgroundColor,
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: LessonMarkdownBody(
            body: ':::lead\n'
                'Открывал когда-нибудь приложение брокера — и почти сразу '
                'закрывал? Графики ползут, мигают красные и зелёные числа, '
                'всюду «заявки» и «стаканы». Со стороны биржа и правда похожа '
                'на кабину самолёта, где лучше ничего не трогать.\n\n'
                'Если узнал себя — ты не один такой.\n'
                ':::\n\n'
                'Aloria для этого и придумана. И сразу главное: внутри '
                'работает **тот же торговый движок, что и у настоящего '
                'брокера**, — просто на учебной бирже и без реальных денег.',
            tint: AppColors.primary,
          ),
        ),
      ),
      height: 600,
    );
  });
}
