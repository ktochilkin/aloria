using Aloria.Api.Data;
using Aloria.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Services;

/// <summary>Поиск/создание пользователя по AlorPortfolioId, обновление XP/streak.</summary>
public class UserService(AloriaDbContext db)
{
    public async Task<User> EnsureUserAsync(string portfolioId, CancellationToken ct = default)
    {
        var existing = await db.Users.FirstOrDefaultAsync(x => x.AlorPortfolioId == portfolioId, ct);
        if (existing != null) return existing;

        var user = new User
        {
            Id = Guid.NewGuid(),
            AlorPortfolioId = portfolioId,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };
        db.Users.Add(user);
        await db.SaveChangesAsync(ct);
        return user;
    }

    public async Task TouchActivityAsync(User user, CancellationToken ct = default)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var lastActiveDay = user.LastActiveDate is { } last
            ? DateOnly.FromDateTime(last)
            : (DateOnly?)null;

        if (lastActiveDay == today)
        {
            user.LastActiveDate = DateTime.UtcNow;
        }
        else if (lastActiveDay == today.AddDays(-1))
        {
            user.StreakDays += 1;
            user.LastActiveDate = DateTime.UtcNow;
        }
        else
        {
            user.StreakDays = 1;
            user.LastActiveDate = DateTime.UtcNow;
        }
        user.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task AddXpAsync(User user, int xp, CancellationToken ct = default)
    {
        user.Xp += xp;
        user.Level = ComputeLevel(user.Xp);
        user.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    private static int ComputeLevel(int xp)
    {
        // Простая прогрессия: 100, 250, 500, 1000, ...
        if (xp < 100) return 1;
        if (xp < 250) return 2;
        if (xp < 500) return 3;
        if (xp < 1000) return 4;
        if (xp < 2000) return 5;
        if (xp < 4000) return 6;
        return 7 + (xp - 4000) / 2000;
    }
}
