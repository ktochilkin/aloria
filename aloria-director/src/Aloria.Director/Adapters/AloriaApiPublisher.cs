using System.Text;
using System.Text.Json;
using Aloria.Director.Core.Model;

namespace Aloria.Director.Adapters;

/// <summary>
/// Публикация контента мира в aloria-api (клиентский read-API приложения):
/// новости, макросостояние, календарь. Ошибки не валят тик — логируются,
/// следующий тик пробует снова (aloria-api может быть просто не поднят).
/// </summary>
public sealed class AloriaApiPublisher
{
    private readonly HttpClient _http;
    private readonly ILogger<AloriaApiPublisher> _log;

    public AloriaApiPublisher(HttpClient http, DirectorOptions.AloriaApiOptions options,
        ILogger<AloriaApiPublisher> log)
    {
        _http = http;
        _http.BaseAddress = new Uri(options.BaseUrl.TrimEnd('/') + "/");
        _http.Timeout = TimeSpan.FromSeconds(10);
        _log = log;
    }

    public async Task PublishNewsAsync(IReadOnlyList<WorldNews> news, CancellationToken ct = default)
    {
        foreach (var n in news)
        {
            var payload = new
            {
                headline = n.Headline,
                content = n.Body,
                sentiment = n.Sentiment switch
                {
                    Sentiment.Positive => "positive",
                    Sentiment.Negative => "negative",
                    _ => "neutral",
                },
                eventType = MapType(n.Type),
                scope = n.Scope switch
                {
                    EventScope.Macro => "macro",
                    EventScope.Sector => "sector",
                    _ => "company",
                },
                symbols = string.Join(',', n.Symbols),
                sectorSlug = n.SectorSlug,
                urgency = n.Urgency,
                source = "director",
            };
            await PostAsync("api/admin/market/news", payload, ct);
        }
    }

    public Task PublishMacroAsync(WorldSnapshot snapshot, CancellationToken ct = default)
        => PutAsync("api/admin/macro/state", new
        {
            regime = snapshot.Regime switch
            {
                Regime.Expansion => "expansion",
                Regime.Peak => "peak",
                Regime.Recession => "recession",
                Regime.Recovery => "recovery",
                _ => "expansion",
            },
            keyRate = snapshot.KeyRate,
            inflation = snapshot.Inflation,
            cycleDay = snapshot.CycleDay,
            cycleLength = Universe.CycleDays,
            source = "director",
        }, ct);

    public async Task PublishCalendarAsync(
        IReadOnlyList<CalendarEvent> events, CancellationToken ct = default)
    {
        if (events.Count == 0) return;
        var payload = events
            .Where(e => e.Type is not (EventType.ExpectationNote))
            .Select(e => new
            {
                day = e.Day,
                tickOfDay = e.TickOfDay,
                type = MapType(e.Type),
                symbol = e.Symbol,
            })
            .ToArray();
        await PostAsync("api/admin/market/calendar", payload, ct);
    }

    /// <summary>Словарь типов между миром режиссёра и лентой приложения.</summary>
    private static string MapType(EventType t) => t switch
    {
        EventType.Earnings => "earnings",
        EventType.DividendDecision or EventType.DividendCutoff or EventType.DividendPayout => "dividend",
        EventType.Coupon => "coupon",
        EventType.Maturity => "maturity",
        EventType.RateDecision => "rate",
        EventType.MacroShock => "macro",
        EventType.SectorShock => "sector",
        EventType.ProductNews => "product",
        EventType.OperationsShock => "operations",
        EventType.Default => "default",
        EventType.ExpectationNote => "guidance",
        _ => "operations",
    };

    private async Task PostAsync(string path, object payload, CancellationToken ct)
    {
        try
        {
            using var res = await _http.PostAsync(path,
                new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json"), ct);
            if (!res.IsSuccessStatusCode)
                _log.LogWarning("aloria-api POST {Path} → {Status}", path, (int)res.StatusCode);
        }
        catch (Exception e)
        {
            _log.LogWarning("aloria-api POST {Path} failed: {Message}", path, e.Message);
        }
    }

    private async Task PutAsync(string path, object payload, CancellationToken ct)
    {
        try
        {
            using var res = await _http.PutAsync(path,
                new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json"), ct);
            if (!res.IsSuccessStatusCode)
                _log.LogWarning("aloria-api PUT {Path} → {Status}", path, (int)res.StatusCode);
        }
        catch (Exception e)
        {
            _log.LogWarning("aloria-api PUT {Path} failed: {Message}", path, e.Message);
        }
    }
}
