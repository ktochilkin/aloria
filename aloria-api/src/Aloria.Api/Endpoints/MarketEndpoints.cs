using Aloria.Api.Data;
using Aloria.Api.Domain;
using Aloria.Api.Dtos;
using Aloria.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Endpoints;

/// <summary>
/// Эндпоинты экономического мира: новости (фильтр по symbol/сектору/типу),
/// справочник секторов/компаний, макросостояние и справочник-каталог мира
/// (лор компаний, облигации, фонды, деривативы). Клиент читает их вместо
/// торгового <c>/news/graphql</c>. Писатель данных на шаге 1 — мок-сидер,
/// позже — ИИ-режиссёр.
/// </summary>
public static class MarketEndpoints
{
    public static IEndpointRouteBuilder MapMarketEndpoints(this IEndpointRouteBuilder app)
    {
        MapClient(app);
        MapAdmin(app);
        return app;
    }

    private static void MapClient(IEndpointRouteBuilder app)
    {
        var market = app.MapGroup("/api/v1/market").WithTags("Market");

        market.MapGet("/news", async (
            string? symbol,
            string? sector,
            string? type,
            int? limit,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var take = Math.Clamp(limit ?? 50, 1, 200);
            var q = db.NewsItems.AsQueryable();

            if (!string.IsNullOrWhiteSpace(symbol))
            {
                var s = symbol.Trim().ToUpperInvariant();
                // Symbols хранятся как CSV; обрамляем запятыми, чтобы не ловить
                // частичные совпадения (HOME ≠ HOMER).
                q = q.Where(n => ("," + n.Symbols + ",").Contains("," + s + ","));
            }
            if (!string.IsNullOrWhiteSpace(sector))
                q = q.Where(n => n.SectorSlug == sector);
            if (!string.IsNullOrWhiteSpace(type))
                q = q.Where(n => n.EventType == type);

            var rows = await q
                .OrderByDescending(n => n.PublishDate)
                .Take(take)
                .ToListAsync(ct);

            return Results.Ok(rows.Select(ToDto));
        });

        market.MapGet("/sectors", async (AloriaDbContext db, CancellationToken ct) =>
        {
            var sectors = await db.Sectors
                .OrderBy(s => s.Order)
                .Include(s => s.Companies)
                .ToListAsync(ct);

            var dto = sectors.Select(s => new MarketSectorDto(
                s.Id, s.Slug, s.Title, s.Order,
                s.Companies.OrderBy(c => c.Order)
                    .Select(c => new CompanyDto(c.Id, c.Symbol, c.Name, c.Theme, s.Slug, c.Order))
                    .ToList()));
            return Results.Ok(dto);
        });

        // Справочник-каталог мира Алории целиком: сектора с лором, компании,
        // облигации, фонды, деривативы. Пока каталог не запушен режиссёром —
        // отдаём пустые массивы (не 404), клиенту так проще.
        market.MapGet("/reference", async (AloriaDbContext db, CancellationToken ct) =>
        {
            var sectors = await db.ReferenceSectors.OrderBy(x => x.Order).ToListAsync(ct);
            var companies = await db.ReferenceCompanies.OrderBy(x => x.Order).ToListAsync(ct);
            var bonds = await db.ReferenceBonds.OrderBy(x => x.Order).ToListAsync(ct);
            var funds = await db.ReferenceFunds.OrderBy(x => x.Order).ToListAsync(ct);
            var derivatives = await db.ReferenceDerivatives.OrderBy(x => x.Order).ToListAsync(ct);

            return Results.Ok(new MarketReferenceDto(
                sectors.Select(s => new ReferenceSectorDto(s.Slug, s.Title, s.Description)).ToList(),
                companies.Select(c => new ReferenceCompanyDto(
                    c.Symbol, c.Name, c.SectorSlug, c.Theme, c.Story,
                    c.Payout, c.Leverage, c.Sigma,
                    c.Stage, c.CeoName, c.CeoSinceDay)).ToList(),
                bonds.Select(x => new ReferenceBondDto(
                    x.Symbol, x.Name, x.IssuerSymbol, x.Quality,
                    x.CouponPerCycle, x.CouponEveryDays)).ToList(),
                funds.Select(f => new ReferenceFundDto(
                    f.Symbol, f.Name, f.IsBondFund, f.Description)).ToList(),
                derivatives.Select(d => new ReferenceDerivativeDto(
                    d.Symbol, d.Name, d.Type, d.UnderlyingSymbol, d.Description)).ToList()));
        });

        app.MapGet("/api/v1/macro/state", async (AloriaDbContext db, CancellationToken ct) =>
        {
            var m = await db.MacroStates
                .OrderByDescending(x => x.UpdatedAt)
                .FirstOrDefaultAsync(ct);
            return m == null ? Results.NotFound() : Results.Ok(ToDto(m));
        }).WithTags("Market");

        // Календарь цикла: ближайшие события с указанного мирового дня.
        app.MapGet("/api/v1/macro/calendar", async (
            int? fromDay,
            int? limit,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var take = Math.Clamp(limit ?? 50, 1, 200);
            var q = db.CycleCalendar.AsQueryable();
            if (fromDay is { } d) q = q.Where(x => x.Day >= d);

            var rows = await q
                .OrderBy(x => x.Day).ThenBy(x => x.TickOfDay)
                .Take(take)
                .ToListAsync(ct);
            return Results.Ok(rows.Select(x => new CalendarItemDto(
                x.Day, x.TickOfDay, x.Type,
                string.IsNullOrEmpty(x.Symbol) ? null : x.Symbol)));
        }).WithTags("Market");
    }

    private static void MapAdmin(IEndpointRouteBuilder app)
    {
        var admin = app.MapGroup("/api/admin/market").WithTags("Admin");

        admin.MapPost("/news/reseed", async (
            int? count,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var n = Math.Clamp(count ?? 48, 1, 500);
            await MarketMockSeeder.RegenerateNewsAsync(db, n, ct);
            return Results.Ok(new { reseeded = n });
        });

        admin.MapPut("/macro/state", async (
            MacroStateInput input,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var m = await db.MacroStates
                .OrderByDescending(x => x.UpdatedAt)
                .FirstOrDefaultAsync(ct);
            if (m == null)
            {
                m = new MacroState { Id = Guid.NewGuid() };
                db.MacroStates.Add(m);
            }

            if (!string.IsNullOrWhiteSpace(input.Regime)) m.Regime = input.Regime!;
            if (input.KeyRate is { } kr) m.KeyRate = kr;
            if (input.Inflation is { } inf) m.Inflation = inf;
            if (input.CycleDay is { } cd) m.CycleDay = cd;
            if (input.CycleLength is { } cl) m.CycleLength = cl;
            m.Source = string.IsNullOrWhiteSpace(input.Source) ? "mock" : input.Source!;
            m.UpdatedAt = DateTime.UtcNow;

            await db.SaveChangesAsync(ct);
            return Results.Ok(ToDto(m));
        });

        // Ингест новости от Aloria Director.
        admin.MapPost("/news", async (
            DirectorNewsInput input,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(input.Headline) || string.IsNullOrWhiteSpace(input.Content))
                return Results.BadRequest("headline и content обязательны");

            var item = new NewsItem
            {
                Id = Guid.NewGuid(),
                Headline = input.Headline.Length > 256 ? input.Headline[..256] : input.Headline,
                Content = input.Content,
                PublishDate = DateTime.UtcNow,
                Sentiment = input.Sentiment is "positive" or "negative" ? input.Sentiment : "neutral",
                EventType = string.IsNullOrWhiteSpace(input.EventType) ? "operations" : input.EventType!,
                Scope = input.Scope is "macro" or "sector" ? input.Scope! : "company",
                Symbols = input.Symbols ?? string.Empty,
                SectorSlug = input.SectorSlug,
                Urgency = Math.Clamp(input.Urgency ?? 2, 1, 3),
                Source = string.IsNullOrWhiteSpace(input.Source) ? "director" : input.Source!,
                CreatedAt = DateTime.UtcNow,
            };
            db.NewsItems.Add(item);
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { id = item.Id });
        });

        // Ингест справочника-каталога мира от Aloria Director: полная атомарная
        // замена содержимого reference-таблиц в одной транзакции (идемпотентно —
        // повторный PUT того же каталога даёт то же состояние).
        admin.MapPut("/reference", async (
            MarketReferenceInput input,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var sectors = input.Sectors ?? Array.Empty<ReferenceSectorDto>();
            var companies = input.Companies ?? Array.Empty<ReferenceCompanyDto>();
            var bonds = input.Bonds ?? Array.Empty<ReferenceBondDto>();
            var funds = input.Funds ?? Array.Empty<ReferenceFundDto>();
            var derivatives = input.Derivatives ?? Array.Empty<ReferenceDerivativeDto>();

            if (sectors.Any(s => string.IsNullOrWhiteSpace(s.Slug)))
                return Results.BadRequest("у каждого сектора должен быть непустой slug");
            if (companies.Any(c => string.IsNullOrWhiteSpace(c.Symbol))
                || bonds.Any(x => string.IsNullOrWhiteSpace(x.Symbol))
                || funds.Any(f => string.IsNullOrWhiteSpace(f.Symbol))
                || derivatives.Any(d => string.IsNullOrWhiteSpace(d.Symbol)))
                return Results.BadRequest("у каждого инструмента должен быть непустой symbol");

            await using var tx = await db.Database.BeginTransactionAsync(ct);

            await db.ReferenceSectors.ExecuteDeleteAsync(ct);
            await db.ReferenceCompanies.ExecuteDeleteAsync(ct);
            await db.ReferenceBonds.ExecuteDeleteAsync(ct);
            await db.ReferenceFunds.ExecuteDeleteAsync(ct);
            await db.ReferenceDerivatives.ExecuteDeleteAsync(ct);

            db.ReferenceSectors.AddRange(sectors.Select((s, i) => new ReferenceSector
            {
                Id = Guid.NewGuid(),
                Slug = s.Slug.Trim(),
                Title = s.Title ?? string.Empty,
                Description = s.Description ?? string.Empty,
                Order = i,
            }));
            db.ReferenceCompanies.AddRange(companies.Select((c, i) => new ReferenceCompany
            {
                Id = Guid.NewGuid(),
                Symbol = c.Symbol.Trim().ToUpperInvariant(),
                Name = c.Name ?? string.Empty,
                SectorSlug = c.SectorSlug ?? string.Empty,
                Theme = c.Theme ?? string.Empty,
                Story = c.Story ?? string.Empty,
                Payout = c.Payout,
                Leverage = c.Leverage,
                Sigma = c.Sigma,
                // Отсутствие поля в PUT = дефолт (обратная совместимость со
                // старым каталогом без stage/CEO).
                Stage = string.IsNullOrWhiteSpace(c.Stage) ? "mature" : c.Stage.Trim(),
                CeoName = string.IsNullOrWhiteSpace(c.CeoName) ? null : c.CeoName.Trim(),
                CeoSinceDay = c.CeoSinceDay,
                Order = i,
            }));
            db.ReferenceBonds.AddRange(bonds.Select((x, i) => new ReferenceBond
            {
                Id = Guid.NewGuid(),
                Symbol = x.Symbol.Trim().ToUpperInvariant(),
                Name = x.Name ?? string.Empty,
                IssuerSymbol = string.IsNullOrWhiteSpace(x.IssuerSymbol) ? null : x.IssuerSymbol.Trim().ToUpperInvariant(),
                Quality = x.Quality ?? string.Empty,
                CouponPerCycle = x.CouponPerCycle,
                CouponEveryDays = x.CouponEveryDays,
                Order = i,
            }));
            db.ReferenceFunds.AddRange(funds.Select((f, i) => new ReferenceFund
            {
                Id = Guid.NewGuid(),
                Symbol = f.Symbol.Trim().ToUpperInvariant(),
                Name = f.Name ?? string.Empty,
                IsBondFund = f.IsBondFund,
                Description = f.Description ?? string.Empty,
                Order = i,
            }));
            db.ReferenceDerivatives.AddRange(derivatives.Select((d, i) => new ReferenceDerivative
            {
                Id = Guid.NewGuid(),
                Symbol = d.Symbol.Trim().ToUpperInvariant(),
                Name = d.Name ?? string.Empty,
                Type = d.Type ?? string.Empty,
                UnderlyingSymbol = string.IsNullOrWhiteSpace(d.UnderlyingSymbol) ? null : d.UnderlyingSymbol.Trim().ToUpperInvariant(),
                Description = d.Description ?? string.Empty,
                Order = i,
            }));

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);

            return Results.Ok(new
            {
                sectors = sectors.Length,
                companies = companies.Length,
                bonds = bonds.Length,
                funds = funds.Length,
                derivatives = derivatives.Length,
            });
        });

        // Ингест календаря цикла от Aloria Director (идемпотентно по ключу события).
        // Symbol хранится пустой строкой вместо NULL: сравнение с NULL в SQL и
        // уникальный индекс с NULL не дают идемпотентности.
        admin.MapPost("/calendar", async (
            CalendarItemInput[] input,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var added = 0;
            var seen = new HashSet<string>();
            foreach (var e in input)
            {
                var symbol = e.Symbol ?? string.Empty;
                if (!seen.Add($"{e.Day}|{e.TickOfDay}|{e.Type}|{symbol}")) continue;

                var exists = await db.CycleCalendar.AnyAsync(x =>
                    x.Day == e.Day && x.TickOfDay == e.TickOfDay
                    && x.Type == e.Type && x.Symbol == symbol, ct);
                if (exists) continue;

                db.CycleCalendar.Add(new CycleCalendarItem
                {
                    Id = Guid.NewGuid(),
                    Day = e.Day,
                    TickOfDay = e.TickOfDay,
                    Type = e.Type,
                    Symbol = symbol,
                    CreatedAt = DateTime.UtcNow,
                });
                added++;
            }
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { added });
        });
    }

    private static MarketNewsDto ToDto(NewsItem n) => new(
        // SQLite теряет DateTimeKind: без SpecifyKind дата уедет клиенту без 'Z',
        // и приложение примет UTC за локальное время (сдвиг на часовой пояс).
        n.Id, n.Headline, n.Content,
        DateTime.SpecifyKind(n.PublishDate, DateTimeKind.Utc),
        n.Sentiment, n.EventType, n.Scope,
        string.IsNullOrEmpty(n.Symbols)
            ? Array.Empty<string>()
            : n.Symbols.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries),
        n.SectorSlug, n.Urgency);

    private static MacroStateDto ToDto(MacroState m) => new(
        m.Regime, m.KeyRate, m.Inflation, m.CycleDay, m.CycleLength, m.Source,
        DateTime.SpecifyKind(m.UpdatedAt, DateTimeKind.Utc));
}
