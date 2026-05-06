using Aloria.Api.Domain;

namespace Aloria.Api.Services;

/// <summary>
/// Шлюз к торговой системе Алора. На старте — заглушка: записываем grant
/// со статусом committed, реальный API не дёргаем.
/// Когда появится контракт от торговой команды — здесь живёт интеграция.
/// </summary>
public interface IBrokerageGateway
{
    Task<BrokerageGrantResult> GrantBuyingPowerAsync(
        BuyingPowerGrant grant,
        CancellationToken ct = default);
}

public record BrokerageGrantResult(bool IsCommitted, string? FailureReason);

public class StubBrokerageGateway(ILogger<StubBrokerageGateway> log) : IBrokerageGateway
{
    public Task<BrokerageGrantResult> GrantBuyingPowerAsync(
        BuyingPowerGrant grant,
        CancellationToken ct = default)
    {
        log.LogInformation(
            "[BROKERAGE STUB] Grant {GrantId} for user {UserId}: +{Amount} ₽ ({Reason})",
            grant.Id, grant.UserId, grant.Amount, grant.Reason);
        // На реальной интеграции сюда придёт HTTP-вызов в торговый бэк.
        return Task.FromResult(new BrokerageGrantResult(true, null));
    }
}
