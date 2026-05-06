using Aloria.Api.Data;
using Aloria.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Services;

/// <summary>
/// Проверяет все ачивки против текущего состояния пользователя
/// и открывает те, у которых выполнено условие.
/// </summary>
public class AchievementEvaluator(AloriaDbContext db, GrantService grants)
{
    public async Task EvaluateAsync(User user, CancellationToken ct = default)
    {
        var achievements = await db.Achievements.OrderBy(x => x.Order).ToListAsync(ct);
        if (achievements.Count == 0) return;

        var alreadyUnlocked = await db.AchievementUnlocks
            .Where(x => x.UserId == user.Id)
            .Select(x => x.AchievementId)
            .ToListAsync(ct);
        var unlockedSet = alreadyUnlocked.ToHashSet();

        var lessonsCompleted = await db.LessonCompletions.CountAsync(x => x.UserId == user.Id, ct);
        var quizzesPassed = await db.QuizAttempts.CountAsync(x => x.UserId == user.Id && x.IsPassed, ct);

        foreach (var a in achievements)
        {
            if (unlockedSet.Contains(a.Id)) continue;

            var matched = a.Condition switch
            {
                AchievementCondition.LessonsCompleted => lessonsCompleted >= a.ConditionThreshold,
                AchievementCondition.QuizzesPassed => quizzesPassed >= a.ConditionThreshold,
                AchievementCondition.StreakDays => user.StreakDays >= a.ConditionThreshold,
                AchievementCondition.TotalXp => user.Xp >= a.ConditionThreshold,
                AchievementCondition.FirstPositionOpened => false, // дёрнем позже из торгового события
                _ => false
            };

            if (!matched) continue;

            db.AchievementUnlocks.Add(new AchievementUnlock
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                AchievementId = a.Id,
                UnlockedAt = DateTime.UtcNow,
            });
            await db.SaveChangesAsync(ct);

            if (a.RewardBuyingPower > 0)
            {
                await grants.GrantAsync(
                    user.Id,
                    a.RewardBuyingPower,
                    $"achievement:{a.Code}",
                    $"achievement-{user.Id:N}-{a.Id:N}",
                    ct);
            }

            if (a.RewardXp > 0)
            {
                user.Xp += a.RewardXp;
                user.UpdatedAt = DateTime.UtcNow;
                await db.SaveChangesAsync(ct);
            }
        }
    }
}
