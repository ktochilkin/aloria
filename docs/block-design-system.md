# Дизайн-система блоков уроков — план (handoff)

Статус: **план, код ещё не начат.** Эта фаза вынесена в отдельный диалог. Здесь — что и как делать.

## Контекст (где мы)

- Ветка: `lessons-interactive-experiments`.
- В витрине «Лаборатория блоков» (секция `lab`, урок `assets/lessons/lab/01-gallery.md`) — **44 интерактивных блока** после ревью пользователя.
- Реестр директив: `lib/features/learn/presentation/widgets/lesson_blocks.dart` (директива `:::имя` в md → виджет). Инфра уже есть.
- Оценки/заметки по блокам: `docs/block-verdicts.md`. Каталог идей: `docs/block-ideas.md`.
- Добавлены и обкатаны библиотеки: **fl_chart ^0.69.2** (графики) и **flutter_animate ^4.5.0** (анимация появления). Примеры перевода: `lesson_compound_growth.dart`, `lesson_charts_extra.dart`.
- Проблема, которую лечим: каждый блок свёрстан с нуля → разнобой отступов/типографики/слайдеров, графики частью руками. Цель — единый набор кирпичей и правил.

## Шаг 0 — выбрать визуальное направление (с пользователем)

Минимал/флэт (как сейчас) · премиум-финтех (тонкая глубина, воздух) · играбельный (Duolingo). Под выбранное строить токены.

## Шаг 1 — токены

Поверх `core/theme/tokens.dart` (AppColors, AppTypography): шкала отступов (4/8/12/16/24), радиусы (12/16), палитра графиков (accent + success/error + нейтраль), длительности/кривые анимаций (вход 350ms easeOutCubic, морфинг 700–900ms), правило accent-tint (приходит в блок как `tint`).

## Шаг 2 — примитивы `lib/features/learn/presentation/widgets/blocks/block_kit.dart`

- `LessonBlockCard({title?, subtitle?, footer?, child})` — единая обёртка (фон surfaceContainerHighest@0.4, радиус 16, рамка outlineVariant@0.5, паддинг 16). Все блоки оборачиваются.
- `BlockSlider({label, value, min, max, divisions?, onChanged})` — слайдер с инлайн-подписью значения и `HapticFeedback.selectionClick()`.
- `BlockButton` — обёртка над FilledButton (иконка+текст, full-width вариант).
- `BlockMetric({label, value, color?})` и `NumberAccent({value, label})` — число+подпись / крупное число.
- `BlockLegend(items: [(color, label)])` — строка-легенда.
- `BlockChip({text, tone: success|error|neutral})` — result-чип.
- `blockLineChart({bars, minY, maxY, bottomTitles?, animate})` → LineChartData в домашнем стиле (сетка outlineVariant@0.4, без рамки, isCurved, dotData off, опц. градиент, duration). Все линейные графики через неё.
- `Widget.blockEntrance()` — extension: `.animate().fadeIn(350.ms).slideY(begin:0.06, curve: easeOutCubic)`.

## Шаг 3 — док-контракт

Дописать сюда правила do/don't: какой отступ между элементами, какой вес/размер у заголовка блока и у числа, когда анимировать, как делать график (только через `blockLineChart`), как слайдер (только `BlockSlider`).

## Шаг 4 — раскатка

1. Перевести 2–3 эталона на block_kit (один график, один слайдер-сим, один gauge), показать на устройстве.
2. Прогнать остальные блоки агентами-строителями (паттерн уже отработан: пакетами по 5, строгий шаблон + block_kit в промпте). Заодно перевести оставшиеся линейные графики на fl_chart.
3. Каждую волну: `flutter analyze` зелёный, пересид (`rm aloria.db*` + dotnet run), сборка на iPhone по `.local`-адресу (см. reference в памяти).

## Инвентарь блоков (что куда)

- Линейные графики (→ fl_chart через blockLineChart): compound-growth✓, index-vs-fund✓, pnl-live(частично), compound-race, divgap-chart, drawdown(удалён), rate-reaction(rework), short-loss, diversification-dice.
- Слайдер-симы (→ BlockSlider): margin-call, ytm-dial, bond-yield-flip, rate-reaction, leverage-seesaw, allocation-pie, inflation-erosion, real-yield, eat-the-book, orderbook-2col, и др.
- Стакан/кастом (остаются на CustomPainter, но в LessonBlockCard): orderbook-2col, matching, book-vs-tape, treemap(удалён).
- Игры/чипы (→ BlockChip/BlockButton): scam-flags, scam-sorter, sort-by-risk, candle-anatomy, predict(удалён), if-then-rule, order-builder, order-status.

## Запуск/сборка (напоминание)

- Бэкенд уроков: `cd aloria-api/src/Aloria.Api && rm -f aloria.db* && dotnet run --urls http://0.0.0.0:5050` (пересид нужен только при изменении .md).
- iPhone: `flutter run --release -d <id> --dart-define=APP_ENV=dev --dart-define=ENABLE_LOGGING=true` (НЕ задавать ALORIA_API_URL — дефолтный `Noutbuk-Kirill.local:5050`; см. память). Беспроводная установка иногда флакает — повторить.
- Админка превью: `aloria-admin` на :5173 (vite), прокси `/api`→:5050.
