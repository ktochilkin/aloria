namespace Aloria.Api.Domain;

/// <summary>
/// Сектор экономического мира Aloria (финансы, ритейл, технологии и т. п.).
/// Группирует компании; в будущем несёт беты к макрофакторам для ИИ-режиссёра.
/// </summary>
public class Sector
{
    public Guid Id { get; set; }
    public string Slug { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public int Order { get; set; }

    public List<Company> Companies { get; set; } = new();
}
