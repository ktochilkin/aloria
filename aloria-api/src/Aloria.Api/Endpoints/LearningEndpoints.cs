using Aloria.Api.Data;
using Aloria.Api.Domain;
using Aloria.Api.Dtos;
using Aloria.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Endpoints;

public static class LearningEndpoints
{
    public static IEndpointRouteBuilder MapLearningEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/v1/learning").WithTags("Learning");

        group.MapGet("/sections", async (
            string? portfolioId,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var sections = await db.Sections
                .OrderBy(s => s.Order)
                .Select(s => new
                {
                    s.Id, s.Slug, s.Title, s.Description, s.Order, s.PrerequisiteSectionId,
                    LessonCount = s.Lessons.Count,
                    LessonIds = s.Lessons.Select(l => l.Id).ToList(),
                })
                .ToListAsync(ct);

            HashSet<Guid> completed = new();
            if (!string.IsNullOrWhiteSpace(portfolioId))
            {
                completed = await db.LessonCompletions
                    .Where(c => c.User!.AlorPortfolioId == portfolioId)
                    .Select(c => c.LessonId)
                    .ToHashSetAsync(ct);
            }

            var dto = sections.Select(s => new SectionDto(
                s.Id, s.Slug, s.Title, s.Description, s.Order, s.PrerequisiteSectionId,
                s.LessonCount,
                s.LessonIds.Count(id => completed.Contains(id))));
            return Results.Ok(dto);
        });

        group.MapGet("/sections/{slug}", async (
            string slug,
            string? portfolioId,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var section = await db.Sections
                .FirstOrDefaultAsync(s => s.Slug == slug, ct);
            if (section == null) return Results.NotFound();

            var lessons = await db.Lessons
                .Where(l => l.SectionId == section.Id)
                .OrderBy(l => l.Order)
                .Select(l => new
                {
                    l.Id, l.Slug, l.Title, l.Description, l.ImageUrl, l.EstimatedMinutes, l.Order,
                    HasQuiz = l.Quiz != null, l.Group
                })
                .ToListAsync(ct);

            HashSet<Guid> completed = new();
            if (!string.IsNullOrWhiteSpace(portfolioId))
            {
                completed = await db.LessonCompletions
                    .Where(c => c.User!.AlorPortfolioId == portfolioId
                        && lessons.Select(l => l.Id).Contains(c.LessonId))
                    .Select(c => c.LessonId)
                    .ToHashSetAsync(ct);
            }

            var dto = lessons.Select(l => new LessonSummaryDto(
                l.Id, l.Slug, l.Title, l.Description, l.ImageUrl, l.EstimatedMinutes,
                l.Order, l.HasQuiz, completed.Contains(l.Id), l.Group));
            return Results.Ok(new
            {
                section = new
                {
                    section.Id, section.Slug, section.Title, section.Description, section.Order,
                    section.PrerequisiteSectionId
                },
                lessons = dto
            });
        });

        group.MapGet("/lessons/{id:guid}", async (
            Guid id,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var lesson = await db.Lessons
                .Include(l => l.Quiz)
                    .ThenInclude(q => q!.Questions)
                        .ThenInclude(q => q.Options)
                .FirstOrDefaultAsync(l => l.Id == id, ct);
            if (lesson == null) return Results.NotFound();

            QuizDto? quizDto = null;
            if (lesson.Quiz != null)
            {
                quizDto = new QuizDto(
                    lesson.Quiz.Id,
                    lesson.Quiz.Slug,
                    lesson.Quiz.Title,
                    lesson.Quiz.Description,
                    lesson.Quiz.RewardXp,
                    lesson.Quiz.RewardBuyingPower,
                    lesson.Quiz.Questions.OrderBy(q => q.Order).Select(q =>
                        new QuizQuestionDto(
                            q.Id, q.Text, q.AllowsMultiple, q.Order,
                            q.Options.OrderBy(o => o.Order)
                                .Select(o => new QuizOptionDto(o.Id, o.Text, o.Order))
                                .ToList()
                        )).ToList());
            }

            return Results.Ok(new LessonDto(
                lesson.Id, lesson.SectionId, lesson.Slug, lesson.Title, lesson.Description,
                lesson.BodyMd, lesson.ImageUrl, lesson.EstimatedMinutes, lesson.AcademicDefinition,
                lesson.Order, lesson.Version, quizDto,
                lesson.PracticeSymbol, lesson.PracticeText,
                lesson.RecallPrompt, lesson.RecallAnswer, lesson.Group));
        });

        group.MapPost("/lessons/{id:guid}/complete", async (
            Guid id,
            string portfolioId,
            AloriaDbContext db,
            UserService users,
            AchievementEvaluator achievements,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(portfolioId)) return Results.BadRequest("portfolioId required");
            var lesson = await db.Lessons.FirstOrDefaultAsync(l => l.Id == id, ct);
            if (lesson == null) return Results.NotFound();

            var user = await users.EnsureUserAsync(portfolioId, ct);
            var existing = await db.LessonCompletions
                .FirstOrDefaultAsync(c => c.UserId == user.Id && c.LessonId == lesson.Id, ct);

            if (existing == null)
            {
                db.LessonCompletions.Add(new LessonCompletion
                {
                    Id = Guid.NewGuid(),
                    UserId = user.Id,
                    LessonId = lesson.Id,
                    LessonVersion = lesson.Version,
                    CompletedAt = DateTime.UtcNow,
                });
                await db.SaveChangesAsync(ct);
                await users.AddXpAsync(user, 10, ct); // фикс XP за урок
                await users.TouchActivityAsync(user, ct);
            }

            // Evaluator идемпотентен — отрабатывает только на ещё не открытые
            // ачивки. Гоним его и на дубликатах: страхует от потерянных
            // апдейтов при гонке быстрых параллельных completions.
            await achievements.EvaluateAsync(user, ct);

            return Results.Ok(new { isCompleted = true });
        });

        return app;
    }
}
