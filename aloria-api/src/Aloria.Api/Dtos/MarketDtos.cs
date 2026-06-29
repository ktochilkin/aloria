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

/// <summary>Вход для ручной правки макросостояния (админ).</summary>
public record MacroStateInput(
    string? Regime,
    double? KeyRate,
    double? Inflation,
    int? CycleDay,
    int? CycleLength);
