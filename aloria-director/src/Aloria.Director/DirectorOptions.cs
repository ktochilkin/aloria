namespace Aloria.Director;

/// <summary>Конфигурация сервиса (appsettings.json, секция Director + env-оверрайды).</summary>
public sealed class DirectorOptions
{
    /// <summary>Seed мира — один seed, один воспроизводимый мир.</summary>
    public int Seed { get; set; } = 20260701;

    /// <summary>Тиков в мировом дне.</summary>
    public int TicksPerDay { get; set; } = 96;

    /// <summary>Реальных секунд между тиками в режиме run (900 = 15 минут).</summary>
    public int TickSeconds { get; set; } = 900;

    /// <summary>HTTP-порт админки режиссёра.</summary>
    public int Port { get; set; } = 5077;

    public LlmOptions Llm { get; set; } = new();
    public TerexDbOptions TerexDb { get; set; } = new();
    public AloriaApiOptions AloriaApi { get; set; } = new();
    public ForesightOptions Foresight { get; set; } = new();

    /// <summary>Просчёт — точное будущее живого мира (тот же поток костей).</summary>
    public sealed class ForesightOptions
    {
        /// <summary>Горизонт по умолчанию, дней.</summary>
        public int DefaultDays { get; set; } = 30;

        /// <summary>Потолок: дальше не покажет, сколько ни проси (спойлер-гигиена).</summary>
        public int MaxDays { get; set; } = 120;
    }

    public sealed class LlmOptions
    {
        /// <summary>Выключено → всегда шаблонный нарратор (мир работает без сети).</summary>
        public bool Enabled { get; set; } = true;

        public string BaseUrl { get; set; } = "https://openrouter.ai/api/v1";

        /// <summary>Модель OpenRouter (дешёвая и быстрая по умолчанию).</summary>
        public string Model { get; set; } = "openai/gpt-4o-mini";

        /// <summary>Имя env-переменной с ключом.</summary>
        public string ApiKeyEnv { get; set; } = "OPENROUTER_API_KEY";

        public double Temperature { get; set; } = 0.9;
        public int TimeoutSeconds { get; set; } = 25;
    }

    public sealed class TerexDbOptions
    {
        /// <summary>Строка подключения к Postgres terex (env DIRECTOR_TEREX_DB перекрывает).</summary>
        public string? ConnectionString { get; set; }

        public bool Enabled { get; set; } = true;
    }

    public sealed class AloriaApiOptions
    {
        public bool Enabled { get; set; } = true;
        public string BaseUrl { get; set; } = "http://localhost:5050";
    }
}
