namespace Aloria.Director.Core.Engine;

/// <summary>
/// Детерминированный генератор случайностей мира. Один seed — один мир:
/// прогон полностью воспроизводим (важно для дебага и балансировки).
/// </summary>
public sealed class Rng
{
    private readonly Random _r;

    public Rng(int seed) => _r = new Random(seed);

    public double NextDouble() => _r.NextDouble();

    public int NextInt(int minInclusive, int maxExclusive) => _r.Next(minInclusive, maxExclusive);

    public bool Chance(double p) => _r.NextDouble() < p;

    /// <summary>Стандартная нормальная (Бокс–Мюллер).</summary>
    public double NextGaussian()
    {
        var u1 = 1.0 - _r.NextDouble();
        var u2 = _r.NextDouble();
        return Math.Sqrt(-2.0 * Math.Log(u1)) * Math.Sin(2.0 * Math.PI * u2);
    }

    public double NextGaussian(double mean, double sigma) => mean + sigma * NextGaussian();

    /// <summary>Логнормальная с параметрами лога.</summary>
    public double NextLogNormal(double mu, double sigma) => Math.Exp(NextGaussian(mu, sigma));

    /// <summary>Парето (xm=1): тяжёлый хвост для серьёзности кризисов.</summary>
    public double NextPareto(double alpha) => Math.Pow(1.0 - _r.NextDouble(), -1.0 / alpha);

    /// <summary>Бета-распределение через отношение гамм.</summary>
    public double NextBeta(double a, double b)
    {
        var x = NextGamma(a);
        var y = NextGamma(b);
        return x / (x + y);
    }

    /// <summary>Гамма (Марсалья–Цанг), θ=1.</summary>
    public double NextGamma(double shape)
    {
        if (shape < 1)
        {
            var u = _r.NextDouble();
            return NextGamma(shape + 1) * Math.Pow(u, 1.0 / shape);
        }

        var d = shape - 1.0 / 3.0;
        var c = 1.0 / Math.Sqrt(9.0 * d);
        while (true)
        {
            double x, v;
            do
            {
                x = NextGaussian();
                v = 1.0 + c * x;
            } while (v <= 0);

            v = v * v * v;
            var uu = _r.NextDouble();
            if (uu < 1.0 - 0.0331 * x * x * x * x) return d * v;
            if (Math.Log(uu) < 0.5 * x * x + d * (1.0 - v + Math.Log(v))) return d * v;
        }
    }

    /// <summary>Пуассон (Кнут) — число приходов событий за тик.</summary>
    public int NextPoisson(double lambda)
    {
        if (lambda <= 0) return 0;
        var l = Math.Exp(-lambda);
        var k = 0;
        var p = 1.0;
        do
        {
            k++;
            p *= _r.NextDouble();
        } while (p > l);
        return k - 1;
    }

    /// <summary>Выбор случайного элемента.</summary>
    public T Pick<T>(IReadOnlyList<T> items) => items[_r.Next(items.Count)];

    /// <summary>Взвешенный выбор.</summary>
    public T PickWeighted<T>(IReadOnlyList<(T Item, double Weight)> items)
    {
        var total = items.Sum(i => i.Weight);
        var x = _r.NextDouble() * total;
        foreach (var (item, w) in items)
        {
            x -= w;
            if (x <= 0) return item;
        }
        return items[^1].Item;
    }
}
