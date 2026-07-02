namespace Aloria.Director.Core.Engine;

/// <summary>
/// Ручки тюнинга мира — то, что можно крутить на лету из админки без правки
/// кода. Дефолты = откалиброванные значения; изменения переживают рестарт
/// (сохраняются в снимке мира).
/// </summary>
public sealed record WorldTuning
{
    /// <summary>Множитель частоты всех стохастических событий (1 = базовые ~4.6/день).</summary>
    public double EventRateMultiplier { get; init; } = 1.0;

    /// <summary>Шанс уйти в тяжёлый хвост Парето при розыгрыше серьёзности.</summary>
    public double TailChance { get; init; } = 0.09;

    /// <summary>Порог серьёзности негативного макрошока, за которым начинается кризис.</summary>
    public double CrisisSeverityThreshold { get; init; } = 0.85;

    /// <summary>Вероятность «пузырь лопнул» за день перегрева.</summary>
    public double PeakBubbleBurstPerDay { get; init; } = 0.04;

    /// <summary>Прямой hazard кризиса: вероятность в день в ЛЮБОМ режиме (0 = выкл).</summary>
    public double CrisisHazardPerDay { get; init; } = 0.0;

    /// <summary>Общий множитель волатильности поверх режимного.</summary>
    public double VolatilityMultiplier { get; init; } = 1.0;

    /// <summary>Разжатые к разумному диапазону значения (защита от опечаток в админке).</summary>
    public WorldTuning Clamped() => new()
    {
        EventRateMultiplier = Math.Clamp(EventRateMultiplier, 0.1, 10),
        TailChance = Math.Clamp(TailChance, 0, 0.5),
        CrisisSeverityThreshold = Math.Clamp(CrisisSeverityThreshold, 0.5, 1.0),
        PeakBubbleBurstPerDay = Math.Clamp(PeakBubbleBurstPerDay, 0, 0.5),
        CrisisHazardPerDay = Math.Clamp(CrisisHazardPerDay, 0, 0.5),
        VolatilityMultiplier = Math.Clamp(VolatilityMultiplier, 0.25, 4),
    };
}
