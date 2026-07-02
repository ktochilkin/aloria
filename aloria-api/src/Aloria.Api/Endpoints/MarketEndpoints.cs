using Aloria.Api.Data;
using Aloria.Api.Domain;
using Aloria.Api.Dtos;
using Aloria.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Endpoints;

/// <summary>
/// Эндпоинты экономического мира: новости (фильтр по symbol/сектору/типу),
/// справочник секторов/компаний и макросостояние. Клиент читает их вместо
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
        n.Id, n.Headline, n.Content, n.PublishDate, n.Sentiment, n.EventType, n.Scope,
        string.IsNullOrEmpty(n.Symbols)
            ? Array.Empty<string>()
            : n.Symbols.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries),
        n.SectorSlug, n.Urgency);

    private static MacroStateDto ToDto(MacroState m) => new(
        m.Regime, m.KeyRate, m.Inflation, m.CycleDay, m.CycleLength, m.Source, m.UpdatedAt);
}
