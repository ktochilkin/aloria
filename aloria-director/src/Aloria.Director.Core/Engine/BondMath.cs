using Aloria.Director.Core.Model;

namespace Aloria.Director.Core.Engine;

/// <summary>
/// Математика облигаций. Время сжато: 1 цикл (10 дней) = «год», ставки и
/// купоны — «за цикл». Цены — в процентах номинала (чистая цена, clean).
/// </summary>
public static class BondMath
{
    /// <summary>
    /// Чистая цена, % номинала: дисконтирование купонов и номинала по
    /// непрерывной ставке y за цикл (y = ключевая + кредитный спред, в долях).
    /// </summary>
    /// <param name="couponRatePerCycle">Купонная ставка за цикл, доля (0.09 = 9%).</param>
    /// <param name="couponEveryDays">Периодичность купона, мировых дней.</param>
    /// <param name="daysToMaturity">Дней до погашения.</param>
    /// <param name="yieldPerCycle">Требуемая доходность за цикл, доля.</param>
    /// <param name="daysSinceCoupon">Дней с последнего купона (для положения первого CF).</param>
    public static double CleanPrice(
        double couponRatePerCycle,
        int couponEveryDays,
        int daysToMaturity,
        double yieldPerCycle,
        int daysSinceCoupon = 0)
    {
        if (daysToMaturity <= 0) return 100.0;

        var cycleDays = (double)Universe.CycleDays;
        var couponPct = couponRatePerCycle * 100.0 * (couponEveryDays / cycleDays);

        var price = 0.0;
        // Первый купон — через (couponEveryDays - daysSinceCoupon) дней, дальше по сетке.
        var t = couponEveryDays - Math.Clamp(daysSinceCoupon, 0, couponEveryDays - 1);
        for (; t <= daysToMaturity; t += couponEveryDays)
        {
            var tau = t / cycleDays;
            price += couponPct * Math.Exp(-yieldPerCycle * tau);
        }

        price += 100.0 * Math.Exp(-yieldPerCycle * daysToMaturity / cycleDays);
        return price;
    }

    /// <summary>НКД, % номинала — линейное накопление внутри купонного периода.</summary>
    public static double Accrued(double couponRatePerCycle, int couponEveryDays, int daysSinceCoupon)
    {
        var couponPct = couponRatePerCycle * 100.0 * (couponEveryDays / (double)Universe.CycleDays);
        return couponPct * Math.Clamp(daysSinceCoupon, 0, couponEveryDays) / couponEveryDays;
    }

    /// <summary>Базовый кредитный спред за цикл (доли) по качеству.</summary>
    public static double BaseSpread(CreditQuality q) => q switch
    {
        CreditQuality.Gov => 0.000,
        CreditQuality.A => 0.015,
        CreditQuality.Bbb => 0.030,
        CreditQuality.Bb => 0.060,
        _ => 0.03,
    };

    /// <summary>Цена дефолтнувшего выпуска: recovery, % номинала.</summary>
    public static double RecoveryPrice(Rng rng) => 30.0 + rng.NextDouble() * 15.0;
}
