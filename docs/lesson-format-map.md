# Карта форматов уроков Aloria

Цель: уйти от «голого markdown» (заголовок → абзац → blockquote → квиз в конце) к набору переиспользуемых визуальных/интерактивных блоков, вплетённых в текст. Источник — анализ всех 46 уроков (по агенту на этап, маппинг к общему каталогу блоков).

## Каталог блоков

| Код | Что | Реюз торговли |
|---|---|---|
| `callout` | врезка-выноска (info / warning / «а в Aloria это так») | — |
| `number-accent` | крупное выделенное число с подписью | — |
| `data-table` | таблица данных (сравнение, ряд значений) | — |
| `mini-chart` | мини-график линией (рост во времени / движение цены), mock-данные, анимация | ✅ график |
| `mini-orderbook` | встроенный мини-стакан на mock-данных, анимация съедания заявок | ✅ стакан |
| `seesaw` | анимация обратной связи / двух сторон (ставка↔цена, риск вверх/вниз) | частично |
| `range-fork` | визуальная вилка диапазона исходов (шире/уже разброс) | — |
| `diagram-flow` | схема-поток/цепочка (ты → брокер → биржа; денежный поток) | — |
| `compare-cards` | 2–3 карточки бок о бок для сравнения | — |
| `mid-checkpoint` | интерактив в середине урока (tap-to-reveal, выбор) | — |
| `try-live` | блок «попробуй на живом рынке»: дип-линк в симулятор с действием | ✅ движок |
| `timeline` | горизонтальная шкала событий/дат (T+1, купоны, отсечка, сессии) | — |

## Охват (по всем 46 урокам)

| Блок | Primary | Всего (с secondary) |
|---|---|---|
| mini-chart | 12 | 15 |
| seesaw | 7 | 7 |
| mini-orderbook | 6 | 7 |
| compare-cards | 4 | 11 |
| try-live | 3 | 6 |
| mid-checkpoint | 3 | 6 |
| number-accent | 3 | 9 |
| diagram-flow | 3 | 6 |
| timeline | 3 | 4 |
| range-fork | 2 | 4 |
| callout | 0 | 12 |
| data-table | 0 | 5 |

**Вывод:** 12 компонентов закрывают весь курс. `mini-chart` + `mini-orderbook` (оба реюз торговли) — primary в 18 из 46 уроков (~40%). `try-live` как primary в 3, но `liveEngineOpportunity` отмечена в ~20 уроках — это стандартный футер-блок для инструментальных уроков, главный дифференциатор Aloria (за уроком настоящий движок).

## Порядок постройки (ROI)

- **Тир 0 — инфра:** механизм «директива в markdown → Flutter-виджет» в `lesson_page.dart` (расширить кастомный билдер `MarkdownBody`, уже используемый для concept-ссылок). Без неё блоки не вставить.
- **Тир 1 — тривиально + охват:** `callout` (12), `number-accent` (9). Чистая верстка.
- **Тир 2 — козырь:** `mini-chart` (18), `mini-orderbook` (7). Реюз торговых виджетов на mock-данных. Начать с mini-chart.
- **Тир 3 — одна анимация на 7 уроков:** `seesaw`.
- **Тир 4 — добивка:** `compare-cards`, `mid-checkpoint`, `diagram-flow`, `timeline`, `range-fork`, `data-table`.

## Пилоты первой очереди (boring 4–5 + реюз торговли)

- `compound_interest` — ряд 1000 → 17 449 за 30 лет в анимированную кривую (загиб вверх).
- `liquidity` — два стакана бок о бок: «телефон» (плотный, узкий спред) vs «гараж» (дыры, широкий спред); анимация продажи.
- `orderbook` / `spread` — живой мини-стакан со съеданием заявок, подсветка спреда.
- `bonds_price` — качели «ключевая ставка ↔ цена облигации».
- `pnl` — линия цены покупки + скачущая рыночная цена, зелёная/красная зона = бумажный P&L.

## Полная карта по урокам

Каждый урок: primary-блок / secondary / boringness (1 живой … 5 стена текста) / реюз торговли / live-возможность.

### why-market
- **01-welcome** — try-live / callout · b2 · реюз✅ · дип-линк «зайди в рынок и купи что-нибудь прямо сейчас».
- **02-why_invest** — seesaw / callout · b4 · деньги в покое (тают) vs в работе (колеблются), у обоих минус.
- **03-inflation** — mini-chart / number-accent · b4 · реюз✅ · убывающая покупательная способность по годам.
- **04-compound_interest** — mini-chart / number-accent · b3 · реюз✅ · ряд 1000→17449, ×17 vs ожидаемых ×4.
- **05-scam** — mid-checkpoint / callout · b4 · «красный флаг или нет?» tap-to-reveal на реальных предложениях.

### basics
- **01-three_params** — compare-cards / callout · b2 · три карточки Риск/Ликвидность/Доходность.
- **02-risk** — range-fork / mini-chart · b4 · реюз✅ · слайдер «больше риска» раздвигает вилку в обе стороны.
- **03-risk_types** — compare-cards / number-accent · b5 · 6 видов риска в карточки-фишки вместо стены.
- **04-liquidity** — mini-orderbook / compare-cards · b3 · реюз✅ · два стакана «телефон vs гараж».
- **05-yield** — mid-checkpoint / data-table · b4 · «30% — много или мало?» за день/год/10 лет.

### first-trade
- **01-exchange** — mini-orderbook / diagram-flow · b3 · реюз✅ · схлопывание встречных заявок в сделку.
- **02-order_basics** — mini-orderbook / data-table · b4 · реюз✅ · рыночная бьёт встречную vs лимитная ждёт в очереди.
- **03-first_trade** — try-live / callout · b2 · большой дип-линк «купи небольшой объём по рынку».
- **04-position** — seesaw / callout · b3 · чаши «Рубли ↔ Бумага», сумма сохраняется.
- **05-pnl** — mini-chart / number-accent · b4 · реюз✅ · цена покупки + скачущая цена, зелёная/красная зона.

### reading-market
- **01-session** — timeline / callout · b4 · шкала суток MOEX с сегментами сессий.
- **02-orderbook** — mini-orderbook / try-live · b3 · реюз✅ · живой стакан со съеданием.
- **03-spread** — mini-orderbook / try-live · b3 · реюз✅ · подсветка спреда, ликвидный/неликвидный переключатель.
- **04-chart** — mini-chart / callout · b3 · реюз✅ · те же данные на коротком (шум) и длинном (тренд) таймфрейме.
- **05-candles** — mini-chart / mid-checkpoint · b3 · реюз✅ · анатомия свечи tap-to-reveal (OHLC).
- **06-observation** — try-live / diagram-flow · b2 · реюз✅ · чек-лист действий в живом рынке (финал этапа).

### stocks
- **01-stock_market** — diagram-flow / mini-orderbook · b3 · эмитенты → инструменты → инвесторы.
- **02-stock** — number-accent / mid-checkpoint · b2 · «1 / 1000 — твоя доля».
- **03-stock_behavior** — mini-chart / compare-cards · b3 · реюз✅ · спокойная фишка vs дёрганая малая компания.
- **04-dividends** — mini-chart / timeline · b3 · реюз✅ · анимация дивидендного гэпа.

### bonds
- **01-bonds** — diagram-flow / compare-cards · b3 · анатомия облигации: срок, купонные стрелки, погашение.
- **02-bonds_trading** — mini-orderbook / number-accent · b3 · реюз✅ · стакан в %, пересчёт 98.5 → 985 ₽.
- **03-bonds_price** — seesaw / mini-chart · b3 · реюз✅ · ставка вверх → цена вниз.
- **04-bonds_yield** — timeline / data-table · b4 · шкала купонного периода, накопление НКД.
- **05-bonds_types** — range-fork / compare-cards · b4 · вилка надёжность ↔ доходность по рейтингам.

### funds
- **01-funds** — diagram-flow / callout · b3 · 1 пай разворачивается в корзину бумаг.
- **02-fund_types** — compare-cards / data-table · b4 · карточки фондов акций/облигаций/металлов.
- **03-fund_index** — mini-chart / diagram-flow · b3 · реюз✅ · линия индекса и линия пая слипаются.
- **04-fund_active** — number-accent / compare-cards · b3 · «70–90% активных проигрывают индексу».
- **05-fund_select** — mini-chart / mid-checkpoint · b3 · реюз✅ · веер расхождения по TER (0,5% vs 1,2%).
- **06-metals** — mini-chart / callout · b2 · реюз✅ · золото идёт иначе, чем акции.

### portfolio
- **01-diversification** — seesaw / compare-cards · b3 · реюз✅ · акции вниз, облигации/золото держат, портфель проседает меньше.
- **02-risk_profile** — mid-checkpoint / range-fork · b4 · «увидишь −30%, что сделаешь?» → подходящая доля спокойной части.
- **03-psychology** — seesaw / callout · b4 · реюз✅ · жадность у вершины, страх у дна.
- **04-rebalancing** — mini-chart / data-table · b3 · реюз✅ · дрейф долей 60/40 → 70/30 и возврат.
- **05-taxes** — number-accent / compare-cards · b4 · пошаговый расчёт налога и сальдирования.

### active-trading
- **01-short** — seesaw / mini-chart · b3 · реюз✅ · асимметрия: прибыль в пол, убыток без потолка.
- **02-margin** — seesaw / number-accent · b4 · слайдер плеча, обе стрелки растут синхронно.
- **03-stop_orders** — mini-chart / try-live · b3 · реюз✅ · стоп при плавном заходе vs гэп перепрыгивает уровень.
- **04-settlement** — timeline / callout · b3 · шкала T → T+1, рабочие дни (пятница → понедельник).
- **05-derivatives** — compare-cards / range-fork · b4 · фьючерс (обязан) vs опцион (право, премия).
