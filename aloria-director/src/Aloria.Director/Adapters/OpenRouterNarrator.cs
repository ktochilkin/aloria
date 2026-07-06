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
        Ты — редактор деловых новостей вымышленной страны Алория (игровой учебный мир:
        свои компании, своя биржа, свой колорит). Тебе дают СПЕЦИФИКАЦИЮ события: охват,
        знак, серьёзность, компанию. Все числа уже решены — ты отвечаешь ТОЛЬКО за историю:
        1) придумай конкретный живой инфоповод, соответствующий знаку и серьёзности;
        2) если quirky=true — причина ОБЯЗАНА быть бытовой/забавной (казус, курьёз,
           нелепое стечение обстоятельств), но последствия — всегда реалистичные и
           рыночные: издержки, спрос, логистика, репутация;
        3) для продуктовых событий (type=ProductNews) придумай КОНКРЕТНЫЙ продукт:
           название в кавычках и одной фразой — что это, в духе лора компании (story).
           Никаких безликих «новый продукт»: читатель должен понять, что именно вышло;
        4) заголовок цепляющий, но не жёлтый; body — 3–4 предложения:
           факт → операционные последствия → реакция рынка/эффект второго порядка,
           можно добавить деталь лора Алории или сухую шутку.

        Можно опираться на лор компании (поле story у кандидатов), но не противоречить ему.
        Пиши так, чтобы новости хотелось читать: конкретика, детали, лёгкая ирония.
        Не повторяй недавние заголовки (recentHeadlines). Запрещено: советы
        покупать/продавать, обещания доходности, «ставка», «казино», преуменьшение риска.

        Для смены руководителя (type=CeoChange, detail = имя назначенца):
        напиши новость о назначении. Знак (sign) — единственный намёк на силу
        назначения: +1 — «рынок встретил со сдержанным оптимизмом», -1 —
        «инвесторы пожимают плечами», 0 — рабочее назначение без ярлыков.
        Намекай ТОЛЬКО качественно; никаких чисел, рейтингов и оценок
        «качества менеджмента» — этот параметр скрыт от игроков. Для scope=Macro
        это смена главы ЦБ Алории: sign +1 — ястреб (жёстче к инфляции),
        -1 — голубь (мягче к экономике), 0 — прагматик.

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
                .Select(i => new
                {
                    i.Symbol,
                    i.Name,
                    i.Theme,
                    story = i.Story,
                    stage = i.Stage.ToString().ToLowerInvariant(),
                    // Живое имя CEO — из состояния мира; спек — только фолбэк.
                    ceoName = draft.CandidateCeos.GetValueOrDefault(i.Symbol, i.CeoName0),
                    bonds = Universe.Bonds
                        .Where(b => b.IssuerSymbol == i.Symbol)
                        .Select(b => b.Symbol)
                        .ToArray(),
                })
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
                quirky = spec.Quirky,
                sector,
                actual = spec.Actual,
                expected = spec.Expected,
                surpriseSigmas = spec.SurpriseZ,
                detail = spec.Detail,
            },
            candidates,
            recentHeadlines = draft.RecentHeadlines,
        });
    }
}
