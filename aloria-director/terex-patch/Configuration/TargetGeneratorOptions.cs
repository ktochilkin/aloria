using Alor.Core.Settings;

namespace Terex.OrderGenerator.Configuration;

/// <summary>
/// Настройки маркетмейкера по целевым ценам (Terex::TargetGenerator).
/// Генератор котирует лестницу заявок вокруг целевой цены из
/// director.price_targets (таблица сервиса Aloria Director в той же БД terex),
/// перечитывая цели на лету — рынок движется за «миром» без рестартов.
/// Секция опциональна: без неё генератор выключен.
/// </summary>
internal sealed class TargetGeneratorOptions
{
    /// <summary>Минимальная пауза между котированиями одного инструмента, мс.</summary>
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.Required)]
    public int MinIntervalMs { get; init; }

    /// <summary>Максимальная пауза между котированиями одного инструмента, мс.</summary>
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.Required)]
    public int MaxIntervalMs { get; init; }

    /// <summary>Период перечитывания целевых цен и инструментов из БД, сек.</summary>
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.Required)]
    public int TargetsRefreshSeconds { get; init; }

    /// <summary>Доля разрыва до цели, закрываемая за одно котирование, % (напр. 25).</summary>
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.Required)]
    public int PullFactorPct { get; init; }

    /// <summary>Максимальный сдвиг середины за одно котирование, шагов цены.</summary>
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.Required)]
    public int MaxStepTicks { get; init; }

    /// <summary>Случайный шум середины, ± шагов цены.</summary>
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.Required)]
    public int NoiseSteps { get; init; }

    /// <summary>Спред = max(2 шага, фактор × дневная волатильность × цена). Фактор в сотых (80 = 0.8).</summary>
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.Required)]
    public int SpreadSigmaFactorPct { get; init; }

    /// <summary>Уровней лестницы на каждую сторону.</summary>
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.Required)]
    public int DepthLevels { get; init; }

    /// <summary>Расстояние между уровнями лестницы, шагов цены.</summary>
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.Required)]
    public int LevelStepTicks { get; init; }

    /// <summary>Максимальный объём лимитной заявки одного уровня.</summary>
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.Required)]
    public int MaxLimitQuantity { get; init; }

    /// <summary>Базовая вероятность рыночной заявки-тейкера на котирование, %.</summary>
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.Required)]
    public int TakerProbPct { get; init; }

    /// <summary>Максимальный объём рыночной заявки-тейкера.</summary>
    [AlorSettings(SettingsSource.Identity, SettingsSeverity.Required)]
    public int MaxMarketQuantity { get; init; }
}
