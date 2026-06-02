using System.Text.Json;
using Aloria.Api.Data;
using Aloria.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Services;

/// <summary>
/// Единая точка обновления спирального прогресса пользователя. Вызывается
/// при завершении урока (поднимает UserConceptMastery по ролям LessonConcept
/// и пересчитывает UserStageProgress) и при фулфилменте требования практики
/// (поднимает мастеринг до Applied для связанных концепций).
/// </summary>
public class ProgressUpdater(AloriaDbContext db)
{
    /// <summary>Вызывается после успешной записи LessonCompletion.</summary>
    public async Task OnLessonCompletedAsync(User user, Lesson lesson, CancellationToken ct)
    {
        var conceptLinks = await db.LessonConcepts
            .Where(lc => lc.LessonId == lesson.Id)
            .Select(lc => new { lc.ConceptId, lc.Role, lc.Depth })
            .ToListAsync(ct);

        foreach (var link in conceptLinks)
        {
            var target = link.Role switch
            {
                ConceptRole.Introduce => ConceptMasteryLevel.Familiar,
                ConceptRole.Deepen    => ConceptMasteryLevel.Understands,
                ConceptRole.Apply     => ConceptMasteryLevel.Understands, // практика поднимет до Applied
                _ => ConceptMasteryLevel.None,
            };
            await RaiseMasteryAsync(user, link.ConceptId, target,
                source: new { from = "lesson", lessonId = lesson.Id, role = link.Role.ToString(), depth = link.Depth },
                ct);
        }

        var section = await db.Sections.FirstOrDefaultAsync(s => s.Id == lesson.SectionId, ct);
        if (section != null)
        {
            await RecomputeStageAsync(user, section, ct);
        }
    }

    /// <summary>Вызывается после записи UserPracticeFulfillment.</summary>
    public async Task OnPracticeFulfilledAsync(User user, PracticeRequirement req, CancellationToken ct)
    {
        var slugs = ParseConceptSlugs(req.ConceptSlugsJson);
        if (slugs.Count > 0)
        {
            var conceptIds = await db.Concepts
                .Where(c => slugs.Contains(c.Slug))
                .Select(c => new { c.Id, c.Slug })
                .ToListAsync(ct);

            foreach (var c in conceptIds)
            {
                await RaiseMasteryAsync(user, c.Id, ConceptMasteryLevel.Applied,
                    source: new { from = "practice", requirementId = req.Id, code = req.Code },
                    ct);
            }
        }

        var section = await db.Sections.FirstOrDefaultAsync(s => s.Id == req.SectionId, ct);
        if (section != null)
        {
            await RecomputeStageAsync(user, section, ct);
        }
    }

    /// <summary>
    /// Идемпотентно пересчитывает UserStageProgress для пользователя и этапа.
    /// Можно вызывать многократно — состояние всегда сходится к актуальному.
    /// </summary>
    public async Task RecomputeStageAsync(User user, Section stage, CancellationToken ct)
    {
        var lessonsTotal = await db.Lessons.CountAsync(l => l.SectionId == stage.Id, ct);
        var lessonsCompleted = await db.LessonCompletions
            .CountAsync(lc => lc.UserId == user.Id
                && db.Lessons.Any(l => l.Id == lc.LessonId && l.SectionId == stage.Id), ct);

        var practiceTotal = await db.PracticeRequirements
            .CountAsync(pr => pr.SectionId == stage.Id && !pr.Archived && !pr.IsOptional, ct);
        var practiceFulfilled = await db.UserPracticeFulfillments
            .CountAsync(uf => uf.UserId == user.Id
                && db.PracticeRequirements.Any(pr => pr.Id == uf.PracticeRequirementId
                    && pr.SectionId == stage.Id && !pr.Archived && !pr.IsOptional), ct);

        var status =
            (lessonsCompleted == 0 && practiceFulfilled == 0) ? StageStatus.NotStarted
            : (lessonsCompleted >= lessonsTotal && practiceFulfilled >= practiceTotal) ? StageStatus.Completed
            : StageStatus.InProgress;

        var progress = await db.UserStageProgress
            .FirstOrDefaultAsync(usp => usp.UserId == user.Id && usp.SectionId == stage.Id, ct);

        if (progress == null)
        {
            progress = new UserStageProgress
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                SectionId = stage.Id,
                Status = status,
                LessonsCompletedCount = lessonsCompleted,
                PracticeFulfilledCount = practiceFulfilled,
                StartedAt = status != StageStatus.NotStarted ? DateTime.UtcNow : null,
                CompletedAt = status == StageStatus.Completed ? DateTime.UtcNow : null,
                UpdatedAt = DateTime.UtcNow,
            };
            db.UserStageProgress.Add(progress);
        }
        else
        {
            var wasCompleted = progress.Status == StageStatus.Completed;
            progress.Status = status;
            progress.LessonsCompletedCount = lessonsCompleted;
            progress.PracticeFulfilledCount = practiceFulfilled;
            if (status != StageStatus.NotStarted && progress.StartedAt == null)
                progress.StartedAt = DateTime.UtcNow;
            if (status == StageStatus.Completed && !wasCompleted)
                progress.CompletedAt = DateTime.UtcNow;
            progress.UpdatedAt = DateTime.UtcNow;
        }
        await db.SaveChangesAsync(ct);
    }

    private async Task RaiseMasteryAsync(
        User user, Guid conceptId, ConceptMasteryLevel target, object source, CancellationToken ct)
    {
        var mastery = await db.UserConceptMastery
            .FirstOrDefaultAsync(m => m.UserId == user.Id && m.ConceptId == conceptId, ct);

        if (mastery == null)
        {
            mastery = new UserConceptMastery
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                ConceptId = conceptId,
                Level = target,
                SourcesJson = JsonSerializer.Serialize(new[]
                {
                    AppendSource(Array.Empty<JsonElement>(), source, target),
                }),
                UpdatedAt = DateTime.UtcNow,
            };
            db.UserConceptMastery.Add(mastery);
        }
        else
        {
            // Уровень монотонно растёт.
            if (target <= mastery.Level) return;

            mastery.Level = target;
            mastery.SourcesJson = AppendSourceToJson(mastery.SourcesJson, source, target);
            mastery.UpdatedAt = DateTime.UtcNow;
        }
        await db.SaveChangesAsync(ct);
    }

    private static List<string> ParseConceptSlugs(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.ValueKind != JsonValueKind.Array) return new();
            return doc.RootElement.EnumerateArray()
                .Select(el => el.GetString()?.ToLowerInvariant())
                .Where(s => !string.IsNullOrWhiteSpace(s))
                .Select(s => s!)
                .ToList();
        }
        catch
        {
            return new();
        }
    }

    private static string AppendSourceToJson(string sourcesJson, object source, ConceptMasteryLevel raised)
    {
        try
        {
            var arr = JsonSerializer.Deserialize<List<Dictionary<string, object?>>>(sourcesJson)
                ?? new();
            arr.Add(BuildSource(source, raised));
            return JsonSerializer.Serialize(arr);
        }
        catch
        {
            return JsonSerializer.Serialize(new[] { BuildSource(source, raised) });
        }
    }

    private static Dictionary<string, object?> AppendSource(IEnumerable<JsonElement> _, object source, ConceptMasteryLevel raised)
        => BuildSource(source, raised);

    private static Dictionary<string, object?> BuildSource(object source, ConceptMasteryLevel raised)
    {
        var dict = new Dictionary<string, object?>
        {
            ["at"] = DateTime.UtcNow.ToString("O"),
            ["raised"] = raised.ToString().ToLowerInvariant(),
        };
        // Грубый дамп source в словарь.
        foreach (var prop in source.GetType().GetProperties())
        {
            dict[prop.Name] = prop.GetValue(source);
        }
        return dict;
    }
}
