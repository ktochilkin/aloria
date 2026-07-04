namespace Aloria.Director.Core.Model;

/// <summary>Сектор экономики Алории и его чувствительности к макрофакторам.</summary>
/// <param name="Slug">Ключ (совпадает с aloria-api).</param>
/// <param name="Title">Название для новостей/лора.</param>
/// <param name="BetaGrowth">Чувствительность к росту экономики.</param>
/// <param name="BetaRate">Чувствительность к ключевой ставке (финансам ставка в плюс).</param>
/// <param name="BetaInflation">Чувствительность к инфляции (энергетике инфляция в плюс).</param>
/// <param name="SigmaDaily">Собственная дневная волатильность сектора (лог).</param>
/// <param name="Description">Описание сектора для справочника (лор, вход LLM).</param>
public sealed record SectorSpec(
    string Slug,
    string Title,
    double BetaGrowth,
    double BetaRate,
    double BetaInflation,
    double SigmaDaily,
    string Description);

/// <summary>Компания-эмитент.</summary>
/// <param name="Symbol">Тикер акции (≤20 символов, TEREX).</param>
/// <param name="Name">Название.</param>
/// <param name="Theme">Чем занимается (лор, вход LLM).</param>
/// <param name="SectorSlug">Сектор.</param>
/// <param name="StartPrice">Стартовая цена акции.</param>
/// <param name="PriceStep">Шаг цены (MinPriceIncrement).</param>
/// <param name="LotSize">Лот.</param>
/// <param name="SharesMln">Условных акций в обращении, млн (для индекса).</param>
/// <param name="BaseEpsPerCycle">Базовая «прибыль на акцию» за цикл (=«год»).</param>
/// <param name="PayoutRatio">Доля прибыли на дивиденды [0..1].</param>
/// <param name="Leverage">Долговая нагрузка [0..1] — влияет на бету к ставке и дистресс.</param>
/// <param name="SigmaDaily">Идиосинкразическая дневная волатильность (лог).</param>
/// <param name="Story">Живой лор компании на 2–3 предложения (справочник, вход LLM).</param>
public sealed record IssuerSpec(
    string Symbol,
    string Name,
    string Theme,
    string SectorSlug,
    decimal StartPrice,
    decimal PriceStep,
    int LotSize,
    double SharesMln,
    double BaseEpsPerCycle,
    double PayoutRatio,
    double Leverage,
    double SigmaDaily,
    string Story);

/// <summary>Выпуск облигации.</summary>
/// <param name="Symbol">Тикер выпуска.</param>
/// <param name="Name">Название выпуска.</param>
/// <param name="IssuerSymbol">Эмитент (null = государство Алории).</param>
/// <param name="Quality">Кредитное качество.</param>
/// <param name="CouponRatePerCycle">Купонная ставка за цикл (=«год»), доля (0.09 = 9%).</param>
/// <param name="CouponEveryDays">Каждые сколько мировых дней платится купон.</param>
/// <param name="MaturityCycles">Сколько циклов до погашения на старте мира.</param>
public sealed record BondSpec(
    string Symbol,
    string Name,
    string? IssuerSymbol,
    CreditQuality Quality,
    double CouponRatePerCycle,
    int CouponEveryDays,
    int MaturityCycles);

/// <summary>Фонд.</summary>
/// <param name="Symbol">Тикер.</param>
/// <param name="Name">Название.</param>
/// <param name="IsBondFund">Облигационный (иначе — индексный акций).</param>
/// <param name="StartPrice">Стартовый пай.</param>
/// <param name="Description">Описание фонда для справочника (лор).</param>
public sealed record FundSpec(
    string Symbol,
    string Name,
    bool IsBondFund,
    decimal StartPrice,
    string Description);

/// <summary>Дериватив. Задел на будущее: в мире Алории деривативы пока не торгуются.</summary>
/// <param name="Symbol">Тикер.</param>
/// <param name="Name">Название.</param>
/// <param name="Type">Тип инструмента (например, Futures).</param>
/// <param name="UnderlyingSymbol">Базовый актив.</param>
/// <param name="Description">Описание для справочника (лор).</param>
public sealed record DerivativeSpec(
    string Symbol,
    string Name,
    string Type,
    string UnderlyingSymbol,
    string Description);

/// <summary>
/// Вселенная Алории: единый источник правды для сида instruments,
/// состояния режиссёра и промптов LLM.
/// </summary>
public static class Universe
{
    public static readonly IReadOnlyList<SectorSpec> Sectors =
    [
        new("finance",   "Финансы",           0.8,  +0.50, -0.2, 0.012,
            "Банки и страховщики. Рост ставки им чаще на руку."),
        new("consumer",  "Потребительский",   0.6,  -0.30, -0.4, 0.010,
            "Товары на каждый день — спрос устойчивее, чем у других."),
        new("retail",    "Ритейл",            0.9,  -0.50, -0.5, 0.013,
            "Магазины и торговля. Живут настроением покупателей."),
        new("food",      "Общепит и еда",     0.3,  -0.20, -0.3, 0.008,
            "Кафе и пекарни. Едят даже в рецессию — сектор-тихоня."),
        new("logistics", "Логистика",         1.1,  -0.60, -0.4, 0.014,
            "Доставка и порты. Барометр деловой активности страны."),
        new("tech",      "Технологии",        1.4,  -1.00, -0.2, 0.020,
            "IT и игры. Быстро растут, но больнее всех падают."),
        new("travel",    "Туризм",            1.6,  -0.80, -0.5, 0.022,
            "Отдых и путешествия — первое, на чём экономят в кризис."),
        new("energy",    "Энергетика",        0.7,  -0.20, +0.6, 0.016,
            "Сети и топливо. Инфляция для них часто плюс, не минус."),
    ];

    public static readonly IReadOnlyList<IssuerSpec> Issuers =
    [
        //         Symbol  Name              Theme                          Sector      Price  Step  Lot Shares EPS  Payout Lev  Sigma
        new("ALBK", "Банк Алория",     "системный банк",                    "finance",   250m, 0.5m, 1,  120,  28.0, 0.50, 0.55, 0.011,
            "Старейший банк страны: через него проходит половина платежей Алории. "
            + "Кредитует всех — от пекарен до порта, поэтому его отчёт читают как "
            + "сводку здоровья всей экономики."),
        new("INSA", "Страж Полис",     "страхование",                       "finance",    90m, 0.1m, 10,  80,   9.5, 0.40, 0.30, 0.012,
            "Страхует дома, грузы и урожай. Зарабатывает на спокойных временах: "
            + "пока ничего не горит и не тонет, премии капают, а выплат мало."),
        new("ICEC", "Холодок и Ко",    "производитель мороженого",          "consumer",   64m, 0.1m, 10,  60,   6.0, 0.45, 0.25, 0.012,
            "Легенда алорийского лета. Полстраны выросло на пломбире «Холодок», "
            + "и каждую жару компания бьёт рекорды продаж — а в холодный сезон "
            + "спасается тортами-мороженое."),
        new("DRNK", "ЖивВода",         "напитки и вода",                    "consumer",  120m, 0.5m, 10,  90,  11.0, 0.50, 0.20, 0.009,
            "Разливает воду из северных источников Алории и делает лимонады по "
            + "старым рецептам. Скучный стабильный бизнес — пить хотят всегда."),
        new("HOME", "ДомоТехника",     "бытовая техника",                   "consumer",  340m, 0.5m, 1,   45,  30.0, 0.30, 0.45, 0.013,
            "Собирает холодильники и стиральные машины «для алорийской семьи». "
            + "Покупки крупные и нечастые: когда у людей туго с деньгами, новую "
            + "плиту откладывают на потом."),
        new("SHOP", "РядомМаркет",     "магазины у дома",                   "retail",    180m, 0.5m, 1,  150,  15.0, 0.35, 0.50, 0.012,
            "Сеть «магазинов за углом» в каждом районе. Держится на обороте: "
            + "маржа копеечная, зато покупатель заходит каждый день."),
        new("WEAR", "НосиСмело",       "одежда и обувь",                    "retail",     55m, 0.1m, 10,  70,   4.8, 0.25, 0.40, 0.016,
            "Модный бренд для молодёжи: яркие коллекции, шумные распродажи. "
            + "Продажи скачут вместе с модой — угадали сезон или нет."),
        new("FAST", "ШустроЕд",        "сеть быстрого питания",             "food",       75m, 0.1m, 10, 110,   7.2, 0.40, 0.35, 0.011,
            "Бургерные на каждой площади страны. Фирменный соус «Шустрый» — "
            + "государственная тайна похлеще резервов центробанка."),
        new("BRED", "Тёплый Хлеб",     "кафе и пекарни",                    "food",       42m, 0.1m, 10,  50,   3.9, 0.45, 0.20, 0.010,
            "Семейные пекарни с круассанами, за которыми стоят очереди с утра. "
            + "Маленькая, уютная и на удивление живучая в любой кризис."),
        new("MOVE", "ЕдемБыстро",      "доставка и логистика",              "logistics", 210m, 0.5m, 1,   95,  17.0, 0.20, 0.60, 0.015,
            "Курьеры в зелёных куртках и фуры на всех трассах Алории. Растёт "
            + "агрессивно и в долг — ставка по кредитам для неё больной вопрос."),
        new("PORT", "Порт Алория",     "морской порт и грузовой хаб",       "logistics", 480m, 1.0m, 1,   35,  46.0, 0.55, 0.45, 0.012,
            "Морские ворота страны: почти весь импорт и экспорт проходит через "
            + "его краны. Полугосударственный гигант со стабильными тарифами."),
        new("DIGI", "ЦифраЛаб",        "онлайн-сервисы и IT",               "tech",      620m, 1.0m, 1,   65,  34.0, 0.05, 0.15, 0.021,
            "Главная IT-компания Алории: почта, карты, облака и такси в одном "
            + "приложении. Прибыль почти не раздаёт — всё уходит в новые сервисы."),
        new("GAME", "ИгроСфера",       "игры и развлечения",                "tech",      150m, 0.5m, 1,   40,   8.0, 0.00, 0.10, 0.026,
            "Студия, чей хит «Драконы Алории» играла вся страна. Живёт от релиза "
            + "до релиза: удачная игра — праздник, провал — долгая зима."),
        new("TRVL", "Свободный Путь",  "туризм и отдых",                    "travel",     95m, 0.1m, 10,  55,   8.6, 0.30, 0.65, 0.020,
            "Туроператор и сеть отелей на южном побережье. Набрала кредитов на "
            + "новые курорты — в хорошие годы летает, в плохие считает каждую "
            + "монету."),
        new("NRGA", "АлорЭнерго",      "электросети и генерация",           "energy",    130m, 0.5m, 10, 200,  14.5, 0.60, 0.50, 0.010,
            "Держит все провода страны: свет в домах — её работа. Тарифы "
            + "регулируются, поэтому сюрпризов мало, а дивиденды регулярные."),
        new("FUEL", "ТопливоПром",     "добыча и переработка топлива",      "energy",    390m, 0.5m, 1,   85,  48.0, 0.45, 0.40, 0.018,
            "Качает и перерабатывает топливо на севере Алории. Когда цены на "
            + "сырьё растут, здесь праздник — даже если всей остальной экономике "
            + "от этого больно."),
    ];

    /// <summary>
    /// Облигации: 2 государственные + 4 корпоративные с лестницей качества.
    /// Цена котируется в процентах номинала (номинал 1000), шаг 0.01.
    /// TRVB1 — сознательно рисковый выпуск (кандидат в дефолт при кризисе).
    /// </summary>
    public static readonly IReadOnlyList<BondSpec> Bonds =
    [
        new("GOVB1", "Гособлигация Алории 1", null,   CreditQuality.Gov, 0.070, 2, 2),
        new("GOVB2", "Гособлигация Алории 2", null,   CreditQuality.Gov, 0.075, 2, 5),
        new("ALBB1", "Банк Алория Б1",        "ALBK", CreditQuality.A,   0.095, 2, 3),
        new("MOVB1", "ЕдемБыстро Б1",         "MOVE", CreditQuality.Bbb, 0.120, 2, 3),
        new("FULB1", "ТопливоПром Б1",        "FUEL", CreditQuality.Bbb, 0.115, 2, 4),
        new("TRVB1", "Свободный Путь Б1",     "TRVL", CreditQuality.Bb,  0.160, 2, 2),
    ];

    public static readonly IReadOnlyList<FundSpec> Funds =
    [
        new("ALIN", "Индекс Алории",     false, 100m,
            "Пай на все акции страны разом, крупные компании весят больше. "
            + "Один инструмент — вся экономика Алории."),
        new("ALBF", "Облигации Алории",  true,  100m,
            "Корзина государственных и корпоративных облигаций. Спокойнее "
            + "акций, живёт на купонах."),
    ];

    /// <summary>
    /// Деривативы: в мире Алории пока не торгуются — список пуст. Это задел,
    /// чтобы каталог справочника уже поддерживал их схему.
    /// </summary>
    public static readonly IReadOnlyList<DerivativeSpec> Derivatives = [];

    public const decimal BondFaceValue = 1000m;
    public const decimal BondPriceStep = 0.01m;
    public const int CycleDays = 10;

    public static SectorSpec SectorOf(string slug) => Sectors.First(s => s.Slug == slug);
    public static SectorSpec SectorOfIssuer(IssuerSpec i) => SectorOf(i.SectorSlug);
}
