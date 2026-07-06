namespace Aloria.Api.Services.Push;

/// <summary>
/// Виды пушей. Добавить новый вид = добавить значение сюда и ветку в
/// <see cref="PushDispatcher"/> (заголовок/текст + deep-link route). Остальная
/// инфраструктура (токены, отправка, эндпоинты) не меняется.
/// </summary>
public enum NotificationType
{
    Test,
    AchievementUnlocked,
    ReviewDue,
    StreakReminder,

    /// Ручная рассылка из админки: заголовок/текст и (опц.) route задаёт оператор.
    Custom,

    // --- Экономический мир (категорийные рассылки, см. PushCategory) ---

    /// Срочное в мире: кризис, ставка ЦБ, дефолт, смена главы ЦБ.
    WorldAlert,

    /// Смена фазы экономического цикла / старт нового цикла.
    CycleEvent,

    /// Новость компании (продукты, отчёты, смена CEO и т.п.).
    CompanyNews,

    /// Дайджест событий календаря при открытии мирового дня.
    CalendarDigest,
}
