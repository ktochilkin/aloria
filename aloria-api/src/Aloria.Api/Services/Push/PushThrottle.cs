namespace Aloria.Api.Services.Push;

/// <summary>
/// Троттлинг рассылок по категориям (in-memory, singleton — переживает scoped
/// диспетчеры, но НЕ рестарт процесса: после рестарта окна обнуляются, для
/// прототипа это осознанно допустимо).
///
/// Правила контракта:
/// — worldAlerts / learning: без ограничений;
/// — cycleEvents, calendarDigest: не чаще 1 раза в 10 минут на категорию;
/// — companyNews: не чаще 1 раза в 30 минут; пропущенные копятся счётчиком,
///   при следующей отправке диспетчер дописывает «и ещё N новостей».
/// </summary>
public sealed class PushThrottle
{
    private readonly object _gate = new();
    private readonly Dictionary<PushCategory, DateTime> _lastSentAt = new();
    private readonly Dictionary<PushCategory, int> _skipped = new();

    /// <summary>
    /// Пропускает или откладывает рассылку категории. Возвращает true, если
    /// слать можно; <paramref name="skippedSinceLast"/> — сколько рассылок этой
    /// категории было подавлено с момента последней успешной отправки.
    /// </summary>
    public bool TryPass(PushCategory category, out int skippedSinceLast)
    {
        var interval = IntervalFor(category);
        lock (_gate)
        {
            if (interval == TimeSpan.Zero)
            {
                skippedSinceLast = 0;
                return true;
            }

            var now = DateTime.UtcNow;
            if (_lastSentAt.TryGetValue(category, out var last) && now - last < interval)
            {
                _skipped[category] = _skipped.GetValueOrDefault(category) + 1;
                skippedSinceLast = _skipped[category];
                return false;
            }

            skippedSinceLast = _skipped.GetValueOrDefault(category);
            _skipped[category] = 0;
            _lastSentAt[category] = now;
            return true;
        }
    }

    private static TimeSpan IntervalFor(PushCategory category) => category switch
    {
        PushCategory.CycleEvents => TimeSpan.FromMinutes(10),
        PushCategory.CalendarDigest => TimeSpan.FromMinutes(10),
        PushCategory.CompanyNews => TimeSpan.FromMinutes(30),
        _ => TimeSpan.Zero,
    };
}
