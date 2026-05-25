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
}
