using Aloria.Director.Core.Model;

namespace Aloria.Director.Core.Engine;

/// <summary>
/// Снимок мира для сохранения/восстановления (JSON в director.world_state).
/// Спеки (вселенная) не сохраняются — восстанавливаются по символам из
/// <see cref="Universe"/>. Состояние RNG не сохраняется: после рестарта поток
/// случайностей новый (seed смешивается с днём), сам мир — продолжается.
/// </summary>
public sealed record WorldPersistDto
{
    public required int Day { get; init; }
    public required int TickOfDay { get; init; }
    public required int TicksPerDay { get; init; }
    public required int LastPlannedCycleStart { get; init; }

    public required MacroDto Macro { get; init; }
    public required Dictionary<string, IssuerDto> Issuers { get; init; }
    public required Dictionary<string, BondDto> Bonds { get; init; }
    public required Dictionary<string, double> SectorShocks { get; init; }
    public required Dictionary<string, FundDto> Funds { get; init; }
    public required List<CalendarDto> Calendar { get; init; }
    public required Dictionary<string, ExpectationDto> Expectations { get; init; }

    /// <summary>Ручки тюнинга (null в старых снимках → дефолты).</summary>
    public WorldTuning? Tuning { get; init; }

    /// <summary>
    /// Состояние потока костей. С ним рестарт продолжает ровно ТОТ ЖЕ поток
    /// случайностей, а ветка-просчёт предсказывает живой мир точно.
    /// null (ветки-симуляции) → новый поток от свежего seed.
    /// </summary>
    public RngState? Rng { get; init; }

    /// <summary>«Зерно будущего» — метка, из какого числа начат текущий поток.</summary>
    public int? FutureSeed { get; init; }

    /// <summary>Состояние ЦБ (null в старых снимках → стартовые значения).</summary>
    public CentralBankDto? CentralBank { get; init; }

    public sealed record MacroDto(
        Regime Regime, int RegimeAgeDays, int RegimePlannedDays,
        double KeyRate, double Inflation, double Growth, double RiskAppetite, bool Crisis,
        int DaysSinceCrisis = 15);

    public sealed record CentralBankDto(string GovernorName, double Hawkishness, int SinceDay);

    /// <summary>
    /// ДНК-поля с дефолтами: старый снимок без них восстанавливается со
    /// стартовыми значениями из спека (Management=MgmtQuality0, CeoName=CeoName0).
    /// </summary>
    public sealed record IssuerDto(
        double LogFair, double Target, double EpsTrend, double Distress,
        double PendingDividend, bool Defaulted, List<double[]> Smoulder,
        double? Management = null, string? CeoName = null, int CeoSinceDay = 0);

    public sealed record BondDto(
        double Spread, int DaysToMaturity, double TargetClean, double Accrued,
        bool Defaulted, bool Matured);

    public sealed record FundDto(double Divisor, double Target);

    public sealed record CalendarDto(
        string Id, EventType Type, int Day, int TickOfDay, string? Symbol,
        bool Done, bool ExpectationPublished);

    public sealed record ExpectationDto(string EventId, double Expected, double Sigma);
}

public static class WorldPersistence
{
    public static WorldPersistDto ToDto(
        WorldState s, int lastPlannedCycleStart,
        WorldTuning? tuning = null, RngState? rng = null, int? futureSeed = null) => new()
    {
        Tuning = tuning,
        Rng = rng,
        FutureSeed = futureSeed,
        Day = s.Day,
        TickOfDay = s.TickOfDay,
        TicksPerDay = s.TicksPerDay,
        LastPlannedCycleStart = lastPlannedCycleStart,
        Macro = new WorldPersistDto.MacroDto(
            s.Macro.Regime, s.Macro.RegimeAgeDays, s.Macro.RegimePlannedDays,
            s.Macro.KeyRate, s.Macro.Inflation, s.Macro.Growth, s.Macro.RiskAppetite, s.Macro.Crisis,
            s.Macro.DaysSinceCrisis),
        CentralBank = new WorldPersistDto.CentralBankDto(
            s.CentralBank.GovernorName, s.CentralBank.Hawkishness, s.CentralBank.SinceDay),
        Issuers = s.Issuers.ToDictionary(kv => kv.Key, kv => new WorldPersistDto.IssuerDto(
            kv.Value.LogFair, kv.Value.Target, kv.Value.EpsTrend, kv.Value.Distress,
            kv.Value.PendingDividend, kv.Value.Defaulted,
            kv.Value.Smoulder.Select(x => new[] { (double)x.TicksLeft, x.PerTick }).ToList(),
            kv.Value.Management, kv.Value.CeoName, kv.Value.CeoSinceDay)),
        Bonds = s.Bonds.ToDictionary(kv => kv.Key, kv => new WorldPersistDto.BondDto(
            kv.Value.Spread, kv.Value.DaysToMaturity, kv.Value.TargetClean, kv.Value.Accrued,
            kv.Value.Defaulted, kv.Value.Matured)),
        SectorShocks = s.Sectors.ToDictionary(kv => kv.Key, kv => kv.Value.Shock),
        Funds = s.Funds.ToDictionary(kv => kv.Key, kv => new WorldPersistDto.FundDto(
            kv.Value.Divisor, kv.Value.Target)),
        Calendar = s.Calendar
            .Where(c => c.Day >= s.Day - 1) // прошлое не тащим
            .Select(c => new WorldPersistDto.CalendarDto(
                c.Id, c.Type, c.Day, c.TickOfDay, c.Symbol, c.Done, c.ExpectationPublished))
            .ToList(),
        Expectations = s.Expectations.ToDictionary(kv => kv.Key, kv =>
            new WorldPersistDto.ExpectationDto(kv.Value.EventId, kv.Value.Expected, kv.Value.Sigma)),
    };

    /// <summary>Восстанавливает состояние поверх свежесозданного мира.</summary>
    public static void Apply(WorldState s, WorldPersistDto dto)
    {
        s.Day = dto.Day;
        s.TickOfDay = dto.TickOfDay;

        s.Macro.Regime = dto.Macro.Regime;
        s.Macro.RegimeAgeDays = dto.Macro.RegimeAgeDays;
        s.Macro.RegimePlannedDays = dto.Macro.RegimePlannedDays;
        s.Macro.KeyRate = dto.Macro.KeyRate;
        s.Macro.Inflation = dto.Macro.Inflation;
        s.Macro.Growth = dto.Macro.Growth;
        s.Macro.RiskAppetite = dto.Macro.RiskAppetite;
        s.Macro.Crisis = dto.Macro.Crisis;
        s.Macro.DaysSinceCrisis = dto.Macro.DaysSinceCrisis;

        // ЦБ: старый снимок без блока — стартовые значения (уже в конструкторе).
        if (dto.CentralBank is { } cb)
        {
            s.CentralBank.GovernorName = cb.GovernorName;
            s.CentralBank.Hawkishness = cb.Hawkishness;
            s.CentralBank.SinceDay = cb.SinceDay;
        }

        foreach (var (sym, d) in dto.Issuers)
        {
            if (!s.Issuers.TryGetValue(sym, out var st)) continue;
            st.LogFair = d.LogFair;
            st.Target = d.Target;
            st.EpsTrend = d.EpsTrend;
            st.Distress = d.Distress;
            st.PendingDividend = d.PendingDividend;
            st.Defaulted = d.Defaulted;
            st.Smoulder.Clear();
            st.Smoulder.AddRange(d.Smoulder.Select(x => ((int)x[0], x[1])));
            // ДНК-поля: дефолты для старых снимков — стартовые значения из спека.
            st.Management = d.Management ?? st.Spec.MgmtQuality0;
            st.CeoName = string.IsNullOrEmpty(d.CeoName) ? st.Spec.CeoName0 : d.CeoName;
            st.CeoSinceDay = d.CeoSinceDay;
        }

        foreach (var (sym, d) in dto.Bonds)
        {
            if (!s.Bonds.TryGetValue(sym, out var st)) continue;
            st.Spread = d.Spread;
            st.DaysToMaturity = d.DaysToMaturity;
            st.TargetClean = d.TargetClean;
            st.Accrued = d.Accrued;
            st.Defaulted = d.Defaulted;
            st.Matured = d.Matured;
        }

        foreach (var (slug, shock) in dto.SectorShocks)
            if (s.Sectors.TryGetValue(slug, out var st))
                st.Shock = shock;

        foreach (var (sym, d) in dto.Funds)
        {
            if (!s.Funds.TryGetValue(sym, out var st)) continue;
            st.Divisor = d.Divisor;
            st.Target = d.Target;
        }

        s.Calendar.Clear();
        s.Calendar.AddRange(dto.Calendar.Select(c => new CalendarEvent
        {
            Id = c.Id,
            Type = c.Type,
            Day = c.Day,
            TickOfDay = c.TickOfDay,
            Symbol = c.Symbol,
            Done = c.Done,
            ExpectationPublished = c.ExpectationPublished,
        }));

        s.Expectations.Clear();
        foreach (var (k, e) in dto.Expectations)
            s.Expectations[k] = new Expectation { EventId = e.EventId, Expected = e.Expected, Sigma = e.Sigma };
    }
}
