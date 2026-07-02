namespace Terex.OrderGenerator.Models;

/// <summary>Целевая котировка инструмента из director.price_targets (Aloria Director).</summary>
public sealed class TargetInfo
{
    public required string Symbol { get; init; }

    /// <summary>Целевая цена — «гравитация» для середины котирования.</summary>
    public decimal TargetPrice { get; init; }

    /// <summary>Дневная волатильность (лог) — из неё считается спред.</summary>
    public decimal SigmaDaily { get; init; }

    /// <summary>false — инструмент не котируем (дефолт/погашение).</summary>
    public bool Active { get; init; }
}
