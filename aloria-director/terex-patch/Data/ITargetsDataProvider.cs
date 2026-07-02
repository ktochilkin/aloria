using Terex.OrderGenerator.Models;

namespace Terex.OrderGenerator.Data;

/// <summary>Чтение целевых цен режиссёра (director.price_targets).</summary>
public interface ITargetsDataProvider
{
    /// <summary>Все целевые цены; пустой массив, если схема ещё не создана.</summary>
    Task<TargetInfo[]> GetAllAsync(CancellationToken cancellationToken = default);
}
