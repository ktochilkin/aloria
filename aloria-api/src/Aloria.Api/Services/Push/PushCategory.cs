namespace Aloria.Api.Services.Push;

/// <summary>
/// Категории пушей (битовая маска в <see cref="Domain.DeviceToken.Categories"/>).
/// Контракт единый с приложением (экран «Уведомления»): ключи, флаги и дефолт
/// не менять без синхронного изменения на клиенте.
/// </summary>
[Flags]
public enum PushCategory
{
    None = 0,

    /// Срочное в мире: кризисы, решение ЦБ по ставке, дефолт эмитента, смена главы ЦБ.
    WorldAlerts = 1,

    /// Экономический цикл: смена фазы, старт нового цикла.
    CycleEvents = 2,

    /// Новости компаний: продукты, отчёты, смены CEO и прочее (по умолчанию выключено).
    CompanyNews = 4,

    /// Календарь дня: один дайджест при открытии мирового дня.
    CalendarDigest = 8,

    /// Обучение: ачивки, повторения, стрики.
    Learning = 16,
}

/// <summary>Константы контракта пуш-категорий.</summary>
public static class PushCategories
{
    /// Дефолтная маска нового устройства: всё, кроме новостей компаний
    /// (worldAlerts + cycleEvents + calendarDigest + learning = 27).
    public const int DefaultMask = (int)(PushCategory.WorldAlerts
        | PushCategory.CycleEvents
        | PushCategory.CalendarDigest
        | PushCategory.Learning);
}
