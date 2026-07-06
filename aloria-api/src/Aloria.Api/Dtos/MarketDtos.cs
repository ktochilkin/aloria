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

// Справочник-каталог мира Алории. Shape единый для PUT (режиссёр -> aloria-api)
// и GET (aloria-api -> приложение), элементы каталога — общие record'ы.

/// <summary>Сектор каталога с лором.</summary>
public record ReferenceSectorDto(string Slug, string Title, string Description);

/// <summary>
/// Компания каталога: лор плюс фундаментальные параметры мира.
/// Stage/CeoName/CeoSinceDay nullable для обратной совместимости: старый PUT
/// без этих полей не падает (отсутствие поля = дефолт), GET всегда отдаёт stage.
/// </summary>
public record ReferenceCompanyDto(
    string Symbol,
    string Name,
    string SectorSlug,
    string Theme,
    string Story,
    double Payout,
    double Leverage,
    double Sigma,
    string? Stage = null,
    string? CeoName = null,
    int? CeoSinceDay = null);

/// <summary>Облигация каталога. Quality: Gov | A | Bbb | Bb.</summary>
public record ReferenceBondDto(
    string Symbol,
    string Name,
    string? IssuerSymbol,
    string Quality,
    double CouponPerCycle,
    int CouponEveryDays);

/// <summary>Фонд каталога.</summary>
public record ReferenceFundDto(
    string Symbol,
    string Name,
    bool IsBondFund,
    string Description);

/// <summary>Дериватив каталога (пока в мире не торгуются — список пуст).</summary>
public record ReferenceDerivativeDto(
    string Symbol,
    string Name,
    string Type,
    string? UnderlyingSymbol,
    string Description);

/// <summary>Каталог целиком от Aloria Director (полная замена; null == пусто).</summary>
public record MarketReferenceInput(
    ReferenceSectorDto[]? Sectors,
    ReferenceCompanyDto[]? Companies,
    ReferenceBondDto[]? Bonds,
    ReferenceFundDto[]? Funds,
    ReferenceDerivativeDto[]? Derivatives);

/// <summary>Каталог целиком для клиента (пустые массивы, если ещё не запушен).</summary>
public record MarketReferenceDto(
    IReadOnlyList<ReferenceSectorDto> Sectors,
    IReadOnlyList<ReferenceCompanyDto> Companies,
    IReadOnlyList<ReferenceBondDto> Bonds,
    IReadOnlyList<ReferenceFundDto> Funds,
    IReadOnlyList<ReferenceDerivativeDto> Derivatives);
