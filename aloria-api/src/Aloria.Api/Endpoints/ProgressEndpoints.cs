using Aloria.Api.Data;
using Aloria.Api.Dtos;
using Aloria.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Endpoints;

public static class ProgressEndpoints
{
    public static IEndpointRouteBuilder MapProgressEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/v1/me").WithTags("Me");

        group.MapGet("/progress", async (
            string portfolioId,
            AloriaDbContext db,
            UserService users,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(portfolioId))
                return Results.BadRequest("portfolioId required");

            var user = await users.EnsureUserAsync(portfolioId, ct);

            var lessonsCompleted = await db.LessonCompletions.CountAsync(c => c.UserId == user.Id, ct);
            var quizzesPassed = await db.QuizAttempts.CountAsync(a => a.UserId == user.Id && a.IsPassed, ct);
            var bonus = await db.BuyingPowerGrants
                .Where(g => g.UserId == user.Id && g.Status == "committed")
                .SumAsync(g => (decimal?)g.Amount, ct) ?? 0;
            var unlocked = await db.AchievementUnlocks.CountAsync(u => u.UserId == user.Id, ct);
            var total = await db.Achievements.CountAsync(ct);

            return Results.Ok(new ProgressDto(
                user.Xp, user.Level, user.StreakDays,
                lessonsCompleted, quizzesPassed, bonus,
                unlocked, total));
        });

        group.MapGet("/achievements", async (
            string portfolioId,
            AloriaDbContext db,
            UserService users,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(portfolioId))
                return Results.BadRequest("portfolioId required");

            var user = await users.EnsureUserAsync(portfolioId, ct);
            var achievements = await db.Achievements.OrderBy(x => x.Order).ToListAsync(ct);
            var unlocks = await db.AchievementUnlocks
                .Where(u => u.UserId == user.Id)
                .ToDictionaryAsync(u => u.AchievementId, ct);

            var lessonsCompleted = await db.LessonCompletions.CountAsync(x => x.UserId == user.Id, ct);
            var quizzesPassed = await db.QuizAttempts.CountAsync(x => x.UserId == user.Id && x.IsPassed, ct);

            var dto = achievements.Select(a =>
            {
                int? progress = a.Condition switch
                {
                    Domain.AchievementCondition.LessonsCompleted => lessonsCompleted,
                    Domain.AchievementCondition.QuizzesPassed => quizzesPassed,
                    Domain.AchievementCondition.StreakDays => user.StreakDays,
                    Domain.AchievementCondition.TotalXp => user.Xp,
                    _ => null
                };
                var unlock = unlocks.GetValueOrDefault(a.Id);
                return new AchievementDto(
                    a.Id, a.Code, a.Title, a.Description, a.IconName,
                    a.RewardXp, a.RewardBuyingPower,
                    unlock != null,
                    unlock?.UnlockedAt,
                    progress,
                    a.ConditionThreshold);
            });

            return Results.Ok(dto);
        });

        group.MapPost("/events/first-position", async (
            string portfolioId,
            AloriaDbContext db,
            UserService users,
            AchievementEvaluator achievements,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(portfolioId))
                return Results.BadRequest("portfolioId required");
            var user = await users.EnsureUserAsync(portfolioId, ct);
            var existing = await db.UserEvents.AnyAsync(
                e => e.UserId == user.Id && e.Code == "first_position", ct);
            if (!existing)
            {
                db.UserEvents.Add(new Domain.UserEvent
                {
                    Id = Guid.NewGuid(),
                    UserId = user.Id,
                    Code = "first_position",
                    OccurredAt = DateTime.UtcNow,
                });
                await db.SaveChangesAsync(ct);
                await achievements.EvaluateAsync(user, ct);
            }
            return Results.Ok(new { recorded = !existing });
        });

        group.MapGet("/grants", async (
            string portfolioId,
            AloriaDbContext db,
            UserService users,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(portfolioId))
                return Results.BadRequest("portfolioId required");

            var user = await users.EnsureUserAsync(portfolioId, ct);
            var grants = await db.BuyingPowerGrants
                .Where(g => g.UserId == user.Id)
                .OrderByDescending(g => g.CreatedAt)
                .Select(g => new GrantDto(g.Id, g.Amount, g.Reason, g.Status, g.CreatedAt, g.CommittedAt))
                .ToListAsync(ct);
            return Results.Ok(grants);
        });

        return app;
    }
}
