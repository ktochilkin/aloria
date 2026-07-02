namespace Aloria.Director.Core.Engine;

/// <summary>Сериализуемое состояние генератора (для точного просчёта будущего).</summary>
/// <remarks>ulong как строки: JSON-число теряет точность выше 2^53 в части парсеров.</remarks>
public sealed record RngState(string State, string Inc);

/// <summary>
/// Детерминированный генератор случайностей мира — PCG32 с экспортируемым
/// состоянием. Один seed — один мир; снимок состояния позволяет ветке
/// продолжить ТОТ ЖЕ поток костей (точный просчёт будущего) и делает рестарты
/// сервиса бесшовными. System.Random не подходит: его состояние не достать.
/// </summary>
public sealed class Rng
{
    private ulong _state;
    private ulong _inc;

    public Rng(int seed) => Reset(seed);

    /// <summary>
    /// Перезапуск потока костей с нового зерна НА МЕСТЕ (все держатели ссылки
    /// продолжают с новым потоком) — «перебросить будущее» от текущего момента.
    /// </summary>
    public void Reset(int seed)
    {
        // Инициализация через SplitMix64 — размазывает даже соседние seed'ы.
        var s = unchecked((ulong)seed * 0x9E3779B97F4A7C15UL + 0xBF58476D1CE4E5B9UL);
        _state = SplitMix(ref s);
        _inc = SplitMix(ref s) | 1UL; // инкремент обязан быть нечётным
    }

    public Rng(RngState state)
    {
        _state = ulong.Parse(state.State);
        _inc = ulong.Parse(state.Inc);
    }

    /// <summary>Снимок состояния — для world_state и точного просчёта.</summary>
    public RngState Export() => new(_state.ToString(), _inc.ToString());

    private static ulong SplitMix(ref ulong x)
    {
        x += 0x9E3779B97F4A7C15UL;
        var z = x;
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
        return z ^ (z >> 31);
    }

    private uint NextUInt()
    {
        var old = _state;
        _state = unchecked(old * 6364136223846793005UL + _inc);
        var xorshifted = (uint)(((old >> 18) ^ old) >> 27);
        var rot = (int)(old >> 59);
        return (xorshifted >> rot) | (xorshifted << (-rot & 31));
    }

    /// <summary>Равномерная в [0, 1) с 53-битной точностью.</summary>
    public double NextDouble()
    {
        var hi = (ulong)NextUInt();
        var lo = (ulong)NextUInt();
        return (((hi << 21) | (lo >> 11)) & ((1UL << 53) - 1)) * (1.0 / (1UL << 53));
    }

    public int NextInt(int minInclusive, int maxExclusive)
        => maxExclusive <= minInclusive
            ? minInclusive
            : minInclusive + (int)(NextDouble() * (maxExclusive - minInclusive));

    public bool Chance(double p) => NextDouble() < p;

    /// <summary>Стандартная нормальная (Бокс–Мюллер).</summary>
    public double NextGaussian()
    {
        var u1 = 1.0 - NextDouble();
        var u2 = NextDouble();
        return Math.Sqrt(-2.0 * Math.Log(u1)) * Math.Sin(2.0 * Math.PI * u2);
    }

    public double NextGaussian(double mean, double sigma) => mean + sigma * NextGaussian();

    /// <summary>Логнормальная с параметрами лога.</summary>
    public double NextLogNormal(double mu, double sigma) => Math.Exp(NextGaussian(mu, sigma));

    /// <summary>Парето (xm=1): тяжёлый хвост для серьёзности кризисов.</summary>
    public double NextPareto(double alpha) => Math.Pow(1.0 - NextDouble(), -1.0 / alpha);

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
            var u = NextDouble();
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
            var uu = NextDouble();
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
            p *= NextDouble();
        } while (p > l);
        return k - 1;
    }

    /// <summary>Выбор случайного элемента.</summary>
    public T Pick<T>(IReadOnlyList<T> items) => items[NextInt(0, items.Count)];

    /// <summary>Взвешенный выбор.</summary>
    public T PickWeighted<T>(IReadOnlyList<(T Item, double Weight)> items)
    {
        var total = items.Sum(i => i.Weight);
        var x = NextDouble() * total;
        foreach (var (item, w) in items)
        {
            x -= w;
            if (x <= 0) return item;
        }
        return items[^1].Item;
    }
}
