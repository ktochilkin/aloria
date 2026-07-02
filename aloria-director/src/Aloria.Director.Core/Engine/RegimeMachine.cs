using Aloria.Director.Core.Model;

namespace Aloria.Director.Core.Engine;

/// <summary>
/// Полумарковская машина макрорежимов: петля
/// расширение → перегрев → рецессия → восстановление, с редкими «срезками»
/// (мягкая посадка, двойное дно) и кризисным оверлеем.
/// </summary>
public static class RegimeMachine
{
    /// <summary>Средние значения макрофакторов по режимам.</summary>
    public static (double Growth, double Inflation, double RiskAppetite) Means(Regime r) => r switch
    {
        Regime.Expansion => (3.5, 4.0, 0.5),
        Regime.Peak => (4.5, 7.5, 0.15),
        Regime.Recession => (-2.5, 3.0, -0.6),
        Regime.Recovery => (1.5, 2.5, 0.2),
        _ => (2.0, 4.0, 0.0),
    };

    /// <summary>Множитель волатильности по режиму (кризис добавляет сверху).</summary>
    public static double VolMultiplier(Regime r, bool crisis)
    {
        var m = r switch
        {
            Regime.Expansion => 1.0,
            Regime.Peak => 1.25,
            Regime.Recession => 1.7,
            Regime.Recovery => 1.2,
            _ => 1.0,
        };
        return crisis ? m * 2.0 : m;
    }

    /// <summary>Плановая длительность режима, дней (Gamma, клип разумным окном).</summary>
    public static int SampleDuration(Regime r, Rng rng)
    {
        var (mean, min, max) = r switch
        {
            Regime.Expansion => (14.0, 6, 30),
            Regime.Peak => (6.0, 3, 12),
            Regime.Recession => (8.0, 4, 16),
            Regime.Recovery => (7.0, 3, 14),
            _ => (8.0, 4, 16),
        };
        // Gamma с k=4 → CV 50%
        var d = rng.NextGamma(4.0) * (mean / 4.0);
        return Math.Clamp((int)Math.Round(d), min, max);
    }

    /// <summary>Следующий режим: по кругу с редкими срезками.</summary>
    public static Regime SampleNext(Regime current, Rng rng) => current switch
    {
        // Срезка: перегрев минуя пик невозможен, но расширение может рухнуть сразу в рецессию.
        Regime.Expansion => rng.Chance(0.82) ? Regime.Peak : Regime.Recession,
        // Мягкая посадка: перегрев изредка возвращается в расширение без рецессии.
        Regime.Peak => rng.Chance(0.85) ? Regime.Recession : Regime.Expansion,
        // Двойное дно: восстановление изредка проваливается обратно.
        Regime.Recession => rng.Chance(0.88) ? Regime.Recovery : Regime.Expansion,
        Regime.Recovery => rng.Chance(0.90) ? Regime.Expansion : Regime.Recession,
        _ => Regime.Expansion,
    };

    /// <summary>
    /// Дневной шаг макрофакторов: Орнштейн–Уленбек к режимным средним.
    /// Возвращает true, если день сменил режим.
    /// </summary>
    public static bool DailyStep(MacroState m, Rng rng)
    {
        var regimeChanged = false;
        m.RegimeAgeDays++;
        if (m.RegimeAgeDays >= m.RegimePlannedDays)
        {
            m.Regime = SampleNext(m.Regime, rng);
            m.RegimeAgeDays = 0;
            m.RegimePlannedDays = SampleDuration(m.Regime, rng);
            regimeChanged = true;

            // Выход из рецессии гасит кризисный оверлей.
            if (m.Crisis && m.Regime is Regime.Recovery or Regime.Expansion)
                m.Crisis = false;
        }

        var (g, pi, rho) = Means(m.Regime);
        const double theta = 0.25;
        m.Growth += theta * (g - m.Growth) + rng.NextGaussian(0, 0.30);
        m.Inflation += theta * (pi - m.Inflation) + rng.NextGaussian(0, 0.25);
        m.Inflation = Math.Max(0, m.Inflation);
        m.RiskAppetite = Math.Clamp(
            m.RiskAppetite + theta * (rho - m.RiskAppetite) + rng.NextGaussian(0, 0.08), -1, 1);

        return regimeChanged;
    }

    /// <summary>
    /// Решение «ЦБ Алории» по ставке (правило Тейлора с шагом 0.25 п.п.).
    /// Возвращает изменение ставки в п.п. за цикл.
    /// </summary>
    public static double PolicyDelta(MacroState m)
    {
        var raw = 0.5 * (m.Inflation - 4.0) - 0.25 * (m.Growth - 2.0);
        var stepped = Math.Round(raw * 4, MidpointRounding.AwayFromZero) / 4.0;
        return Math.Clamp(stepped, -2.0, 2.0);
    }
}
