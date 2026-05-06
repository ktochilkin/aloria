using Aloria.Api.Data;
using Aloria.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Services;

/// <summary>
/// Идемпотентная выдача бонусной покупательной способности.
/// Тот же IdempotencyKey возвращает уже выданный grant, не создаёт новый.
/// </summary>
public class GrantService(AloriaDbContext db, IBrokerageGateway brokerage)
{
    public async Task<BuyingPowerGrant> GrantAsync(
        Guid userId,
        decimal amount,
        string reason,
        string idempotencyKey,
        CancellationToken ct = default)
    {
        var existing = await db.BuyingPowerGrants
            .FirstOrDefaultAsync(x => x.IdempotencyKey == idempotencyKey, ct);
        if (existing != null) return existing;

        var grant = new BuyingPowerGrant
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Amount = amount,
            Reason = reason,
            IdempotencyKey = idempotencyKey,
            Status = "pending",
            CreatedAt = DateTime.UtcNow,
        };
        db.BuyingPowerGrants.Add(grant);
        await db.SaveChangesAsync(ct);

        try
        {
            var result = await brokerage.GrantBuyingPowerAsync(grant, ct);
            grant.Status = result.IsCommitted ? "committed" : "failed";
            grant.FailureReason = result.FailureReason;
            grant.CommittedAt = result.IsCommitted ? DateTime.UtcNow : null;
        }
        catch (Exception ex)
        {
            grant.Status = "failed";
            grant.FailureReason = ex.Message;
        }
        await db.SaveChangesAsync(ct);
        return grant;
    }
}
