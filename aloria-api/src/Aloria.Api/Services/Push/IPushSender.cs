namespace Aloria.Api.Services.Push;

/// <summary>Готовое к отправке push-сообщение.</summary>
public record PushMessage(string Title, string Body, IReadOnlyDictionary<string, string> Data);

/// <summary>
/// Результат рассылки: сколько сообщений ушло и какие токены оказались мёртвыми
/// (их нужно отключить, чтобы не слать впустую).
/// </summary>
public record PushSendResult(int Sent, IReadOnlyCollection<string> InvalidTokens);

/// <summary>
/// Абстракция канала доставки пушей. Текущая реализация — FCM (см.
/// <see cref="FcmPushSender"/>); за этим интерфейсом можно добавить и другие
/// транспорты, не трогая остальную логику (диспетчер, эндпоинты, типы).
/// </summary>
public interface IPushSender
{
    Task<PushSendResult> SendAsync(
        IReadOnlyCollection<string> tokens,
        PushMessage message,
        CancellationToken ct = default);
}
