using Aloria.Api.Data;
using Aloria.Api.Domain;
using Aloria.Api.Dtos;
using Aloria.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Endpoints;

public static class AdminEndpoints
{
    public static IEndpointRouteBuilder MapAdminEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/admin").WithTags("Admin");

        MapSections(group);
        MapLessons(group);
        MapQuizzes(group);
        MapAchievements(group);
        MapUsers(group);
        MapAudit(group);
        MapUploads(group);

        return app;
    }

    private static void MapSections(RouteGroupBuilder group)
    {
        group.MapGet("/sections", async (AloriaDbContext db, CancellationToken ct) =>
        {
            var list = await db.Sections
                .OrderBy(s => s.Order)
                .Select(s => new AdminSectionDto(
                    s.Id, s.Slug, s.Title, s.Description, s.Order, s.PrerequisiteSectionId,
                    s.Lessons.Count, s.CreatedAt, s.UpdatedAt))
                .ToListAsync(ct);
            return Results.Ok(list);
        });

        group.MapPost("/sections", async (
            AdminSectionInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var section = new Section
            {
                Id = Guid.NewGuid(),
                Slug = input.Slug,
                Title = input.Title,
                Description = input.Description,
                Order = input.Order,
                PrerequisiteSectionId = input.PrerequisiteSectionId,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
            db.Sections.Add(section);
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("create", "Section", section.Id, section.Slug, ct);
            return Results.Created($"/api/admin/sections/{section.Id}", section.Id);
        });

        group.MapPut("/sections/{id:guid}", async (
            Guid id,
            AdminSectionInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var section = await db.Sections.FindAsync([id], ct);
            if (section == null) return Results.NotFound();
            section.Slug = input.Slug;
            section.Title = input.Title;
            section.Description = input.Description;
            section.Order = input.Order;
            section.PrerequisiteSectionId = input.PrerequisiteSectionId;
            section.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("update", "Section", id, section.Slug, ct);
            return Results.NoContent();
        });

        group.MapDelete("/sections/{id:guid}", async (
            Guid id,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var section = await db.Sections.FindAsync([id], ct);
            if (section == null) return Results.NotFound();
            db.Sections.Remove(section);
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("delete", "Section", id, section.Slug, ct);
            return Results.NoContent();
        });
    }

    private static void MapLessons(RouteGroupBuilder group)
    {
        group.MapGet("/lessons", async (
            Guid? sectionId,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var query = db.Lessons.AsQueryable();
            if (sectionId.HasValue)
                query = query.Where(l => l.SectionId == sectionId.Value);
            var list = await query
                .OrderBy(l => l.SectionId)
                .ThenBy(l => l.Order)
                .Select(l => new AdminLessonListDto(
                    l.Id, l.SectionId, l.Slug, l.Title, l.Description,
                    l.EstimatedMinutes, l.Order, l.Version,
                    l.Quiz != null,
                    l.UpdatedAt))
                .ToListAsync(ct);
            return Results.Ok(list);
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
            AdminQuizDto? quizDto = lesson.Quiz == null ? null : new AdminQuizDto(
                lesson.Quiz.Id, lesson.Quiz.LessonId, lesson.Quiz.Slug, lesson.Quiz.Title,
                lesson.Quiz.Description, lesson.Quiz.RewardXp, lesson.Quiz.RewardBuyingPower,
                lesson.Quiz.Questions.OrderBy(q => q.Order).Select(q => new AdminQuizQuestionDto(
                    q.Id, q.Text, q.AllowsMultiple, q.Order,
                    q.Options.OrderBy(o => o.Order).Select(o => new AdminQuizOptionDto(
                        o.Id, o.Text, o.IsCorrect, o.Explanation, o.Order)).ToList()
                )).ToList());
            return Results.Ok(new AdminLessonDto(
                lesson.Id, lesson.SectionId, lesson.Slug, lesson.Title, lesson.Description,
                lesson.BodyMd, lesson.ImageUrl, lesson.EstimatedMinutes,
                lesson.AcademicDefinition, lesson.Order, lesson.Version, quizDto));
        });

        group.MapPost("/lessons", async (
            AdminLessonInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var lesson = new Lesson
            {
                Id = Guid.NewGuid(),
                SectionId = input.SectionId,
                Slug = input.Slug,
                Title = input.Title,
                Description = input.Description,
                BodyMd = input.BodyMd,
                ImageUrl = input.ImageUrl,
                EstimatedMinutes = input.EstimatedMinutes,
                AcademicDefinition = input.AcademicDefinition,
                Order = input.Order,
                Version = 1,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
            db.Lessons.Add(lesson);
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("create", "Lesson", lesson.Id, lesson.Slug, ct);
            return Results.Created($"/api/admin/lessons/{lesson.Id}", lesson.Id);
        });

        group.MapPut("/lessons/{id:guid}", async (
            Guid id,
            AdminLessonInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var lesson = await db.Lessons.FindAsync([id], ct);
            if (lesson == null) return Results.NotFound();
            lesson.SectionId = input.SectionId;
            lesson.Slug = input.Slug;
            lesson.Title = input.Title;
            lesson.Description = input.Description;
            lesson.BodyMd = input.BodyMd;
            lesson.ImageUrl = input.ImageUrl;
            lesson.EstimatedMinutes = input.EstimatedMinutes;
            lesson.AcademicDefinition = input.AcademicDefinition;
            lesson.Order = input.Order;
            lesson.Version += 1;
            lesson.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("update", "Lesson", id, lesson.Slug, ct);
            return Results.NoContent();
        });

        group.MapDelete("/lessons/{id:guid}", async (
            Guid id,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var lesson = await db.Lessons.FindAsync([id], ct);
            if (lesson == null) return Results.NotFound();
            db.Lessons.Remove(lesson);
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("delete", "Lesson", id, lesson.Slug, ct);
            return Results.NoContent();
        });
    }

    private static void MapQuizzes(RouteGroupBuilder group)
    {
        group.MapGet("/quizzes", async (AloriaDbContext db, CancellationToken ct) =>
        {
            var list = await db.Quizzes
                .OrderBy(q => q.Title)
                .Select(q => new
                {
                    q.Id, q.LessonId, q.Slug, q.Title, q.Description,
                    q.RewardXp, q.RewardBuyingPower,
                    QuestionCount = q.Questions.Count,
                    q.UpdatedAt,
                })
                .ToListAsync(ct);
            return Results.Ok(list);
        });

        group.MapGet("/quizzes/{id:guid}", async (
            Guid id, AloriaDbContext db, CancellationToken ct) =>
        {
            var q = await db.Quizzes
                .Include(q => q.Questions).ThenInclude(q => q.Options)
                .FirstOrDefaultAsync(q => q.Id == id, ct);
            if (q == null) return Results.NotFound();
            return Results.Ok(new AdminQuizDto(
                q.Id, q.LessonId, q.Slug, q.Title, q.Description,
                q.RewardXp, q.RewardBuyingPower,
                q.Questions.OrderBy(x => x.Order).Select(x => new AdminQuizQuestionDto(
                    x.Id, x.Text, x.AllowsMultiple, x.Order,
                    x.Options.OrderBy(o => o.Order).Select(o => new AdminQuizOptionDto(
                        o.Id, o.Text, o.IsCorrect, o.Explanation, o.Order)).ToList()
                )).ToList()));
        });

        group.MapPost("/quizzes", async (
            AdminQuizInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var quiz = new Quiz
            {
                Id = Guid.NewGuid(),
                LessonId = input.LessonId,
                Slug = input.Slug,
                Title = input.Title,
                Description = input.Description,
                RewardXp = input.RewardXp,
                RewardBuyingPower = input.RewardBuyingPower,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
            ApplyQuestions(quiz, input.Questions);
            db.Quizzes.Add(quiz);
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("create", "Quiz", quiz.Id, quiz.Slug, ct);
            return Results.Created($"/api/admin/quizzes/{quiz.Id}", quiz.Id);
        });

        group.MapPut("/quizzes/{id:guid}", async (
            Guid id,
            AdminQuizInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            if (!await db.Quizzes.AnyAsync(q => q.Id == id, ct)) return Results.NotFound();

            // Чистим дочерние сущности минуя tracker.
            await db.QuizQuestions.Where(q => q.QuizId == id).ExecuteDeleteAsync(ct);

            // Обновляем поля квиза тоже минуя tracker.
            var now = DateTime.UtcNow;
            await db.Quizzes.Where(q => q.Id == id).ExecuteUpdateAsync(s => s
                .SetProperty(q => q.LessonId, input.LessonId)
                .SetProperty(q => q.Slug, input.Slug)
                .SetProperty(q => q.Title, input.Title)
                .SetProperty(q => q.Description, input.Description)
                .SetProperty(q => q.RewardXp, input.RewardXp)
                .SetProperty(q => q.RewardBuyingPower, input.RewardBuyingPower)
                .SetProperty(q => q.UpdatedAt, now), ct);

            // Добавляем новые вопросы напрямую через DbSet, без обращения к Quiz.
            var qOrder = 0;
            foreach (var qIn in input.Questions)
            {
                var question = new QuizQuestion
                {
                    Id = Guid.NewGuid(),
                    QuizId = id,
                    Text = qIn.Text,
                    AllowsMultiple = qIn.AllowsMultiple,
                    Order = qOrder++,
                };
                db.QuizQuestions.Add(question);
                var oOrder = 0;
                foreach (var oIn in qIn.Options)
                {
                    db.QuizOptions.Add(new QuizOption
                    {
                        Id = Guid.NewGuid(),
                        QuestionId = question.Id,
                        Text = oIn.Text,
                        IsCorrect = oIn.IsCorrect,
                        Explanation = oIn.Explanation,
                        Order = oOrder++,
                    });
                }
            }
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("update", "Quiz", id, input.Slug, ct);
            return Results.NoContent();
        });

        group.MapDelete("/quizzes/{id:guid}", async (
            Guid id,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var quiz = await db.Quizzes.FindAsync([id], ct);
            if (quiz == null) return Results.NotFound();
            db.Quizzes.Remove(quiz);
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("delete", "Quiz", id, quiz.Slug, ct);
            return Results.NoContent();
        });
    }

    private static void ApplyQuestions(Quiz quiz, List<AdminQuizQuestionInput> questions)
    {
        var order = 0;
        foreach (var q in questions)
        {
            var question = new QuizQuestion
            {
                Id = Guid.NewGuid(),
                QuizId = quiz.Id,
                Text = q.Text,
                AllowsMultiple = q.AllowsMultiple,
                Order = order++,
            };
            var optOrder = 0;
            foreach (var o in q.Options)
            {
                question.Options.Add(new QuizOption
                {
                    Id = Guid.NewGuid(),
                    QuestionId = question.Id,
                    Text = o.Text,
                    IsCorrect = o.IsCorrect,
                    Explanation = o.Explanation,
                    Order = optOrder++,
                });
            }
            quiz.Questions.Add(question);
        }
    }

    private static void MapAchievements(RouteGroupBuilder group)
    {
        group.MapGet("/achievements", async (AloriaDbContext db, CancellationToken ct) =>
        {
            var list = await db.Achievements
                .OrderBy(a => a.Order)
                .Select(a => new AdminAchievementDto(
                    a.Id, a.Code, a.Title, a.Description, a.IconName,
                    (int)a.Condition, a.ConditionThreshold, a.ConditionArg,
                    a.RewardXp, a.RewardBuyingPower, a.Order, a.UpdatedAt))
                .ToListAsync(ct);
            return Results.Ok(list);
        });

        group.MapPost("/achievements", async (
            AdminAchievementInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var ach = new Achievement
            {
                Id = Guid.NewGuid(),
                Code = input.Code,
                Title = input.Title,
                Description = input.Description,
                IconName = input.IconName,
                Condition = (AchievementCondition)input.Condition,
                ConditionThreshold = input.ConditionThreshold,
                ConditionArg = input.ConditionArg,
                RewardXp = input.RewardXp,
                RewardBuyingPower = input.RewardBuyingPower,
                Order = input.Order,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
            db.Achievements.Add(ach);
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("create", "Achievement", ach.Id, ach.Code, ct);
            return Results.Created($"/api/admin/achievements/{ach.Id}", ach.Id);
        });

        group.MapPut("/achievements/{id:guid}", async (
            Guid id,
            AdminAchievementInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var ach = await db.Achievements.FindAsync([id], ct);
            if (ach == null) return Results.NotFound();
            ach.Code = input.Code;
            ach.Title = input.Title;
            ach.Description = input.Description;
            ach.IconName = input.IconName;
            ach.Condition = (AchievementCondition)input.Condition;
            ach.ConditionThreshold = input.ConditionThreshold;
            ach.ConditionArg = input.ConditionArg;
            ach.RewardXp = input.RewardXp;
            ach.RewardBuyingPower = input.RewardBuyingPower;
            ach.Order = input.Order;
            ach.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("update", "Achievement", id, ach.Code, ct);
            return Results.NoContent();
        });

        group.MapDelete("/achievements/{id:guid}", async (
            Guid id,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var ach = await db.Achievements.FindAsync([id], ct);
            if (ach == null) return Results.NotFound();
            db.Achievements.Remove(ach);
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("delete", "Achievement", id, ach.Code, ct);
            return Results.NoContent();
        });
    }

    private static void MapUsers(RouteGroupBuilder group)
    {
        group.MapGet("/users", async (
            string? search,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var query = db.Users.AsQueryable();
            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.ToLower();
                query = query.Where(u =>
                    u.AlorPortfolioId.ToLower().Contains(s) ||
                    (u.DisplayName != null && u.DisplayName.ToLower().Contains(s)));
            }

            var list = await query.ToListAsync(ct);
            var result = new List<AdminUserListDto>();
            foreach (var u in list)
            {
                var lessons = await db.LessonCompletions.CountAsync(c => c.UserId == u.Id, ct);
                var quizzes = await db.QuizAttempts.CountAsync(a => a.UserId == u.Id && a.IsPassed, ct);
                var bonus = await db.BuyingPowerGrants
                    .Where(g => g.UserId == u.Id && g.Status == "committed")
                    .SumAsync(g => (decimal?)g.Amount, ct) ?? 0;
                result.Add(new AdminUserListDto(
                    u.Id, u.AlorPortfolioId, u.DisplayName, u.Xp, u.Level,
                    u.StreakDays, lessons, quizzes, bonus, u.CreatedAt));
            }
            return Results.Ok(result);
        });

        group.MapGet("/users/{id:guid}", async (
            Guid id,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var user = await db.Users.FindAsync([id], ct);
            if (user == null) return Results.NotFound();

            var lessons = await db.LessonCompletions.CountAsync(c => c.UserId == user.Id, ct);
            var quizzes = await db.QuizAttempts.CountAsync(a => a.UserId == user.Id && a.IsPassed, ct);
            var bonus = await db.BuyingPowerGrants
                .Where(g => g.UserId == user.Id && g.Status == "committed")
                .SumAsync(g => (decimal?)g.Amount, ct) ?? 0;
            var summary = new AdminUserListDto(
                user.Id, user.AlorPortfolioId, user.DisplayName, user.Xp, user.Level,
                user.StreakDays, lessons, quizzes, bonus, user.CreatedAt);

            var grants = await db.BuyingPowerGrants
                .Where(g => g.UserId == user.Id)
                .OrderByDescending(g => g.CreatedAt)
                .Select(g => new AdminGrantDto(g.Id, g.Amount, g.Reason, g.Status, g.CreatedAt, g.CommittedAt))
                .ToListAsync(ct);

            var attempts = await db.QuizAttempts
                .Where(a => a.UserId == user.Id)
                .Include(a => a.Quiz)
                .OrderByDescending(a => a.AttemptedAt)
                .Select(a => new AdminQuizAttemptDto(
                    a.Id, a.QuizId, a.Quiz!.Title, a.IsPassed,
                    a.AwardedXp, a.AwardedBuyingPower, a.AttemptedAt))
                .ToListAsync(ct);

            var unlocks = await db.AchievementUnlocks
                .Where(u => u.UserId == user.Id)
                .Include(u => u.Achievement)
                .OrderByDescending(u => u.UnlockedAt)
                .Select(u => new AdminAchievementUnlockDto(
                    u.AchievementId, u.Achievement!.Code, u.Achievement.Title, u.UnlockedAt))
                .ToListAsync(ct);

            return Results.Ok(new AdminUserDetailDto(summary, grants, attempts, unlocks));
        });

        group.MapPost("/users/{id:guid}/grants", async (
            Guid id,
            AdminManualGrantInput input,
            AloriaDbContext db,
            GrantService grants,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var user = await db.Users.FindAsync([id], ct);
            if (user == null) return Results.NotFound();
            var key = $"manual-{user.Id:N}-{DateTime.UtcNow.Ticks}";
            var grant = await grants.GrantAsync(user.Id, input.Amount, input.Reason, key, ct);
            await audit.LogAsync("create", "Grant", grant.Id, $"manual: {input.Amount} {input.Reason}", ct);
            return Results.Ok(grant.Id);
        });

        group.MapGet("/users/{id:guid}/lessons", async (
            Guid id,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var user = await db.Users.FindAsync([id], ct);
            if (user == null) return Results.NotFound();

            var lessons = await db.Lessons
                .Include(l => l.Section)
                .OrderBy(l => l.Section!.Order)
                .ThenBy(l => l.Order)
                .Select(l => new
                {
                    l.Id, l.Slug, l.Title, l.Order,
                    SectionSlug = l.Section!.Slug,
                    SectionTitle = l.Section!.Title,
                })
                .ToListAsync(ct);

            var completed = await db.LessonCompletions
                .Where(c => c.UserId == id)
                .Select(c => c.LessonId)
                .ToHashSetAsync(ct);

            return Results.Ok(lessons.Select(l => new
            {
                l.Id,
                l.Slug,
                l.Title,
                l.Order,
                l.SectionSlug,
                l.SectionTitle,
                Completed = completed.Contains(l.Id),
            }));
        });

        group.MapPut("/users/{userId:guid}/lessons/{lessonId:guid}", async (
            Guid userId,
            Guid lessonId,
            AdminLessonCompletionInput input,
            AloriaDbContext db,
            UserService users,
            AchievementEvaluator achievements,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var user = await db.Users.FindAsync([userId], ct);
            if (user == null) return Results.NotFound();
            var lesson = await db.Lessons.FindAsync([lessonId], ct);
            if (lesson == null) return Results.NotFound();

            var existing = await db.LessonCompletions
                .FirstOrDefaultAsync(c => c.UserId == userId && c.LessonId == lessonId, ct);

            if (input.Completed && existing == null)
            {
                db.LessonCompletions.Add(new LessonCompletion
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    LessonId = lessonId,
                    LessonVersion = lesson.Version,
                    CompletedAt = DateTime.UtcNow,
                });
                await db.SaveChangesAsync(ct);
                await users.AddXpAsync(user, 10, ct);
                await audit.LogAsync("create", "LessonCompletion", lessonId,
                    $"manual: user={user.AlorPortfolioId} lesson={lesson.Slug}", ct);
            }
            else if (!input.Completed && existing != null)
            {
                db.LessonCompletions.Remove(existing);
                user.Xp = Math.Max(0, user.Xp - 10);
                user.UpdatedAt = DateTime.UtcNow;
                await db.SaveChangesAsync(ct);
                await audit.LogAsync("delete", "LessonCompletion", lessonId,
                    $"manual: user={user.AlorPortfolioId} lesson={lesson.Slug}", ct);
            }

            await achievements.EvaluateAsync(user, ct);
            return Results.NoContent();
        });

        group.MapPost("/users/{id:guid}/reset", async (
            Guid id,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var user = await db.Users.FindAsync([id], ct);
            if (user == null) return Results.NotFound();

            await db.LessonCompletions.Where(x => x.UserId == id).ExecuteDeleteAsync(ct);
            await db.QuizAttempts.Where(x => x.UserId == id).ExecuteDeleteAsync(ct);
            await db.AchievementUnlocks.Where(x => x.UserId == id).ExecuteDeleteAsync(ct);
            await db.BuyingPowerGrants.Where(x => x.UserId == id).ExecuteDeleteAsync(ct);
            await db.UserEvents.Where(x => x.UserId == id).ExecuteDeleteAsync(ct);

            user.Xp = 0;
            user.Level = 1;
            user.StreakDays = 0;
            user.LastActiveDate = null;
            user.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);

            await audit.LogAsync("reset", "User", id, $"manual progress reset for {user.AlorPortfolioId}", ct);
            return Results.NoContent();
        });
    }

    private static void MapAudit(RouteGroupBuilder group)
    {
        group.MapGet("/audit", async (
            int? take,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var n = Math.Min(take ?? 100, 500);
            var list = await db.AuditLog
                .OrderByDescending(a => a.CreatedAt)
                .Take(n)
                .Select(a => new AdminAuditEntryDto(
                    a.Id, a.Actor, a.Action, a.EntityType, a.EntityId, a.Details, a.CreatedAt))
                .ToListAsync(ct);
            return Results.Ok(list);
        });
    }

    private static void MapUploads(RouteGroupBuilder group)
    {
        group.MapPost("/uploads", async (
            HttpRequest request,
            IWebHostEnvironment env,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            if (!request.HasFormContentType) return Results.BadRequest("multipart/form-data required");
            var form = await request.ReadFormAsync(ct);
            var file = form.Files.FirstOrDefault();
            if (file == null || file.Length == 0) return Results.BadRequest("no file");

            var uploadsDir = Path.Combine(env.ContentRootPath, "uploads");
            Directory.CreateDirectory(uploadsDir);
            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            var allowed = new[] { ".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg" };
            if (!allowed.Contains(ext)) return Results.BadRequest("unsupported file type");

            var name = $"{Guid.NewGuid():N}{ext}";
            var fullPath = Path.Combine(uploadsDir, name);
            await using (var stream = File.Create(fullPath))
            {
                await file.CopyToAsync(stream, ct);
            }
            await audit.LogAsync("create", "Upload", null, name, ct);
            return Results.Ok(new { url = $"/uploads/{name}", fileName = name, size = file.Length });
        }).DisableAntiforgery();
    }
}
