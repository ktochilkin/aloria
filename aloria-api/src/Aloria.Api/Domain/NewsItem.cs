namespace Aloria.Api.Domain;

/// <summary>
/// Новость экономического мира. На шаге 1 наполняется мок-генератором
/// (<c>Source = "mock"</c>); позже писателем станет ИИ-режиссёр
/// (<c>Source = "director"</c>). Связь с инструментами — через <see cref="Symbols"/>
/// (тикеры через запятую), с сектором — через <see cref="SectorSlug"/>.
/// </summary>
public class NewsItem
{
    public Guid Id { get; set; }
    public string Headline { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public DateTime PublishDate { get; set; } = DateTime.UtcNow;

    /// <summary>negative | neutral | positive</summary>
    public string Sentiment { get; set; } = "neutral";

    /// <summary>earnings | dividend | guidance | operations | macro | sector</summary>
    public string EventType { get; set; } = "operations";

    /// <summary>macro | sector | company</summary>
    public string Scope { get; set; } = "company";

    /// <summary>Тикеры через запятую (пусто для макро-новостей).</summary>
    public string Symbols { get; set; } = string.Empty;

    /// <summary>Slug основного затронутого сектора (null для макро).</summary>
    public string? SectorSlug { get; set; }

    public int Urgency { get; set; } = 2;

    /// <summary>mock | director — источник новости.</summary>
    public string Source { get; set; } = "mock";

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
