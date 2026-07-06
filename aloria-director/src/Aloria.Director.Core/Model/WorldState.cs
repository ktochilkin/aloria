namespace Aloria.Director.Core.Model;

/// <summary>Макросостояние мира.</summary>
public sealed class MacroState
{
    public Regime Regime { get; set; } = Regime.Expansion;

    /// <summary>Сколько мировых дней идёт текущий режим.</summary>
    public int RegimeAgeDays { get; set; }

    /// <summary>Запланированная длительность текущего режима, дней.</summary>
    public int RegimePlannedDays { get; set; }

    /// <summary>Ключевая ставка, % за цикл («годовых»).</summary>
    public double KeyRate { get; set; } = 7.5;

    /// <summary>Инфляция, % за цикл.</summary>
    public double Inflation { get; set; } = 4.2;

    /// <summary>Рост экономики, % за цикл (может быть отрицательным).</summary>
    public double Growth { get; set; } = 2.0;

    /// <summary>Аппетит к риску [-1..1].</summary>
    public double RiskAppetite { get; set; } = 0.3;

    /// <summary>Кризисный оверлей: волатильность ×, корреляции → 1.</summary>
    public bool Crisis { get; set; }

    /// <summary>
    /// Дней с конца последнего кризиса («засуха»). Питает пейсинг: кулдаун
    /// после кризиса и растущий hazard при долгом штиле. Старт мира = 15,
    /// чтобы свежий мир не ждал первый кризис слишком долго и не получал сразу.
    /// </summary>
    public int DaysSinceCrisis { get; set; } = 15;
}

/// <summary>Живое состояние эмитента (двигается миром).</summary>
public sealed class IssuerState
{
    public required IssuerSpec Spec { get; init; }

    /// <summary>Лог справедливой стоимости акции.</summary>
    public double LogFair { get; set; }

    /// <summary>Текущая целевая цена (к ней тянется рынок).</summary>
    public double Target { get; set; }

    /// <summary>Тренд EPS за цикл (двигается событиями/режимом).</summary>
    public double EpsTrend { get; set; }

    /// <summary>Дистресс [0..1]: близость к дефолту (для облигаций эмитента).</summary>
    public double Distress { get; set; }

    /// <summary>Объявленный, но ещё не выплаченный дивиденд на акцию (для отсечки).</summary>
    public double PendingDividend { get; set; }

    /// <summary>Эмитент в дефолте (купоны не платятся).</summary>
    public bool Defaulted { get; set; }

    /// <summary>
    /// Живое качество менеджмента [0..1] — СКРЫТЫЙ параметр (наружу не отдаётся,
    /// кроме админ-ручки). Старт = <c>Spec.MgmtQuality0</c>, меняется при смене CEO.
    /// </summary>
    public double Management { get; set; }

    /// <summary>Текущий CEO (видимая часть: имя уходит в справочник приложения).</summary>
    public string CeoName { get; set; } = string.Empty;

    /// <summary>С какого мирового дня руководит текущий CEO.</summary>
    public int CeoSinceDay { get; set; }

    /// <summary>Остаток «тлеющих» шоков: (тиков осталось, лог-дельта за тик).</summary>
    public List<(int TicksLeft, double PerTick)> Smoulder { get; } = [];

    /// <summary>Временные шоки: (тиков осталось, полный лог-сдвиг, скорость возврата).</summary>
    public List<(int TicksLeft, double Level)> Transients { get; } = [];
}

/// <summary>
/// Состояние ЦБ Алории: у регулятора есть «характер» — ястребиность главы
/// смещает решения по ставке. Скрытая часть ДНК мира: число наружу не отдаётся,
/// наблюдается по паттерну решений и окраске новостей.
/// </summary>
public sealed class CentralBankState
{
    /// <summary>Ястребиность главы [-1..1]: ястреб повышает раньше, снижает позже.</summary>
    public double Hawkishness { get; set; } = 0.3;

    /// <summary>Имя главы ЦБ (вымышленное).</summary>
    public string GovernorName { get; set; } = Universe.InitialCbGovernor;

    /// <summary>С какого мирового дня руководит текущий глава.</summary>
    public int SinceDay { get; set; }
}

/// <summary>Живое состояние выпуска облигации.</summary>
public sealed class BondState
{
    public required BondSpec Spec { get; init; }

    /// <summary>Кредитный спред за цикл, п.п. (двигается качеством/режимом/дистрессом).</summary>
    public double Spread { get; set; }

    /// <summary>Дней до погашения.</summary>
    public int DaysToMaturity { get; set; }

    /// <summary>Целевая чистая цена, % номинала.</summary>
    public double TargetClean { get; set; } = 100;

    /// <summary>НКД, % номинала.</summary>
    public double Accrued { get; set; }

    public bool Defaulted { get; set; }
    public bool Matured { get; set; }
}

/// <summary>Живое состояние сектора.</summary>
public sealed class SectorState
{
    public required SectorSpec Spec { get; init; }

    /// <summary>Накопленный секторный шок (лог, mean-reverting).</summary>
    public double Shock { get; set; }
}

/// <summary>Состояние фонда.</summary>
public sealed class FundState
{
    public required FundSpec Spec { get; init; }

    /// <summary>Делитель для пересчёта корзины в цену пая.</summary>
    public double Divisor { get; set; } = 1;

    public double Target { get; set; }
}

/// <summary>Полное состояние мира. Сериализуемо, воспроизводимо от seed.</summary>
public sealed class WorldState
{
    public int Day { get; set; } = 1;

    /// <summary>Тик внутри дня, 0..TicksPerDay-1.</summary>
    public int TickOfDay { get; set; }

    public int TicksPerDay { get; init; } = 96;

    public MacroState Macro { get; } = new();

    public CentralBankState CentralBank { get; } = new();

    public Dictionary<string, IssuerState> Issuers { get; } = new();
    public Dictionary<string, BondState> Bonds { get; } = new();
    public Dictionary<string, SectorState> Sectors { get; } = new();
    public Dictionary<string, FundState> Funds { get; } = new();

    public List<CalendarEvent> Calendar { get; } = [];

    /// <summary>Книга ожиданий по плановым событиям.</summary>
    public Dictionary<string, Expectation> Expectations { get; } = new();

    public int CycleDay => (Day - 1) % Model.Universe.CycleDays + 1;
    public int CycleIndex => (Day - 1) / Model.Universe.CycleDays + 1;
}

/// <summary>Плановое событие календаря.</summary>
public sealed class CalendarEvent
{
    public required string Id { get; init; }
    public required EventType Type { get; init; }
    public required int Day { get; init; }
    public required int TickOfDay { get; init; }

    /// <summary>Тикер (null для макро-событий, например заседания ЦБ).</summary>
    public string? Symbol { get; init; }

    public bool Done { get; set; }

    /// <summary>Опубликована ли новость-ожидание (за день до события).</summary>
    public bool ExpectationPublished { get; set; }
}

/// <summary>Консенсус-ожидание по плановому событию.</summary>
public sealed class Expectation
{
    /// <summary>Id календарного события.</summary>
    public required string EventId { get; init; }

    /// <summary>Ожидаемое значение (EPS, размер дивиденда, шаг ставки в п.п.).</summary>
    public double Expected { get; set; }

    /// <summary>Разброс консенсуса (для нормировки сюрприза).</summary>
    public double Sigma { get; set; }
}
