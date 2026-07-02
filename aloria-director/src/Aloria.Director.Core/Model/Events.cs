namespace Aloria.Director.Core.Model;

/// <summary>
/// Спецификация события — то, что решает RNG-сэмплер/календарь ДО LLM.
/// Числа (серьёзность, знак, длительность) — только здесь; LLM получает спек
/// как рамку и решает лишь «что за история и как её рассказать».
/// </summary>
public sealed record EventSpec
{
    public required EventType Type { get; init; }
    public required EventScope Scope { get; init; }

    /// <summary>Серьёзность [0..1] (хвост Парето — редкие кризисы).</summary>
    public required double Severity { get; init; }

    /// <summary>Знак: +1 / -1 (для нейтральных — 0).</summary>
    public required int Sign { get; init; }

    public required EventShape Shape { get; init; }

    /// <summary>Длительность «тления» в тиках (для Shape=Drift/Transient).</summary>
    public int DurationTicks { get; init; }

    /// <summary>Основная цель (тикер/сектор), если уже зафиксирована сэмплером.</summary>
    public string? Symbol { get; init; }
    public string? SectorSlug { get; init; }

    /// <summary>Пул кандидатов для выбора LLM (когда цель не зафиксирована).</summary>
    public IReadOnlyList<string> CandidateSymbols { get; init; } = [];

    /// <summary>Сюрприз против ожиданий (для плановых), в сигмах.</summary>
    public double? SurpriseZ { get; init; }

    /// <summary>Фактическое значение планового события (EPS, дивиденд, шаг ставки).</summary>
    public double? Actual { get; init; }

    /// <summary>Ожидание консенсуса (для текста новости).</summary>
    public double? Expected { get; init; }
}

/// <summary>Черновик новости для нарратора (LLM или шаблоны).</summary>
public sealed record NewsDraft
{
    public required EventSpec Spec { get; init; }
    public required WorldSnapshot World { get; init; }

    /// <summary>Последние заголовки — антидубль для LLM.</summary>
    public IReadOnlyList<string> RecentHeadlines { get; init; } = [];
}

/// <summary>Готовая история от нарратора.</summary>
public sealed record NewsStory
{
    public required string Headline { get; init; }
    public required string Body { get; init; }
    public required Sentiment Sentiment { get; init; }

    /// <summary>Выбранный LLM тикер из пула кандидатов (если пул был).</summary>
    public string? ChosenSymbol { get; init; }
}

/// <summary>Итоговая новость мира (в aloria-api).</summary>
public sealed record WorldNews
{
    public required string Headline { get; init; }
    public required string Body { get; init; }
    public required Sentiment Sentiment { get; init; }
    public required EventType Type { get; init; }
    public required EventScope Scope { get; init; }
    public IReadOnlyList<string> Symbols { get; init; } = [];
    public string? SectorSlug { get; init; }
    public required int Day { get; init; }
    public required int TickOfDay { get; init; }
    public int Urgency { get; init; } = 2;
}

/// <summary>Снимок мира для нарратора/наблюдаемости (компактный, без ссылок).</summary>
public sealed record WorldSnapshot
{
    public required int Day { get; init; }
    public required int CycleDay { get; init; }
    public required Regime Regime { get; init; }
    public required bool Crisis { get; init; }
    public required double KeyRate { get; init; }
    public required double Inflation { get; init; }
    public required double Growth { get; init; }

    /// <summary>Дней с конца последнего кризиса (питает пейсинг).</summary>
    public int DaysSinceCrisis { get; init; }
}

/// <summary>Запись журнала события (для дебага/презентации/уроков «почему двигалось»).</summary>
public sealed record EventLogEntry
{
    public required int Day { get; init; }
    public required int TickOfDay { get; init; }
    public required EventSpec Spec { get; init; }

    /// <summary>Применённый лог-импакт по инструментам.</summary>
    public required IReadOnlyDictionary<string, double> AppliedLogImpact { get; init; }

    public string? Headline { get; init; }
}

/// <summary>Целевая котировка для маркетмейкера.</summary>
public sealed record PriceTarget
{
    public required string Symbol { get; init; }
    public required decimal TargetPrice { get; init; }

    /// <summary>Дневная волатильность (лог) — генератор делает из неё спред/шум.</summary>
    public required double SigmaDaily { get; init; }

    /// <summary>Торгуется ли (дефолт/погашение → false: генератор не котирует).</summary>
    public bool Active { get; init; } = true;
}

/// <summary>Выход одного тика мира.</summary>
public sealed class TickOutput
{
    public required WorldSnapshot Snapshot { get; init; }
    public List<PriceTarget> Targets { get; } = [];
    public List<WorldNews> News { get; } = [];
    public List<EventLogEntry> Events { get; } = [];
    public List<CalendarEvent> NewCalendarEvents { get; } = [];

    /// <summary>Изменилось ли макросостояние (надо ли пушить в aloria-api).</summary>
    public bool MacroChanged { get; set; }
}
