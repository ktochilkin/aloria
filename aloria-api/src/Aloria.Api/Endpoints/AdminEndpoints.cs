using Aloria.Api.Data;
using Aloria.Api.Domain;
using Aloria.Api.Dtos;
using Aloria.Api.Services;
using Aloria.Api.Services.Push;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Endpoints;

public static class AdminEndpoints
{
    public static IEndpointRouteBuilder MapAdminEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/admin").WithTags("Admin");

        MapSections(group);
        MapLessons(group);
        MapConcepts(group);
        MapPracticeRequirements(group);
        MapQuizzes(group);
        MapAchievements(group);
        MapUsers(group);
        MapPush(group);
        MapAudit(group);
        MapUploads(group);

        return app;
    }

    private static void MapPush(RouteGroupBuilder group)
    {
        // Ручная рассылка всем зарегистрированным устройствам.
        group.MapPost("/push/broadcast", async (
            AdminPushInput input,
            PushDispatcher dispatcher,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(input.Title) || string.IsNullOrWhiteSpace(input.Body))
                return Results.BadRequest("title и body обязательны");

            var outcome = await dispatcher.DispatchToAllAsync(NotificationType.Custom, PushArgs(input), ct);
            await audit.LogAsync("push", "Broadcast", null,
                $"\"{input.Title}\" → {outcome.Sent}/{outcome.Targeted}", ct);
            return Results.Ok(outcome);
        });

        // Ручная отправка конкретному пользователю (на все его устройства).
        group.MapPost("/users/{id:guid}/push", async (
            Guid id,
            AdminPushInput input,
            AloriaDbContext db,
            PushDispatcher dispatcher,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(input.Title) || string.IsNullOrWhiteSpace(input.Body))
                return Results.BadRequest("title и body обязательны");

            var user = await db.Users.FindAsync([id], ct);
            if (user == null) return Results.NotFound();

            var outcome = await dispatcher.DispatchAsync(user.Id, NotificationType.Custom, PushArgs(input), ct);
            await audit.LogAsync("push", "User", id,
                $"\"{input.Title}\" → {outcome.Sent}/{outcome.Targeted}", ct);
            return Results.Ok(outcome);
        });
    }

    private static Dictionary<string, string> PushArgs(AdminPushInput input)
    {
        var args = new Dictionary<string, string>
        {
            ["title"] = input.Title,
            ["body"] = input.Body,
        };
        if (!string.IsNullOrWhiteSpace(input.Route)) args["route"] = input.Route!;
        return args;
    }

    private static void MapSections(RouteGroupBuilder group)
    {
        group.MapGet("/sections", async (AloriaDbContext db, CancellationToken ct) =>
        {
            var list = await db.Sections
                .OrderBy(s => s.Order)
                .Select(s => new AdminSectionDto(
                    s.Id, s.Slug, s.Title, s.Description, s.Order, s.PrerequisiteSectionId,
                    s.Lessons.Count, s.CreatedAt, s.UpdatedAt,
                    s.Kind, s.IsOptional, s.IconName, s.Tint, s.Goal, s.TargetMinutes,
                    s.PracticeRequirements.Count(pr => !pr.Archived)))
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
                Kind = input.Kind ?? "stage",
                IsOptional = input.IsOptional ?? false,
                IconName = input.IconName,
                Tint = input.Tint,
                Goal = input.Goal,
                TargetMinutes = input.TargetMinutes,
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
            if (input.Kind != null) section.Kind = input.Kind;
            if (input.IsOptional.HasValue) section.IsOptional = input.IsOptional.Value;
            // null = очистить, иначе обновляем; в DTO решения «не трогать» нет —
            // фронт всегда шлёт текущее значение, поэтому здесь просто перезаписываем.
            section.IconName = input.IconName;
            section.Tint = input.Tint;
            section.Goal = input.Goal;
            section.TargetMinutes = input.TargetMinutes;
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
                    l.UpdatedAt,
                    l.IsCapstone, l.RoleHint, l.PracticeRequirementCode,
                    l.Concepts.Count))
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
                .Include(l => l.Concepts)
                    .ThenInclude(lc => lc.Concept)
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
            var concepts = lesson.Concepts
                .Select(lc => new AdminLessonConceptDto(
                    lc.Concept!.Slug, lc.Concept.Title, lc.Role.ToString(), lc.Depth))
                .OrderBy(c => c.Role).ThenBy(c => c.ConceptSlug)
                .ToList();
            return Results.Ok(new AdminLessonDto(
                lesson.Id, lesson.SectionId, lesson.Slug, lesson.Title, lesson.Description,
                lesson.BodyMd, lesson.ImageUrl, lesson.EstimatedMinutes,
                lesson.AcademicDefinition, lesson.Order, lesson.Version, quizDto,
                lesson.IsCapstone, lesson.RoleHint, lesson.PracticeRequirementCode,
                lesson.Group, lesson.RecallPrompt, lesson.RecallAnswer,
                lesson.PracticeText, lesson.PracticeSymbol,
                concepts));
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
                IsCapstone = input.IsCapstone ?? false,
                RoleHint = input.RoleHint,
                PracticeRequirementCode = input.PracticeRequirementCode,
                Group = input.Group,
                RecallPrompt = input.RecallPrompt,
                RecallAnswer = input.RecallAnswer,
                PracticeText = input.PracticeText,
                PracticeSymbol = input.PracticeSymbol,
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
            if (input.IsCapstone.HasValue) lesson.IsCapstone = input.IsCapstone.Value;
            lesson.RoleHint = input.RoleHint;
            lesson.PracticeRequirementCode = input.PracticeRequirementCode;
            lesson.Group = input.Group;
            lesson.RecallPrompt = input.RecallPrompt;
            lesson.RecallAnswer = input.RecallAnswer;
            lesson.PracticeText = input.PracticeText;
            lesson.PracticeSymbol = input.PracticeSymbol;
            lesson.Version += 1;
            lesson.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("update", "Lesson", id, lesson.Slug, ct);
            return Results.NoContent();
        });

        // r11: правка связей урок ↔ концепции через списки slug'ов.
        // delete-then-insert по правилам importer'a.
        group.MapPut("/lessons/{id:guid}/concepts", async (
            Guid id,
            AdminLessonConceptsInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var lesson = await db.Lessons.FindAsync([id], ct);
            if (lesson == null) return Results.NotFound();

            var allSlugs = new HashSet<string>(
                (input.Introduces ?? []).Concat(input.Deepens ?? []).Concat(input.Applies ?? []),
                StringComparer.OrdinalIgnoreCase);
            var conceptIdBySlug = await db.Concepts
                .Where(c => allSlugs.Contains(c.Slug))
                .ToDictionaryAsync(c => c.Slug, c => c.Id, StringComparer.OrdinalIgnoreCase, ct);

            await db.LessonConcepts.Where(lc => lc.LessonId == id).ExecuteDeleteAsync(ct);

            void Add(string slug, ConceptRole role, int depth)
            {
                if (!conceptIdBySlug.TryGetValue(slug, out var conceptId)) return;
                db.LessonConcepts.Add(new LessonConcept
                {
                    LessonId = id, ConceptId = conceptId, Role = role, Depth = depth,
                });
            }

            foreach (var s in input.Introduces ?? []) Add(s, ConceptRole.Introduce, 1);
            foreach (var s in input.Deepens ?? []) Add(s, ConceptRole.Deepen, 2);
            foreach (var s in input.Applies ?? []) Add(s, ConceptRole.Apply, 3);

            lesson.Version += 1;
            lesson.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("update", "LessonConcepts", id, lesson.Slug, ct);
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

    private static void MapConcepts(RouteGroupBuilder group)
    {
        group.MapGet("/concepts", async (AloriaDbContext db, CancellationToken ct) =>
        {
            var list = await db.Concepts
                .OrderBy(c => c.Order)
                .Select(c => new AdminConceptDto(
                    c.Id, c.Slug, c.Title, c.ShortDefinition, c.IconName, c.Order,
                    c.Lessons.Count, c.CreatedAt, c.UpdatedAt))
                .ToListAsync(ct);
            return Results.Ok(list);
        });

        group.MapGet("/concepts/{id:guid}", async (Guid id, AloriaDbContext db, CancellationToken ct) =>
        {
            var c = await db.Concepts.FindAsync([id], ct);
            if (c == null) return Results.NotFound();
            var lessonsCount = await db.LessonConcepts.CountAsync(lc => lc.ConceptId == id, ct);
            return Results.Ok(new AdminConceptDto(
                c.Id, c.Slug, c.Title, c.ShortDefinition, c.IconName, c.Order,
                lessonsCount, c.CreatedAt, c.UpdatedAt));
        });

        group.MapPost("/concepts", async (
            AdminConceptInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var concept = new Concept
            {
                Id = Guid.NewGuid(),
                Slug = input.Slug.ToLowerInvariant(),
                Title = input.Title,
                ShortDefinition = input.ShortDefinition,
                IconName = input.IconName,
                Order = input.Order,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
            db.Concepts.Add(concept);
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("create", "Concept", concept.Id, concept.Slug, ct);
            return Results.Created($"/api/admin/concepts/{concept.Id}", concept.Id);
        });

        group.MapPut("/concepts/{id:guid}", async (
            Guid id,
            AdminConceptInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var concept = await db.Concepts.FindAsync([id], ct);
            if (concept == null) return Results.NotFound();
            concept.Slug = input.Slug.ToLowerInvariant();
            concept.Title = input.Title;
            concept.ShortDefinition = input.ShortDefinition;
            concept.IconName = input.IconName;
            concept.Order = input.Order;
            concept.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("update", "Concept", id, concept.Slug, ct);
            return Results.NoContent();
        });

        group.MapDelete("/concepts/{id:guid}", async (
            Guid id,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var concept = await db.Concepts.FindAsync([id], ct);
            if (concept == null) return Results.NotFound();
            db.Concepts.Remove(concept);
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("delete", "Concept", id, concept.Slug, ct);
            return Results.NoContent();
        });
    }

    private static void MapPracticeRequirements(RouteGroupBuilder group)
    {
        group.MapGet("/sections/{sectionId:guid}/practice", async (
            Guid sectionId, AloriaDbContext db, CancellationToken ct) =>
        {
            var list = await db.PracticeRequirements
                .Where(pr => pr.SectionId == sectionId)
                .OrderBy(pr => pr.Order)
                .Select(pr => new AdminPracticeRequirementDto(
                    pr.Id, pr.SectionId, pr.Code, pr.Title, pr.Description,
                    pr.Kind.ToString(), pr.ParamsJson, pr.Order, pr.IsOptional,
                    pr.RewardBuyingPower, pr.ConceptSlugsJson, pr.Archived, pr.UpdatedAt))
                .ToListAsync(ct);
            return Results.Ok(list);
        });

        group.MapPost("/sections/{sectionId:guid}/practice", async (
            Guid sectionId,
            AdminPracticeRequirementInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var section = await db.Sections.FindAsync([sectionId], ct);
            if (section == null) return Results.NotFound();
            if (!Enum.TryParse<PracticeKind>(input.Kind, true, out var kind))
                return Results.BadRequest($"unknown PracticeKind '{input.Kind}'");

            var pr = new PracticeRequirement
            {
                Id = Guid.NewGuid(),
                SectionId = sectionId,
                Code = input.Code,
                Title = input.Title,
                Description = input.Description,
                Kind = kind,
                ParamsJson = string.IsNullOrWhiteSpace(input.ParamsJson) ? "{}" : input.ParamsJson,
                Order = input.Order,
                IsOptional = input.IsOptional,
                RewardBuyingPower = input.RewardBuyingPower,
                ConceptSlugsJson = string.IsNullOrWhiteSpace(input.ConceptSlugsJson) ? "[]" : input.ConceptSlugsJson,
                Archived = false,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
            db.PracticeRequirements.Add(pr);
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("create", "PracticeRequirement", pr.Id, pr.Code, ct);
            return Results.Created($"/api/admin/practice/{pr.Id}", pr.Id);
        });

        group.MapPut("/practice/{id:guid}", async (
            Guid id,
            AdminPracticeRequirementInput input,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var pr = await db.PracticeRequirements.FindAsync([id], ct);
            if (pr == null) return Results.NotFound();
            if (!Enum.TryParse<PracticeKind>(input.Kind, true, out var kind))
                return Results.BadRequest($"unknown PracticeKind '{input.Kind}'");

            pr.Code = input.Code;
            pr.Title = input.Title;
            pr.Description = input.Description;
            pr.Kind = kind;
            pr.ParamsJson = string.IsNullOrWhiteSpace(input.ParamsJson) ? "{}" : input.ParamsJson;
            pr.Order = input.Order;
            pr.IsOptional = input.IsOptional;
            pr.RewardBuyingPower = input.RewardBuyingPower;
            pr.ConceptSlugsJson = string.IsNullOrWhiteSpace(input.ConceptSlugsJson) ? "[]" : input.ConceptSlugsJson;
            pr.Archived = false;
            pr.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("update", "PracticeRequirement", id, pr.Code, ct);
            return Results.NoContent();
        });

        group.MapDelete("/practice/{id:guid}", async (
            Guid id,
            AloriaDbContext db,
            AuditLogger audit,
            CancellationToken ct) =>
        {
            var pr = await db.PracticeRequirements.FindAsync([id], ct);
            if (pr == null) return Results.NotFound();
            // Мягкое удаление — фулфилменты пользователей не теряем.
            pr.Archived = true;
            pr.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            await audit.LogAsync("archive", "PracticeRequirement", id, pr.Code, ct);
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
