namespace Aloria.Director.Core.Model;

/// <summary>Фаза экономического цикла.</summary>
public enum Regime
{
    Expansion,
    Peak,
    Recession,
    Recovery,
}

/// <summary>Класс инструмента.</summary>
public enum AssetClass
{
    Equity,
    Bond,
    Fund,
    /// <summary>Задел: фьючерсы/опционы (математика готова, инструменты позже).</summary>
    Derivative,
}

/// <summary>Охват события.</summary>
public enum EventScope
{
    Company,
    Sector,
    Macro,
}

/// <summary>Форма воздействия события на цену.</summary>
public enum EventShape
{
    /// <summary>Мгновенный скачок справедливой стоимости.</summary>
    Jump,
    /// <summary>«Тление»: дрейф в течение нескольких тиков.</summary>
    Drift,
    /// <summary>Временный шок: уходит и возвращается (mean-reverting).</summary>
    Transient,
}

/// <summary>Тип события — общий словарь режиссёра, календаря и новостей.</summary>
public enum EventType
{
    // Плановые (календарь)
    Earnings,
    DividendDecision,
    DividendCutoff,
    DividendPayout,
    Coupon,
    Maturity,
    RateDecision,
    Expiry,
    // Стохастические
    OperationsShock,
    ProductNews,
    SectorShock,
    MacroShock,
    Default,
    // Служебные
    ExpectationNote,
}

/// <summary>Тональность новости.</summary>
public enum Sentiment
{
    Negative,
    Neutral,
    Positive,
}

/// <summary>Кредитное качество эмитента (для облигаций).</summary>
public enum CreditQuality
{
    Gov,
    A,
    Bbb,
    Bb,
}
