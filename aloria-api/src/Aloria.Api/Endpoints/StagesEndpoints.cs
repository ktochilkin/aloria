using Aloria.Api.Data;
using Aloria.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Endpoints;

/// <summary>
/// API спирального курса: этапы, уроки внутри этапов с разметкой концепций
/// и требованиями практики. /api/v1/learning/* остаётся как legacy alias.
/// </summary>
public static class StagesEndpoints
{
    public static IEndpointRouteBuilder MapStagesEndpoints(this IEndpointRouteBuilder app)
    {
        var stages = app.MapGroup("/api/v1/stages").WithTags("Stages");

        stages.MapGet("/", async (
            string? portfolioId,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var sections = await db.Sections
                .OrderBy(s => s.Order)
                .Select(s => new
                {
                    s.Id, s.Slug, s.Title, s.Description, s.Order,
                    s.Kind, s.IsOptional, s.IconName, s.Tint, s.Goal, s.TargetMinutes,
                    LessonIds = s.Lessons.Select(l => l.Id).ToList(),
                    PracticeIds = s.PracticeRequirements
                        .Where(pr => !pr.Archived && !pr.IsOptional)
                        .Select(pr => pr.Id).ToList(),
                })
                .ToListAsync(ct);

            var completedLessonIds = new HashSet<Guid>();
            var fulfilledPracticeIds = new HashSet<Guid>();
            if (!string.IsNullOrWhiteSpace(portfolioId))
            {
                completedLessonIds = await db.LessonCompletions
                    .Where(c => c.User!.AlorPortfolioId == portfolioId)
                    .Select(c => c.LessonId)
                    .ToHashSetAsync(ct);
                fulfilledPracticeIds = await db.UserPracticeFulfillments
                    .Where(f => db.Users.Any(u => u.Id == f.UserId
                        && u.AlorPortfolioId == portfolioId))
                    .Select(f => f.PracticeRequirementId)
                    .ToHashSetAsync(ct);
            }

            var result = sections.Select(s =>
            {
                var lessonsTotal = s.LessonIds.Count;
                var lessonsCompleted = s.LessonIds.Count(id => completedLessonIds.Contains(id));
                var practiceTotal = s.PracticeIds.Count;
                var practiceFulfilled = s.PracticeIds.Count(id => fulfilledPracticeIds.Contains(id));

                var status = (lessonsCompleted == 0 && practiceFulfilled == 0)
                    ? StageStatus.NotStarted
                    : (lessonsCompleted >= lessonsTotal && practiceFulfilled >= practiceTotal)
                        ? StageStatus.Completed
                        : StageStatus.InProgress;

                return new
                {
                    id = s.Id,
                    slug = s.Slug,
                    title = s.Title,
                    subtitle = s.Description,
                    order = s.Order,
                    kind = s.Kind,
                    isOptional = s.IsOptional,
                    icon = s.IconName,
                    tint = s.Tint,
                    goal = s.Goal,
                    targetMinutes = s.TargetMinutes,
                    lessonsTotal,
                    lessonsCompleted,
                    practiceTotal,
                    practiceFulfilled,
                    status = status.ToString().ToLowerInvariant(),
                };
            });

            return Results.Ok(result);
        });

        stages.MapGet("/{slug}", async (
            string slug,
            string? portfolioId,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var section = await db.Sections.FirstOrDefaultAsync(s => s.Slug == slug, ct);
            if (section == null) return Results.NotFound();

            var lessons = await db.Lessons
                .Where(l => l.SectionId == section.Id)
                .OrderBy(l => l.Order)
                .Select(l => new
                {
                    l.Id, l.Slug, l.Title, l.Description, l.ImageUrl, l.EstimatedMinutes,
                    l.Order, l.Group, l.RoleHint, l.IsCapstone, l.PracticeRequirementCode,
                    HasQuiz = l.Quiz != null,
                    Concepts = l.Concepts.Select(lc => new
                    {
                        lc.Role,
                        lc.Depth,
                        ConceptSlug = lc.Concept!.Slug,
                        ConceptTitle = lc.Concept.Title,
                    }).ToList(),
                })
                .ToListAsync(ct);

            var practice = await db.PracticeRequirements
                .Where(pr => pr.SectionId == section.Id && !pr.Archived)
                .OrderBy(pr => pr.Order)
                .Select(pr => new
                {
                    pr.Id, pr.Code, pr.Title, pr.Description,
                    Kind = pr.Kind.ToString(),
                    pr.IsOptional, pr.RewardBuyingPower,
                    pr.ParamsJson, pr.ConceptSlugsJson,
                })
                .ToListAsync(ct);

            var lessonIds = lessons.Select(l => l.Id).ToHashSet();
            var practiceIds = practice.Select(p => p.Id).ToHashSet();

            var completed = new HashSet<Guid>();
            var fulfilled = new HashSet<Guid>();
            if (!string.IsNullOrWhiteSpace(portfolioId))
            {
                completed = await db.LessonCompletions
                    .Where(c => c.User!.AlorPortfolioId == portfolioId && lessonIds.Contains(c.LessonId))
                    .Select(c => c.LessonId)
                    .ToHashSetAsync(ct);
                fulfilled = await db.UserPracticeFulfillments
                    .Where(f => db.Users.Any(u => u.Id == f.UserId && u.AlorPortfolioId == portfolioId)
                        && practiceIds.Contains(f.PracticeRequirementId))
                    .Select(f => f.PracticeRequirementId)
                    .ToHashSetAsync(ct);
            }

            return Results.Ok(new
            {
                stage = new
                {
                    id = section.Id,
                    slug = section.Slug,
                    title = section.Title,
                    subtitle = section.Description,
                    order = section.Order,
                    kind = section.Kind,
                    isOptional = section.IsOptional,
                    icon = section.IconName,
                    tint = section.Tint,
                    goal = section.Goal,
                    targetMinutes = section.TargetMinutes,
                },
                lessons = lessons.Select(l => new
                {
                    l.Id, l.Slug, l.Title, l.Description, l.ImageUrl, l.EstimatedMinutes,
                    l.Order, l.Group,
                    roleHint = l.RoleHint,
                    isCapstone = l.IsCapstone,
                    practiceRequirementCode = l.PracticeRequirementCode,
                    hasQuiz = l.HasQuiz,
                    completed = completed.Contains(l.Id),
                    introduces = l.Concepts.Where(c => c.Role == ConceptRole.Introduce)
                        .Select(c => new { slug = c.ConceptSlug, title = c.ConceptTitle, depth = c.Depth }),
                    deepens = l.Concepts.Where(c => c.Role == ConceptRole.Deepen)
                        .Select(c => new { slug = c.ConceptSlug, title = c.ConceptTitle, depth = c.Depth }),
                    applies = l.Concepts.Where(c => c.Role == ConceptRole.Apply)
                        .Select(c => new { slug = c.ConceptSlug, title = c.ConceptTitle, depth = c.Depth }),
                }),
                practice = practice.Select(p => new
                {
                    p.Id, p.Code, p.Title, p.Description, p.Kind, p.IsOptional, p.RewardBuyingPower,
                    paramsJson = p.ParamsJson,
                    conceptSlugsJson = p.ConceptSlugsJson,
                    fulfilled = fulfilled.Contains(p.Id),
                }),
            });
        });

        var concepts = app.MapGroup("/api/v1/concepts").WithTags("Concepts");

        concepts.MapGet("/", async (
            string? portfolioId,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var all = await db.Concepts
                .OrderBy(c => c.Order)
                .Select(c => new { c.Id, c.Slug, c.Title, c.ShortDefinition, c.IconName, c.Order })
                .ToListAsync(ct);

            var mastery = new Dictionary<Guid, ConceptMasteryLevel>();
            if (!string.IsNullOrWhiteSpace(portfolioId))
            {
                mastery = await db.UserConceptMastery
                    .Where(m => db.Users.Any(u => u.Id == m.UserId && u.AlorPortfolioId == portfolioId))
                    .ToDictionaryAsync(m => m.ConceptId, m => m.Level, ct);
            }

            return Results.Ok(all.Select(c => new
            {
                c.Slug, c.Title, c.ShortDefinition, c.IconName, c.Order,
                level = (mastery.GetValueOrDefault(c.Id, ConceptMasteryLevel.None)).ToString().ToLowerInvariant(),
            }));
        });

        concepts.MapGet("/{slug}", async (
            string slug,
            string? portfolioId,
            AloriaDbContext db,
            CancellationToken ct) =>
        {
            var slugLc = slug.ToLowerInvariant();
            var concept = await db.Concepts.FirstOrDefaultAsync(c => c.Slug == slugLc, ct);
            if (concept == null) return Results.NotFound();

            var occurrences = await db.LessonConcepts
                .Where(lc => lc.ConceptId == concept.Id)
                .Select(lc => new
                {
                    lc.Role,
                    lc.Depth,
                    LessonSlug = lc.Lesson!.Slug,
                    LessonTitle = lc.Lesson.Title,
                    LessonId = lc.LessonId,
                    SectionSlug = lc.Lesson.Section!.Slug,
                    SectionTitle = lc.Lesson.Section.Title,
                    StageOrder = lc.Lesson.Section.Order,
                    LessonOrder = lc.Lesson.Order,
                })
                .OrderBy(o => o.StageOrder).ThenBy(o => o.LessonOrder)
                .ToListAsync(ct);

            ConceptMasteryLevel level = ConceptMasteryLevel.None;
            if (!string.IsNullOrWhiteSpace(portfolioId))
            {
                var m = await db.UserConceptMastery
                    .FirstOrDefaultAsync(m => m.ConceptId == concept.Id
                        && db.Users.Any(u => u.Id == m.UserId && u.AlorPortfolioId == portfolioId), ct);
                if (m != null) level = m.Level;
            }

            return Results.Ok(new
            {
                concept.Slug, concept.Title, concept.ShortDefinition, concept.IconName, concept.Order,
                level = level.ToString().ToLowerInvariant(),
                introductions = occurrences.Where(o => o.Role == ConceptRole.Introduce)
                    .Select(o => new
                    {
                        stageSlug = o.SectionSlug, stageTitle = o.SectionTitle,
                        lessonSlug = o.LessonSlug, lessonTitle = o.LessonTitle,
                        lessonId = o.LessonId, depth = o.Depth,
                    }),
                deepenings = occurrences.Where(o => o.Role == ConceptRole.Deepen)
                    .Select(o => new
                    {
                        stageSlug = o.SectionSlug, stageTitle = o.SectionTitle,
                        lessonSlug = o.LessonSlug, lessonTitle = o.LessonTitle,
                        lessonId = o.LessonId, depth = o.Depth,
                    }),
                applications = occurrences.Where(o => o.Role == ConceptRole.Apply)
                    .Select(o => new
                    {
                        stageSlug = o.SectionSlug, stageTitle = o.SectionTitle,
                        lessonSlug = o.LessonSlug, lessonTitle = o.LessonTitle,
                        lessonId = o.LessonId, depth = o.Depth,
                    }),
            });
        });

        return app;
    }
}
