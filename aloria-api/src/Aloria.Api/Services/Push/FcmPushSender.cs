using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Aloria.Api.Services.Push;

/// <summary>
/// Отправка пушей через FCM HTTP v1. Access token получаем сами по
/// service-account (RSA-подписанный JWT → OAuth), без дополнительных
/// NuGet-зависимостей. Если FCM не сконфигурирован (нет ProjectId/ключа) —
/// отправитель безопасный no-op: приложение поднимается и без секретов.
///
/// Конфиг (appsettings / env):
///   Fcm:ProjectId           — id Firebase-проекта
///   Fcm:ServiceAccountPath  — путь к service-account JSON (НЕ в репозитории)
/// </summary>
public class FcmPushSender : IPushSender
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(15) };

    private readonly ILogger<FcmPushSender> _log;
    private readonly string? _projectId;
    private readonly ServiceAccount? _sa;
    private readonly SemaphoreSlim _tokenLock = new(1, 1);

    private string? _accessToken;
    private DateTime _accessTokenExpUtc;

    public FcmPushSender(IConfiguration config, ILogger<FcmPushSender> log)
    {
        _log = log;
        _projectId = config["Fcm:ProjectId"];
        var path = config["Fcm:ServiceAccountPath"];
        if (!string.IsNullOrWhiteSpace(path) && File.Exists(path))
        {
            try
            {
                _sa = JsonSerializer.Deserialize<ServiceAccount>(File.ReadAllText(path));
            }
            catch (Exception ex)
            {
                _log.LogError(ex, "Не удалось прочитать FCM service account: {Path}", path);
            }
        }

        if (!IsConfigured)
        {
            _log.LogWarning(
                "FCM не сконфигурирован (Fcm:ProjectId / Fcm:ServiceAccountPath). "
                + "Отправка пушей — no-op.");
        }
    }

    private bool IsConfigured =>
        _sa is { private_key.Length: > 0 } && !string.IsNullOrWhiteSpace(_projectId);

    public async Task<PushSendResult> SendAsync(
        IReadOnlyCollection<string> tokens, PushMessage message, CancellationToken ct = default)
    {
        if (!IsConfigured || tokens.Count == 0)
        {
            return new PushSendResult(0, Array.Empty<string>());
        }

        var access = await GetAccessTokenAsync(ct);
        if (access == null) return new PushSendResult(0, Array.Empty<string>());

        var sent = 0;
        var invalid = new List<string>();

        foreach (var token in tokens)
        {
            var payload = new
            {
                message = new
                {
                    token,
                    notification = new { title = message.Title, body = message.Body },
                    data = message.Data,
                },
            };

            using var req = new HttpRequestMessage(
                HttpMethod.Post,
                $"https://fcm.googleapis.com/v1/projects/{_projectId}/messages:send")
            {
                Content = new StringContent(
                    JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json"),
            };
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", access);

            try
            {
                var resp = await Http.SendAsync(req, ct);
                if (resp.IsSuccessStatusCode)
                {
                    sent++;
                }
                else if (resp.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.BadRequest)
                {
                    // UNREGISTERED / INVALID_ARGUMENT — токен мёртв, отключаем.
                    invalid.Add(token);
                }
                else
                {
                    _log.LogWarning("FCM send: {Status}", resp.StatusCode);
                }
            }
            catch (Exception ex)
            {
                _log.LogWarning(ex, "FCM send error");
            }
        }

        return new PushSendResult(sent, invalid);
    }

    private async Task<string?> GetAccessTokenAsync(CancellationToken ct)
    {
        if (_accessToken != null && DateTime.UtcNow < _accessTokenExpUtc.AddMinutes(-2))
        {
            return _accessToken;
        }

        await _tokenLock.WaitAsync(ct);
        try
        {
            if (_accessToken != null && DateTime.UtcNow < _accessTokenExpUtc.AddMinutes(-2))
            {
                return _accessToken;
            }

            var sa = _sa!;
            var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var header = B64Url(JsonSerializer.SerializeToUtf8Bytes(new { alg = "RS256", typ = "JWT" }));
            var claims = B64Url(JsonSerializer.SerializeToUtf8Bytes(new
            {
                iss = sa.client_email,
                scope = "https://www.googleapis.com/auth/firebase.messaging",
                aud = sa.token_uri,
                iat = now,
                exp = now + 3600,
            }));
            var unsigned = $"{header}.{claims}";

            using var rsa = RSA.Create();
            rsa.ImportFromPem(sa.private_key);
            var signature = rsa.SignData(
                Encoding.ASCII.GetBytes(unsigned), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
            var jwt = $"{unsigned}.{B64Url(signature)}";

            using var tokenReq = new HttpRequestMessage(HttpMethod.Post, sa.token_uri)
            {
                Content = new FormUrlEncodedContent(new Dictionary<string, string>
                {
                    ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
                    ["assertion"] = jwt,
                }),
            };

            var resp = await Http.SendAsync(tokenReq, ct);
            if (!resp.IsSuccessStatusCode)
            {
                _log.LogError("FCM token exchange: {Status}", resp.StatusCode);
                return null;
            }

            using var doc = JsonDocument.Parse(await resp.Content.ReadAsStringAsync(ct));
            _accessToken = doc.RootElement.GetProperty("access_token").GetString();
            var expiresIn = doc.RootElement.TryGetProperty("expires_in", out var e) ? e.GetInt32() : 3600;
            _accessTokenExpUtc = DateTime.UtcNow.AddSeconds(expiresIn);
            return _accessToken;
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "FCM token exchange error");
            return null;
        }
        finally
        {
            _tokenLock.Release();
        }
    }

    private static string B64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    /// Поля service-account JSON названы как ключи в файле — System.Text.Json
    /// сопоставит их без атрибутов.
    private sealed class ServiceAccount
    {
        public string client_email { get; set; } = string.Empty;
        public string private_key { get; set; } = string.Empty;
        public string token_uri { get; set; } = "https://oauth2.googleapis.com/token";
    }
}
