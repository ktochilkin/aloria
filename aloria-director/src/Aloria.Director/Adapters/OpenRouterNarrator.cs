using System.Text;
using System.Text.Json;
using Aloria.Director.Core.Model;
using Aloria.Director.Core.News;

namespace Aloria.Director.Adapters;

/// <summary>
/// LLM-нарратор через OpenRouter. Получает готовый спек события (числа уже
/// решены RNG/формулами) и решает только «что за история»: выбирает жертву из
/// пула кандидатов и пишет заголовок/текст. Строгий JSON-контракт, один retry,
/// при любой ошибке — шаблонный fallback: мир не останавливается из-за LLM.
/// </summary>
public sealed class OpenRouterNarrator : INarrator
{
    private readonly HttpClient _http;
    private readonly TemplateNarrator _fallback;
    private readonly DirectorOptions.LlmOptions _options;
    private readonly ILogger<OpenRouterNarrator> _log;
    private readonly string? _apiKey;

    /// <summary>После серии ошибок LLM отключается на время (circuit breaker).</summary>
    private int _consecutiveFailures;
    private DateTime _pausedUntil = DateTime.MinValue;

    public OpenRouterNarrator(
        HttpClient http,
        TemplateNarrator fallback,
        DirectorOptions.LlmOptions options,
        ILogger<OpenRouterNarrator> log)
    {
        _http = http;
        _fallback = fallback;
        _options = options;
        _log = log;
        _apiKey = Environment.GetEnvironmentVariable(options.ApiKeyEnv);

        _http.BaseAddress = new Uri(options.BaseUrl.TrimEnd('/') + "/");
        _http.Timeout = TimeSpan.FromSeconds(options.TimeoutSeconds);
        if (_apiKey is not null)
            _http.DefaultRequestHeaders.Authorization = new("Bearer", _apiKey);
    }

    public async Task<NewsStory> NarrateAsync(NewsDraft draft, CancellationToken ct = default)
    {
        // Механические новости (купоны/выплаты/отсечки/ожидания) не жгут токены.
        var mechanical = draft.Spec.Type is EventType.Coupon or EventType.DividendPayout
            or EventType.DividendCutoff or EventType.ExpectationNote or EventType.Maturity;

        if (!_options.Enabled || _apiKey is null || mechanical || DateTime.UtcNow < _pausedUntil)
            return await _fallback.NarrateAsync(draft, ct);

        for (var attempt = 0; attempt < 2; attempt++)
        {
            try
            {
                var story = await RequestAsync(draft, ct);
                if (story is not null)
                {
                    _consecutiveFailures = 0;
                    return story;
                }
            }
            catch (Exception e) when (e is not OperationCanceledException || !ct.IsCancellationRequested)
            {
                _log.LogWarning(e, "LLM narrate attempt {Attempt} failed", attempt + 1);
            }
        }

        if (++_consecutiveFailures >= 3)
        {
            _pausedUntil = DateTime.UtcNow.AddMinutes(5);
            _consecutiveFailures = 0;
            _log.LogWarning("LLM paused for 5 minutes after repeated failures");
        }

        return await _fallback.NarrateAsync(draft, ct);
    }

    private async Task<NewsStory?> RequestAsync(NewsDraft draft, CancellationToken ct)
    {
        var payload = new
        {
            model = _options.Model,
            temperature = _options.Temperature,
            response_format = new { type = "json_object" },
            messages = new object[]
            {
                new { role = "system", content = SystemPrompt },
                new { role = "user", content = BuildUserPrompt(draft) },
            },
        };

        using var response = await _http.PostAsync("chat/completions",
            new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json"), ct);
        response.EnsureSuccessStatusCode();

        using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
        var content = doc.RootElement
            .GetProperty("choices")[0]
            .GetProperty("message")
            .GetProperty("content")
            .GetString();
        if (string.IsNullOrWhiteSpace(content)) return null;

        return ParseStory(content, draft);
    }

    private NewsStory? ParseStory(string content, NewsDraft draft)
    {
        // Модель может обернуть JSON в ```-блок — срежем.
        var start = content.IndexOf('{');
        var end = content.LastIndexOf('}');
        if (start < 0 || end <= start) return null;

        using var doc = JsonDocument.Parse(content[start..(end + 1)]);
        var root = doc.RootElement;

        var headline = root.TryGetProperty("headline", out var h) ? h.GetString() : null;
        var body = root.TryGetProperty("body", out var b) ? b.GetString() : null;
        if (string.IsNullOrWhiteSpace(headline) || string.IsNullOrWhiteSpace(body)) return null;

        var sentiment = root.TryGetProperty("sentiment", out var s) ? s.GetString() : null;
        var symbol = root.TryGetProperty("symbol", out var sym) ? sym.GetString() : null;

        // Жертва — строго из пула кандидатов; фантазии LLM отбрасываем.
        if (symbol is not null
            && draft.Spec.CandidateSymbols.Count > 0
            && !draft.Spec.CandidateSymbols.Contains(symbol))
            symbol = null;

        return new NewsStory
        {
            Headline = headline.Length > 250 ? headline[..250] : headline,
            Body = body,
            Sentiment = sentiment switch
            {
                "positive" => Sentiment.Positive,
                "negative" => Sentiment.Negative,
                _ => draft.Spec.Sign > 0 ? Sentiment.Positive
                    : draft.Spec.Sign < 0 ? Sentiment.Negative : Sentiment.Neutral,
            },
            ChosenSymbol = symbol,
        };
    }

    private const string SystemPrompt =
        """
        Ты — режиссёр новостей учебного экономического мира «Алория» (вымышленная страна,
        вымышленные компании). Тебе дают СПЕЦИФИКАЦИЮ события: охват, знак, серьёзность,
        кандидатов. Числа уже решены — ты решаешь ТОЛЬКО:
        1) какая конкретно живая история произошла (можно бытовую/забавную причину,
           но последствия всегда реалистичные и рыночные);
        2) кого из кандидатов она задела (поле symbol — строго из списка candidates);
        3) заголовок и текст.

        Формат body: ровно 3 коротких предложения: факт → операционные последствия →
        реакция рынка/эффект второго порядка. Не повторяй недавние заголовки.
        Запрещено: советы покупать/продавать, обещания доходности, слова «ставка на»,
        «казино», преуменьшение риска. Тон — живой, но взрослый.

        Ответ — ТОЛЬКО валидный JSON без markdown:
        {"symbol": "ТИКЕР или null", "headline": "...", "body": "...",
         "sentiment": "positive|negative|neutral"}
        """;

    private static string BuildUserPrompt(NewsDraft draft)
    {
        var spec = draft.Spec;
        var candidates = spec.CandidateSymbols.Count > 0
            ? Universe.Issuers
                .Where(i => spec.CandidateSymbols.Contains(i.Symbol))
                .Select(i => new { i.Symbol, i.Name, i.Theme })
                .Cast<object>()
                .ToArray()
            : [];

        var sector = spec.SectorSlug is not null
            ? Universe.Sectors.FirstOrDefault(s => s.Slug == spec.SectorSlug)?.Title
            : null;

        return JsonSerializer.Serialize(new
        {
            world = new
            {
                day = draft.World.Day,
                cycleDay = draft.World.CycleDay,
                regime = draft.World.Regime.ToString(),
                crisis = draft.World.Crisis,
                keyRate = draft.World.KeyRate,
                inflation = draft.World.Inflation,
                growth = draft.World.Growth,
            },
            @event = new
            {
                type = spec.Type.ToString(),
                scope = spec.Scope.ToString(),
                severity = Math.Round(spec.Severity, 2),
                sign = spec.Sign,
                shape = spec.Shape.ToString(),
                sector,
                actual = spec.Actual,
                expected = spec.Expected,
                surpriseSigmas = spec.SurpriseZ,
            },
            candidates,
            recentHeadlines = draft.RecentHeadlines,
        });
    }
}
