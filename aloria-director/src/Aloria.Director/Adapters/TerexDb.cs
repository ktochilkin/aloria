using System.Text.Json;
using Aloria.Director.Core.Engine;
using Aloria.Director.Core.Model;
using Npgsql;

namespace Aloria.Director.Adapters;

/// <summary>
/// Адаптер Postgres terex. Пишем сырым SQL: EF-модель Terex.Common расходится
/// с реальной DDL-схемой (суррогатный PK "Id" с GENERATED ALWAYS, nullability),
/// и завязываться на приватный NuGet не хочется. Колонки instruments —
/// PascalCase в кавычках (по DDL CreateInstruments.sql). Схема director.* —
/// собственность режиссёра.
/// </summary>
public sealed class TerexDb
{
    private readonly NpgsqlDataSource _dataSource;
    private readonly ILogger<TerexDb> _log;

    public TerexDb(string connectionString, ILogger<TerexDb> log)
    {
        _dataSource = NpgsqlDataSource.Create(connectionString);
        _log = log;
    }

    // ------------------------------------------------------------- schema

    public async Task EnsureDirectorSchemaAsync(CancellationToken ct = default)
    {
        const string sql = """
            CREATE SCHEMA IF NOT EXISTS director;

            CREATE TABLE IF NOT EXISTS director.price_targets (
                symbol       varchar(20) PRIMARY KEY,
                target_price numeric      NOT NULL,
                sigma_daily  numeric      NOT NULL,
                active       boolean      NOT NULL DEFAULT true,
                updated_at   timestamptz  NOT NULL DEFAULT now()
            );

            CREATE TABLE IF NOT EXISTS director.world_state (
                id         int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
                state_json jsonb        NOT NULL,
                updated_at timestamptz  NOT NULL DEFAULT now()
            );

            CREATE TABLE IF NOT EXISTS director.events_log (
                id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                day        int          NOT NULL,
                tick       int          NOT NULL,
                type       text         NOT NULL,
                scope      text         NOT NULL,
                severity   numeric      NOT NULL,
                sign       int          NOT NULL,
                symbol     text         NULL,
                headline   text         NULL,
                payload    jsonb        NULL,
                created_at timestamptz  NOT NULL DEFAULT now()
            );
            CREATE INDEX IF NOT EXISTS idx_director_events_day ON director.events_log (day, tick);
            """;
        await using var cmd = _dataSource.CreateCommand(sql);
        await cmd.ExecuteNonQueryAsync(ct);
        _log.LogInformation("director schema ensured");
    }

    // -------------------------------------------------------------- seed

    /// <summary>
    /// Идемпотентный сид вселенной в instruments (по образцу terex_instruments_seed.sql).
    /// Коридор лимитов сразу широкий (×0.25..×4), чтобы валидатор orderprocessor
    /// не мешал движению цен без рестартов.
    /// </summary>
    public async Task<int> SeedInstrumentsAsync(CancellationToken ct = default)
    {
        var inserted = 0;
        foreach (var i in Universe.Issuers)
            inserted += await InsertInstrumentAsync(
                i.Symbol, i.Name, "CS", "ESVUFR",
                i.StartPrice, i.PriceStep, i.LotSize,
                faceValue: 1m, maturity: null, volatility: (decimal)i.SigmaDaily, ct);

        foreach (var b in Universe.Bonds)
        {
            var days = b.MaturityCycles * Universe.CycleDays;
            inserted += await InsertInstrumentAsync(
                b.Symbol, b.Name, "BOND", "DBFTFR",
                100m, Universe.BondPriceStep, 1,
                faceValue: Universe.BondFaceValue,
                maturity: DateTime.UtcNow.Date.AddDays(days),
                volatility: 0.004m, ct);
        }

        foreach (var f in Universe.Funds)
            inserted += await InsertInstrumentAsync(
                f.Symbol, f.Name, "ETF", "CEOJLU",
                f.StartPrice, 0.01m, 1,
                faceValue: 1m, maturity: null, volatility: 0.01m, ct);

        _log.LogInformation("instruments seeded: {Inserted} new rows", inserted);
        return inserted;
    }

    private async Task<int> InsertInstrumentAsync(
        string symbol, string desc, string securityType, string cfi,
        decimal price, decimal step, int lot,
        decimal faceValue, DateTime? maturity, decimal volatility,
        CancellationToken ct)
    {
        // Широкий коридор, квантованный к шагу.
        var low = Math.Max(step, Math.Floor(price * 0.25m / step) * step);
        var high = Math.Ceiling(price * 4m / step) * step;

        const string sql = """
            INSERT INTO public.instruments (
                "Symbol", "SecurityExchange", "SecurityGroup", "SecurityID", "SecurityIDSource",
                "SecurityType", "SecurityDesc", "StateSecurityID", "CFICode", "MaturityDate",
                "MinPriceIncrement", "UnitOfMeasureQty", "Factor", "Currency", "RoundLot",
                "TradingSessionID", "SecurityTradingStatus", "SettlCurrency", "SettlDate",
                "FaceValue", "MarketCode", "SettlFixingDate", "MarketID",
                "LowLimitPrice", "HighLimitPrice", "Volatility", "UnderlyingCurrency",
                "TheorPrice", "TheorPriceLimit", "InitialMarginOnBuy", "InitialMarginOnSell",
                "InitialMarginSyntetic", "ComplexProductCategory", "SettlementType")
            SELECT
                @symbol, 'TEREX', 'TEREX', @symbol, 'TEREX',
                @securityType, @desc, '', @cfi, @maturity,
                @step, 0, 1, 'RUB', @lot,
                'TEREX', 17, 'RUB', NULL,
                @faceValue, 'TEREX', NULL, 'TEREX',
                @low, @high, @volatility, 'RUB',
                0, 0, 0, 0,
                0, '', 2
            WHERE NOT EXISTS (
                SELECT 1 FROM public.instruments i
                WHERE i."Symbol" = @symbol AND i."SecurityGroup" = 'TEREX')
            """;

        await using var cmd = _dataSource.CreateCommand(sql);
        cmd.Parameters.AddWithValue("symbol", symbol);
        cmd.Parameters.AddWithValue("securityType", securityType);
        cmd.Parameters.AddWithValue("desc", desc.Length > 100 ? desc[..100] : desc);
        cmd.Parameters.AddWithValue("cfi", cfi);
        cmd.Parameters.AddWithValue("maturity", maturity ?? DateTime.MaxValue);
        cmd.Parameters.AddWithValue("step", step);
        cmd.Parameters.AddWithValue("lot", (decimal)lot);
        cmd.Parameters.AddWithValue("faceValue", faceValue);
        cmd.Parameters.AddWithValue("low", low);
        cmd.Parameters.AddWithValue("high", high);
        cmd.Parameters.AddWithValue("volatility", volatility);
        return await cmd.ExecuteNonQueryAsync(ct);
    }

    // ------------------------------------------------------------ targets

    public async Task UpsertTargetsAsync(IReadOnlyList<PriceTarget> targets, CancellationToken ct = default)
    {
        if (targets.Count == 0) return;

        await using var conn = await _dataSource.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);

        const string sql = """
            INSERT INTO director.price_targets (symbol, target_price, sigma_daily, active, updated_at)
            VALUES (@symbol, @price, @sigma, @active, now())
            ON CONFLICT (symbol) DO UPDATE SET
                target_price = EXCLUDED.target_price,
                sigma_daily  = EXCLUDED.sigma_daily,
                active       = EXCLUDED.active,
                updated_at   = now()
            """;

        foreach (var t in targets)
        {
            await using var cmd = new NpgsqlCommand(sql, conn, tx);
            cmd.Parameters.AddWithValue("symbol", t.Symbol);
            cmd.Parameters.AddWithValue("price", t.TargetPrice);
            cmd.Parameters.AddWithValue("sigma", t.SigmaDaily);
            cmd.Parameters.AddWithValue("active", t.Active);
            await cmd.ExecuteNonQueryAsync(ct);
        }

        await tx.CommitAsync(ct);
    }

    // ------------------------------------------------------------- state

    public async Task SaveWorldStateAsync(WorldPersistDto dto, CancellationToken ct = default)
    {
        const string sql = """
            INSERT INTO director.world_state (id, state_json, updated_at)
            VALUES (1, @json::jsonb, now())
            ON CONFLICT (id) DO UPDATE SET state_json = EXCLUDED.state_json, updated_at = now()
            """;
        await using var cmd = _dataSource.CreateCommand(sql);
        cmd.Parameters.AddWithValue("json", JsonSerializer.Serialize(dto));
        await cmd.ExecuteNonQueryAsync(ct);
    }

    public async Task<WorldPersistDto?> LoadWorldStateAsync(CancellationToken ct = default)
    {
        const string sql = "SELECT state_json FROM director.world_state WHERE id = 1";
        await using var cmd = _dataSource.CreateCommand(sql);
        var raw = await cmd.ExecuteScalarAsync(ct) as string;
        return raw is null ? null : JsonSerializer.Deserialize<WorldPersistDto>(raw);
    }

    // -------------------------------------------------------------- events

    public async Task SaveEventsAsync(IReadOnlyList<EventLogEntry> events, CancellationToken ct = default)
    {
        if (events.Count == 0) return;

        const string sql = """
            INSERT INTO director.events_log (day, tick, type, scope, severity, sign, symbol, headline, payload)
            VALUES (@day, @tick, @type, @scope, @severity, @sign, @symbol, @headline, @payload::jsonb)
            """;

        await using var conn = await _dataSource.OpenConnectionAsync(ct);
        foreach (var e in events)
        {
            await using var cmd = new NpgsqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("day", e.Day);
            cmd.Parameters.AddWithValue("tick", e.TickOfDay);
            cmd.Parameters.AddWithValue("type", e.Spec.Type.ToString());
            cmd.Parameters.AddWithValue("scope", e.Spec.Scope.ToString());
            cmd.Parameters.AddWithValue("severity", e.Spec.Severity);
            cmd.Parameters.AddWithValue("sign", e.Spec.Sign);
            cmd.Parameters.AddWithValue("symbol", (object?)e.Spec.Symbol ?? DBNull.Value);
            cmd.Parameters.AddWithValue("headline", (object?)e.Headline ?? DBNull.Value);
            cmd.Parameters.AddWithValue("payload", JsonSerializer.Serialize(e.AppliedLogImpact));
            await cmd.ExecuteNonQueryAsync(ct);
        }
    }
}
