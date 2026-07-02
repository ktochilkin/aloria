namespace Aloria.Director.Core.Engine;

/// <summary>
/// Задел под деривативы: форварды/фьючерсы и опционы (Блэк–Шоулз–Мертон).
/// Время сжато: τ выражается в циклах (1 цикл = «год»), ставки — за цикл.
/// В таблице instruments terex уже есть поля TheorPrice/Volatility/MaturityDate/
/// InitialMargin* — когда деривативы появятся как инструменты, режиссёр будет
/// писать теоретическую цену и волатильность прямо туда.
/// </summary>
public static class DerivativesMath
{
    /// <summary>Форвард/фьючерс: cost of carry. q — «дивидендная доходность» за цикл.</summary>
    public static double Forward(double spot, double ratePerCycle, double divYieldPerCycle, double tauCycles)
        => spot * Math.Exp((ratePerCycle - divYieldPerCycle) * tauCycles);

    /// <summary>Цена колла по BSM.</summary>
    public static double Call(double s, double k, double r, double q, double sigma, double tau)
    {
        if (tau <= 0) return Math.Max(s - k, 0);
        var (d1, d2) = D(s, k, r, q, sigma, tau);
        return s * Math.Exp(-q * tau) * NormCdf(d1) - k * Math.Exp(-r * tau) * NormCdf(d2);
    }

    /// <summary>Цена пута по BSM.</summary>
    public static double Put(double s, double k, double r, double q, double sigma, double tau)
    {
        if (tau <= 0) return Math.Max(k - s, 0);
        var (d1, d2) = D(s, k, r, q, sigma, tau);
        return k * Math.Exp(-r * tau) * NormCdf(-d2) - s * Math.Exp(-q * tau) * NormCdf(-d1);
    }

    /// <summary>Дельта колла/пута.</summary>
    public static double DeltaCall(double s, double k, double r, double q, double sigma, double tau)
        => Math.Exp(-q * tau) * NormCdf(D(s, k, r, q, sigma, tau).D1);

    public static double DeltaPut(double s, double k, double r, double q, double sigma, double tau)
        => Math.Exp(-q * tau) * (NormCdf(D(s, k, r, q, sigma, tau).D1) - 1);

    /// <summary>Вега (на 1.00 волатильности).</summary>
    public static double Vega(double s, double k, double r, double q, double sigma, double tau)
        => s * Math.Exp(-q * tau) * NormPdf(D(s, k, r, q, sigma, tau).D1) * Math.Sqrt(tau);

    /// <summary>Гамма.</summary>
    public static double Gamma(double s, double k, double r, double q, double sigma, double tau)
        => Math.Exp(-q * tau) * NormPdf(D(s, k, r, q, sigma, tau).D1) / (s * sigma * Math.Sqrt(tau));

    private static (double D1, double D2) D(double s, double k, double r, double q, double sigma, double tau)
    {
        var sqrtTau = Math.Sqrt(tau);
        var d1 = (Math.Log(s / k) + (r - q + 0.5 * sigma * sigma) * tau) / (sigma * sqrtTau);
        return (d1, d1 - sigma * sqrtTau);
    }

    public static double NormPdf(double x) => Math.Exp(-0.5 * x * x) / Math.Sqrt(2 * Math.PI);

    /// <summary>Φ(x) через erf (Абрамовиц–Стиган 7.1.26, точность ~1e-7).</summary>
    public static double NormCdf(double x) => 0.5 * (1 + Erf(x / Math.Sqrt(2)));

    private static double Erf(double x)
    {
        var sign = Math.Sign(x);
        x = Math.Abs(x);
        const double a1 = 0.254829592, a2 = -0.284496736, a3 = 1.421413741,
            a4 = -1.453152027, a5 = 1.061405429, p = 0.3275911;
        var t = 1.0 / (1.0 + p * x);
        var y = 1.0 - ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * Math.Exp(-x * x);
        return sign * y;
    }
}
