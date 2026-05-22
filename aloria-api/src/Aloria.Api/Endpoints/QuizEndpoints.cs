using Aloria.Api.Data;
using Aloria.Api.Dtos;
using Aloria.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Endpoints;

public static class QuizEndpoints
{
    public static IEndpointRouteBuilder MapQuizEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/v1/quizzes").WithTags("Quizzes");

        // Standalone top-up тесты для экрана «Пополнить» (не привязаны к уроку
        // и имеют ненулевую денежную награду).
        app.MapGet("/api/v1/topup/quizzes", async (
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var list = await db.Quizzes
                .Where(q => q.LessonId == null && q.RewardBuyingPower > 0)
                .OrderBy(q => q.Title)
                .Select(q => new
                {
                    q.Id,
                    q.Slug,
                    q.Title,
                    q.Description,
                    q.RewardBuyingPower,
                    QuestionCount = q.Questions.Count,
                })
                .ToListAsync(ct);
            return Results.Ok(list);
        }).WithTags("Quizzes");

        group.MapGet("/{id:guid}", async (
            Guid id,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var quiz = await db.Quizzes
                .Include(q => q.Questions)
                    .ThenInclude(q => q.Options)
                .FirstOrDefaultAsync(q => q.Id == id, ct);
            if (quiz == null) return Results.NotFound();
            var dto = new QuizDto(
                quiz.Id, quiz.Slug, quiz.Title, quiz.Description,
                quiz.RewardXp, quiz.RewardBuyingPower,
                quiz.Questions.OrderBy(q => q.Order).Select(q => new QuizQuestionDto(
                    q.Id, q.Text, q.AllowsMultiple, q.Order,
                    q.Options.OrderBy(o => o.Order)
                        .Select(o => new QuizOptionDto(o.Id, o.Text, o.Order)).ToList()
                )).ToList());
            return Results.Ok(dto);
        });

        group.MapPost("/{id:guid}/attempts", async (
            Guid id,
            string portfolioId,
            QuizAttemptRequest request,
            HttpRequest http,
            QuizService quizzes,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(portfolioId))
                return Results.BadRequest("portfolioId required");
            if (!http.Headers.TryGetValue("Idempotency-Key", out var keyVal)
                || string.IsNullOrWhiteSpace(keyVal.ToString()))
                return Results.BadRequest("Idempotency-Key header required");

            try
            {
                var result = await quizzes.SubmitAttemptAsync(
                    id, portfolioId, request, keyVal.ToString(), ct);
                return Results.Ok(result);
            }
            catch (KeyNotFoundException)
            {
                return Results.NotFound();
            }
        });

        return app;
    }
}
