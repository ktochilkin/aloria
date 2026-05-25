using Aloria.Api.Data;
using Aloria.Api.Domain;
using Aloria.Api.Dtos;
using Aloria.Api.Services;
using Aloria.Api.Services.Push;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Endpoints;

public static class DeviceEndpoints
{
    public static IEndpointRouteBuilder MapDeviceEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/v1/me/devices").WithTags("Devices");

        // Регистрация / обновление push-токена устройства за пользователем.
        group.MapPost("", async (
            string portfolioId,
            DeviceRegisterRequest body,
            AloriaDbContext db,
            UserService users,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(portfolioId))
                return Results.BadRequest("portfolioId required");
            if (string.IsNullOrWhiteSpace(body.Token))
                return Results.BadRequest("token required");

            var user = await users.EnsureUserAsync(portfolioId, ct);
            var existing = await db.DeviceTokens.FirstOrDefaultAsync(d => d.Token == body.Token, ct);
            if (existing == null)
            {
                db.DeviceTokens.Add(new DeviceToken
                {
                    Id = Guid.NewGuid(),
                    UserId = user.Id,
                    Token = body.Token,
                    Platform = body.Platform ?? string.Empty,
                });
            }
            else
            {
                existing.UserId = user.Id;
                if (!string.IsNullOrWhiteSpace(body.Platform)) existing.Platform = body.Platform!;
                existing.Disabled = false;
                existing.LastSeenAt = DateTime.UtcNow;
            }
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { registered = true });
        });

        // Отписка устройства (logout / выключение пушей).
        group.MapDelete("/{token}", async (
            string token,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            await db.DeviceTokens.Where(d => d.Token == token).ExecuteDeleteAsync(ct);
            return Results.Ok(new { removed = true });
        });

        // Dev: отправить себе тестовый пуш (проверка всей цепочки доставки).
        group.MapPost("/test", async (
            string portfolioId,
            AloriaDbContext db,
            UserService users,
            PushDispatcher dispatcher,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(portfolioId))
                return Results.BadRequest("portfolioId required");
            var user = await users.EnsureUserAsync(portfolioId, ct);
            await dispatcher.DispatchAsync(user.Id, NotificationType.Test, null, ct);
            return Results.Ok(new { dispatched = true });
        });

        return app;
    }
}
