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
            PracticeEventDispatcher dispatcher,
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

            // Спиральная интеграция: первая позиция = TradeEvent типа
            // PositionOpened с assetClass="any". Закрывает любую цель практики,
            // которая требует «купить что угодно» (Этап 1). Идемпотентно по
            // составному ключу.
            var idemKey = $"first-position:{user.Id}";
            var alreadyDispatched = await db.TradeEvents.AnyAsync(t => t.IdempotencyKey == idemKey, ct);
            if (!alreadyDispatched)
            {
                var ev = new Domain.TradeEvent
                {
                    Id = Guid.NewGuid(),
                    UserId = user.Id,
                    Type = Domain.TradeEventType.PositionOpened,
                    Symbol = string.Empty,
                    AssetClass = "any",
                    Qty = 1m,
                    OccurredAt = DateTime.UtcNow,
                    IdempotencyKey = idemKey,
                    PayloadJson = "{\"source\":\"first-position\"}",
                };
                db.TradeEvents.Add(ev);
                await db.SaveChangesAsync(ct);
                await dispatcher.DispatchAsync(user, ev, ct);
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

        // Оценка карточки recall: упрощённый SM-2. Создаёт ReviewItem при первой
        // оценке, дальше двигает интервал и срок следующего повторения.
        group.MapPost("/reviews/{lessonId:guid}/grade", async (
            Guid lessonId,
            string portfolioId,
            ReviewGradeRequest body,
            AloriaDbContext db,
            UserService users,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(portfolioId))
                return Results.BadRequest("portfolioId required");
            if (!await db.Lessons.AnyAsync(l => l.Id == lessonId, ct))
                return Results.NotFound();

            var user = await users.EnsureUserAsync(portfolioId, ct);
            var item = await db.ReviewItems
                .FirstOrDefaultAsync(r => r.UserId == user.Id && r.LessonId == lessonId, ct);
            if (item == null)
            {
                item = new Domain.ReviewItem
                {
                    Id = Guid.NewGuid(),
                    UserId = user.Id,
                    LessonId = lessonId,
                };
                db.ReviewItems.Add(item);
            }

            if (body.Remembered)
            {
                item.Repetitions += 1;
                item.IntervalDays = item.Repetitions switch
                {
                    1 => 1,
                    2 => 3,
                    _ => (int)Math.Round(item.IntervalDays * item.EaseFactor),
                };
                item.EaseFactor = Math.Min(2.8, item.EaseFactor + 0.05);
            }
            else
            {
                item.Repetitions = 0;
                item.IntervalDays = 1;
                item.EaseFactor = Math.Max(1.3, item.EaseFactor - 0.2);
            }
            if (item.IntervalDays < 1) item.IntervalDays = 1;
            item.NextDueAt = DateTime.UtcNow.AddDays(item.IntervalDays);
            item.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);

            return Results.Ok(new ReviewGradeResultDto(item.NextDueAt, item.IntervalDays));
        });

        // Карточки recall, которые пора повторить (NextDueAt <= сейчас).
        group.MapGet("/reviews/due", async (
            string portfolioId,
            AloriaDbContext db,
            UserService users,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(portfolioId))
                return Results.BadRequest("portfolioId required");
            var user = await users.EnsureUserAsync(portfolioId, ct);
            var now = DateTime.UtcNow;

            var due = await (
                from r in db.ReviewItems
                where r.UserId == user.Id && r.NextDueAt <= now
                join l in db.Lessons on r.LessonId equals l.Id
                join s in db.Sections on l.SectionId equals s.Id
                where l.RecallPrompt != null && l.RecallPrompt != ""
                orderby r.NextDueAt
                select new DueReviewDto(
                    l.Id, s.Slug, l.Slug, l.Title, l.RecallPrompt!, l.RecallAnswer)
            ).ToListAsync(ct);

            return Results.Ok(due);
        });

        return app;
    }
}
