using System.Text.Json;
using Aloria.Api.Data;
using Aloria.Api.Domain;
using Aloria.Api.Dtos;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Services;

/// <summary>Серверная валидация теста + запись попытки + начисление награды.</summary>
public class QuizService(
    AloriaDbContext db,
    UserService users,
    GrantService grants,
    AchievementEvaluator achievements)
{
    public async Task<QuizAttemptResult> SubmitAttemptAsync(
        Guid quizId,
        string portfolioId,
        QuizAttemptRequest request,
        string idempotencyKey,
        CancellationToken ct = default)
    {
        var quiz = await db.Quizzes
            .Include(q => q.Questions)
                .ThenInclude(q => q.Options)
            .FirstOrDefaultAsync(q => q.Id == quizId, ct)
            ?? throw new KeyNotFoundException($"Quiz {quizId} not found");

        var existing = await db.QuizAttempts
            .FirstOrDefaultAsync(a => a.IdempotencyKey == idempotencyKey, ct);
        if (existing != null)
        {
            return BuildResult(quiz, request, existing);
        }

        var user = await users.EnsureUserAsync(portfolioId, ct);

        var (correctCount, perQuestion) = Evaluate(quiz, request);
        var isPassed = correctCount == quiz.Questions.Count && quiz.Questions.Count > 0;

        var attempt = new QuizAttempt
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            QuizId = quiz.Id,
            IsPassed = isPassed,
            AnswersJson = JsonSerializer.Serialize(request.Answers),
            IdempotencyKey = idempotencyKey,
            AwardedXp = isPassed ? quiz.RewardXp : 0,
            AwardedBuyingPower = isPassed ? quiz.RewardBuyingPower : 0,
            AttemptedAt = DateTime.UtcNow,
        };
        db.QuizAttempts.Add(attempt);
        await db.SaveChangesAsync(ct);

        string? grantStatus = null;
        if (isPassed)
        {
            await users.AddXpAsync(user, quiz.RewardXp, ct);
            await users.TouchActivityAsync(user, ct);
            if (quiz.RewardBuyingPower > 0)
            {
                var grant = await grants.GrantAsync(
                    user.Id,
                    quiz.RewardBuyingPower,
                    $"quiz:{quiz.Slug}",
                    $"quiz-{attempt.Id}",
                    ct);
                grantStatus = grant.Status;
            }
            await achievements.EvaluateAsync(user, ct);
        }

        return new QuizAttemptResult(
            isPassed,
            correctCount,
            quiz.Questions.Count,
            attempt.AwardedXp,
            attempt.AwardedBuyingPower,
            grantStatus,
            perQuestion);
    }

    private static (int CorrectCount, List<QuestionResultDto> Per) Evaluate(
        Quiz quiz,
        QuizAttemptRequest req)
    {
        var per = new List<QuestionResultDto>();
        var correctCount = 0;
        foreach (var q in quiz.Questions.OrderBy(x => x.Order))
        {
            var correctIds = q.Options.Where(o => o.IsCorrect).Select(o => o.Id).ToHashSet();
            var picked = req.Answers
                .FirstOrDefault(a => a.QuestionId == q.Id)
                ?.SelectedOptionIds
                .ToHashSet() ?? new HashSet<Guid>();
            var isCorrect = correctIds.SetEquals(picked) && correctIds.Count > 0;
            if (isCorrect) correctCount++;
            var firstWrongOrSelected = q.Options
                .FirstOrDefault(o => o.IsCorrect && !string.IsNullOrWhiteSpace(o.Explanation));
            per.Add(new QuestionResultDto(
                q.Id,
                isCorrect,
                correctIds.ToList(),
                firstWrongOrSelected?.Explanation));
        }
        return (correctCount, per);
    }

    private static QuizAttemptResult BuildResult(Quiz quiz, QuizAttemptRequest req, QuizAttempt attempt)
    {
        var (correct, per) = Evaluate(quiz, req);
        return new QuizAttemptResult(
            attempt.IsPassed,
            correct,
            quiz.Questions.Count,
            attempt.AwardedXp,
            attempt.AwardedBuyingPower,
            attempt.IsPassed ? "committed" : null,
            per);
    }
}
