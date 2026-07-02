namespace Aloria.Api.Dtos;

/// <summary>Новость экономического мира для клиента.</summary>
public record MarketNewsDto(
    Guid Id,
    string Headline,
    string Content,
    DateTime PublishDate,
    string Sentiment,
    string EventType,
    string Scope,
    IReadOnlyList<string> Symbols,
    string? Sector,
    int Urgency);

/// <summary>Компания тестовой вселенной.</summary>
public record CompanyDto(
    Guid Id,
    string Symbol,
    string Name,
    string Theme,
    string Sector,
    int Order);

/// <summary>Сектор со списком компаний.</summary>
public record MarketSectorDto(
    Guid Id,
    string Slug,
    string Title,
    int Order,
    IReadOnlyList<CompanyDto> Companies);

/// <summary>Текущее состояние макромира.</summary>
public record MacroStateDto(
    string Regime,
    double KeyRate,
    double Inflation,
    int CycleDay,
    int CycleLength,
    string Source,
    DateTime UpdatedAt);

/// <summary>Вход для правки макросостояния (админ вручную или Aloria Director).</summary>
public record MacroStateInput(
    string? Regime,
    double? KeyRate,
    double? Inflation,
    int? CycleDay,
    int? CycleLength,
    string? Source);

/// <summary>Новость от Aloria Director (ингест).</summary>
public record DirectorNewsInput(
    string Headline,
    string Content,
    string? Sentiment,
    string? EventType,
    string? Scope,
    string? Symbols,
    string? SectorSlug,
    int? Urgency,
    string? Source);

/// <summary>Событие календаря цикла от Aloria Director.</summary>
public record CalendarItemInput(int Day, int TickOfDay, string Type, string? Symbol);

/// <summary>Событие календаря цикла для клиента.</summary>
public record CalendarItemDto(int Day, int TickOfDay, string Type, string? Symbol);
