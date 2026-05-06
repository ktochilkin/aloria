namespace Aloria.Api.Domain;

/// <summary>Лог действий в админке. Кто (пока заглушка), что, над чем.</summary>
public class AuditLogEntry
{
    public Guid Id { get; set; }
    public string Actor { get; set; } = "admin";
    public string Action { get; set; } = string.Empty; // "create" | "update" | "delete" | "publish"
    public string EntityType { get; set; } = string.Empty;
    public string? EntityId { get; set; }
    public string? Details { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
