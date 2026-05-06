using System.Text.Json;
using System.Text.RegularExpressions;
using Aloria.Api.Data;
using Aloria.Api.Domain;
using Microsoft.EntityFrameworkCore;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace Aloria.Api.Services;

/// <summary>
/// Однократный импорт текущих markdown-уроков из Flutter-проекта.
/// Запускается из CLI: dotnet run -- --seed.
/// </summary>
public class MarkdownLessonImporter(
    AloriaDbContext db,
    ILogger<MarkdownLessonImporter> log)
{
    private static readonly IDeserializer Yaml = new DeserializerBuilder()
        .WithNamingConvention(UnderscoredNamingConvention.Instance)
        .IgnoreUnmatchedProperties()
        .Build();

    private static readonly Regex Frontmatter = new(
        @"^---\s*\r?\n(?<yaml>.*?)\r?\n---\s*\r?\n(?<body>.*)$",
        RegexOptions.Singleline | RegexOptions.Compiled);

    private static readonly Regex QuizBlock = new(
        @"\r?\n---quiz---\s*\r?\n(?<json>.*?)$",
        RegexOptions.Singleline | RegexOptions.Compiled);

    public async Task<int> ImportFromFlutterAsync(string lessonsDir, CancellationToken ct = default)
    {
        if (!Directory.Exists(lessonsDir))
        {
            log.LogWarning("Lessons directory not found: {Dir}", lessonsDir);
            return 0;
        }

        var sectionDirs = Directory.EnumerateDirectories(lessonsDir).OrderBy(x => x).ToList();
        var totalLessons = 0;

        foreach (var sectionDir in sectionDirs)
        {
            var sectionSlug = Path.GetFileName(sectionDir).ToLowerInvariant();
            var section = await db.Sections.FirstOrDefaultAsync(s => s.Slug == sectionSlug, ct);
            if (section == null)
            {
                section = new Section
                {
                    Id = Guid.NewGuid(),
                    Slug = sectionSlug,
                    Title = TitleizeSlug(sectionSlug),
                    Description = string.Empty,
                    Order = sectionDirs.IndexOf(sectionDir),
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                };
                db.Sections.Add(section);
                await db.SaveChangesAsync(ct);
                log.LogInformation("Created section {Slug}", sectionSlug);
            }

            var files = Directory.EnumerateFiles(sectionDir, "*.md").OrderBy(x => x).ToList();
            for (var i = 0; i < files.Count; i++)
            {
                var path = files[i];
                var name = Path.GetFileNameWithoutExtension(path);
                var slug = StripOrderPrefix(name);
                var raw = await File.ReadAllTextAsync(path, ct);

                var (frontmatter, body) = SplitFrontmatter(raw);
                var (bodyWithoutQuiz, quizJson) = SplitQuiz(body);

                Dictionary<string, object?> meta;
                try
                {
                    meta = string.IsNullOrWhiteSpace(frontmatter)
                        ? new()
                        : Yaml.Deserialize<Dictionary<string, object?>>(frontmatter)
                          ?? new Dictionary<string, object?>();
                }
                catch (Exception ex)
                {
                    log.LogWarning(ex, "Bad frontmatter in {File}, skipping", path);
                    continue;
                }

                string? Get(params string[] keys) => keys
                    .Select(k => meta.TryGetValue(k, out var v) ? v?.ToString() : null)
                    .FirstOrDefault(s => !string.IsNullOrWhiteSpace(s));

                int? GetInt(string key) => meta.TryGetValue(key, out var v) && v != null
                    && int.TryParse(v.ToString(), out var n)
                    ? n
                    : null;

                var existing = await db.Lessons
                    .FirstOrDefaultAsync(l => l.SectionId == section.Id && l.Slug == slug, ct);

                if (existing == null)
                {
                    existing = new Lesson
                    {
                        Id = Guid.NewGuid(),
                        SectionId = section.Id,
                        Slug = slug,
                        Order = i,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow,
                    };
                    db.Lessons.Add(existing);
                }

                existing.Title = Get("title") ?? TitleizeSlug(slug);
                existing.Description = Get("description") ?? string.Empty;
                existing.BodyMd = bodyWithoutQuiz.TrimEnd();
                existing.ImageUrl = Get("imageurl", "image_url", "image");
                existing.EstimatedMinutes = GetInt("estimatedminutes")
                    ?? GetInt("estimated_minutes");
                existing.AcademicDefinition = Get("academicdefinition", "academic_definition");
                existing.Order = i;
                existing.Version = (existing.Version == 0 ? 1 : existing.Version);
                existing.UpdatedAt = DateTime.UtcNow;

                await db.SaveChangesAsync(ct);

                if (!string.IsNullOrWhiteSpace(quizJson))
                {
                    await ImportQuizAsync(existing, quizJson!, ct);
                }

                totalLessons++;
            }
        }

        return totalLessons;
    }

    private async Task ImportQuizAsync(Lesson lesson, string json, CancellationToken ct)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Array) return;

            var quiz = await db.Quizzes
                .Include(q => q.Questions)
                    .ThenInclude(q => q.Options)
                .FirstOrDefaultAsync(q => q.LessonId == lesson.Id, ct);

            if (quiz == null)
            {
                quiz = new Quiz
                {
                    Id = Guid.NewGuid(),
                    LessonId = lesson.Id,
                    Slug = $"{lesson.Slug}-self-check",
                    Title = $"Самопроверка: {lesson.Title}",
                    Description = string.Empty,
                    RewardXp = 0,
                    RewardBuyingPower = 0,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                };
                db.Quizzes.Add(quiz);
            }
            else
            {
                db.QuizQuestions.RemoveRange(quiz.Questions);
            }

            var order = 0;
            foreach (var qEl in root.EnumerateArray())
            {
                var questionText = qEl.TryGetProperty("question", out var qt) ? qt.GetString() ?? "" : "";
                var optionsArr = qEl.TryGetProperty("options", out var opts)
                    && opts.ValueKind == JsonValueKind.Array
                    ? opts.EnumerateArray().Select(o => o.GetString() ?? "").ToList()
                    : new List<string>();
                var correctIndex = qEl.TryGetProperty("correctIndex", out var ci) && ci.ValueKind == JsonValueKind.Number
                    ? ci.GetInt32() : 0;
                var explanation = qEl.TryGetProperty("explanation", out var ex) ? ex.GetString() : null;

                var question = new QuizQuestion
                {
                    Id = Guid.NewGuid(),
                    QuizId = quiz.Id,
                    Text = questionText,
                    AllowsMultiple = false,
                    Order = order++,
                };
                for (var oi = 0; oi < optionsArr.Count; oi++)
                {
                    question.Options.Add(new QuizOption
                    {
                        Id = Guid.NewGuid(),
                        QuestionId = question.Id,
                        Text = optionsArr[oi],
                        IsCorrect = oi == correctIndex,
                        Explanation = oi == correctIndex ? explanation : null,
                        Order = oi,
                    });
                }
                quiz.Questions.Add(question);
            }
            quiz.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Failed to import quiz for {Lesson}", lesson.Slug);
        }
    }

    private static (string Frontmatter, string Body) SplitFrontmatter(string raw)
    {
        var m = Frontmatter.Match(raw);
        if (!m.Success) return (string.Empty, raw);
        return (m.Groups["yaml"].Value, m.Groups["body"].Value);
    }

    private static (string Body, string? Quiz) SplitQuiz(string body)
    {
        var m = QuizBlock.Match(body);
        if (!m.Success) return (body, null);
        var withoutQuiz = body[..m.Index].TrimEnd();
        return (withoutQuiz, m.Groups["json"].Value.Trim());
    }

    private static string StripOrderPrefix(string name)
    {
        var m = Regex.Match(name, @"^\d+[-_](?<rest>.+)$");
        return (m.Success ? m.Groups["rest"].Value : name).ToLowerInvariant();
    }

    private static string TitleizeSlug(string slug)
    {
        if (string.IsNullOrEmpty(slug)) return slug;
        var s = slug.Replace('-', ' ').Replace('_', ' ');
        return char.ToUpper(s[0]) + s[1..];
    }
}
