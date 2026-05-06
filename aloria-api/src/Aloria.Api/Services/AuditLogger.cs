using Aloria.Api.Data;
using Aloria.Api.Domain;

namespace Aloria.Api.Services;

public class AuditLogger(AloriaDbContext db)
{
    public async Task LogAsync(
        string action,
        string entityType,
        Guid? entityId,
        string? details = null,
        CancellationToken ct = default)
    {
        db.AuditLog.Add(new AuditLogEntry
        {
            Id = Guid.NewGuid(),
            Actor = "admin",
            Action = action,
            EntityType = entityType,
            EntityId = entityId?.ToString(),
            Details = details,
            CreatedAt = DateTime.UtcNow,
        });
        await db.SaveChangesAsync(ct);
    }
}
