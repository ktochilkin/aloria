using System.Text.Json;
using System.Text.RegularExpressions;
using Aloria.Api.Data;
using Aloria.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Services;

/// <summary>
/// Импорт markdown-уроков из Flutter-проекта в БД. Поддерживает спиральную
/// модель курса: stages.json (метаданные этапов), concepts.json (каталог
/// концепций), practice.json в каждой папке этапа (требования практики),
/// и расширенный frontmatter уроков (introduces/deepens/applies/roleHint/
/// isCapstone/practiceRequirement). Идемпотентен — повторный вызов
/// безопасен.
/// </summary>
public class MarkdownLessonImporter(
    AloriaDbContext db,
    ILogger<MarkdownLessonImporter> log)
{
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

        // 1) Каталог концепций — спиральная сущность поверх уроков.
        var conceptIdBySlug = await UpsertConceptsAsync(lessonsDir, ct);

        // 2) Метаданные этапов: расширенный stages.json приоритетнее sections.json.
        var stageMeta = LoadStageMeta(lessonsDir);

        var sectionDirs = Directory.EnumerateDirectories(lessonsDir)
            .Where(d => !Path.GetFileName(d).StartsWith('.'))
            .OrderBy(x => x)
            .ToList();
        var totalLessons = 0;

        foreach (var sectionDir in sectionDirs)
        {
            var sectionSlug = Path.GetFileName(sectionDir).ToLowerInvariant();
            db.ChangeTracker.Clear();

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
                log.LogInformation("Created section {Slug}", sectionSlug);
            }

            // Метаданные раздела — из stages.json (расширенно) или sections.json (legacy).
            if (stageMeta.TryGetValue(sectionSlug, out var sm))
            {
                if (!string.IsNullOrWhiteSpace(sm.Title)) section.Title = sm.Title!;
                section.Description = sm.Subtitle ?? string.Empty;
                section.Order = sm.Order;
                section.Kind = sm.Kind ?? "stage";
                section.IsOptional = sm.IsOptional;
                section.IconName = sm.IconName;
                section.Tint = sm.Tint;
                section.Goal = sm.Goal;
                section.TargetMinutes = sm.TargetMinutes;
                section.UnlockRuleJson = sm.UnlockRuleJson;
            }
            section.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);

            // 3) Требования практики этапа — practice.json в папке.
            await UpsertPracticeRequirementsAsync(section, sectionDir, ct);

            // 4) Уроки этапа.
            var files = Directory.EnumerateFiles(sectionDir, "*.md").OrderBy(x => x).ToList();
            for (var i = 0; i < files.Count; i++)
            {
                db.ChangeTracker.Clear();

                var path = files[i];
                var name = Path.GetFileNameWithoutExtension(path);
                var slug = StripOrderPrefix(name);
                var raw = await File.ReadAllTextAsync(path, ct);

                var (frontmatter, body) = SplitFrontmatter(raw);
                var (bodyWithoutQuiz, quizJson) = SplitQuiz(body);

                var meta = ParseFrontmatter(frontmatter);

                string? Get(params string[] keys) => keys
                    .Select(k => meta.TryGetValue(k, out var v) ? v : null)
                    .FirstOrDefault(s => !string.IsNullOrWhiteSpace(s));

                int? GetInt(params string[] keys) =>
                    Get(keys) is { } s && int.TryParse(s, out var n) ? n : null;

                bool GetBool(params string[] keys) =>
                    Get(keys) is { } s && (s.Equals("true", StringComparison.OrdinalIgnoreCase)
                                           || s == "1" || s.Equals("yes", StringComparison.OrdinalIgnoreCase));

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
                existing.EstimatedMinutes = GetInt("estimatedMinutes", "estimated_minutes");
                existing.AcademicDefinition = Get("academicdefinition", "academic_definition");
                existing.PracticeSymbol = Get("practiceSymbol", "practice_symbol");
                existing.PracticeText = Get("practiceTask", "practiceText", "practice_task");
                existing.RecallPrompt = Get("recallPrompt", "recall_prompt");
                existing.RecallAnswer = Get("recallAnswer", "recall_answer");
                existing.Group = Get("group");
                existing.RoleHint = Get("roleHint", "role_hint");
                existing.IsCapstone = GetBool("isCapstone", "is_capstone");
                existing.PracticeRequirementCode = Get("practiceRequirement", "practice_requirement");
                existing.Order = i;
                existing.Version = (existing.Version == 0 ? 1 : existing.Version);
                existing.UpdatedAt = DateTime.UtcNow;

                await db.SaveChangesAsync(ct);

                // Связи концепций (delete-then-insert).
                await UpsertLessonConceptsAsync(existing, meta, conceptIdBySlug, ct);

                if (!string.IsNullOrWhiteSpace(quizJson))
                {
                    await ImportQuizAsync(existing, quizJson!, ct);
                }
                else
                {
                    await db.Quizzes.Where(q => q.LessonId == existing.Id).ExecuteDeleteAsync(ct);
                }

                totalLessons++;
            }
        }

        return totalLessons;
    }

    /// <summary>
    /// Загружает concepts.json и апсертит каталог концепций. Возвращает
    /// словарь slug → ConceptId для последующего связывания с уроками.
    /// </summary>
    private async Task<Dictionary<string, Guid>> UpsertConceptsAsync(string lessonsDir, CancellationToken ct)
    {
        var result = new Dictionary<string, Guid>(StringComparer.OrdinalIgnoreCase);
        var path = Path.Combine(lessonsDir, "concepts.json");
        if (!File.Exists(path))
        {
            log.LogInformation("concepts.json not found — skipping concept catalog");
            return result;
        }

        List<(string Slug, string Title, string Short, string? Icon, int Order)> catalog;
        try
        {
            using var doc = JsonDocument.Parse(await File.ReadAllTextAsync(path, ct));
            if (!doc.RootElement.TryGetProperty("concepts", out var arr) || arr.ValueKind != JsonValueKind.Array)
                return result;

            catalog = arr.EnumerateArray()
                .Select(el => (
                    Slug: el.TryGetProperty("id", out var i) ? i.GetString() ?? "" : "",
                    Title: el.TryGetProperty("title", out var t) ? t.GetString() ?? "" : "",
                    Short: el.TryGetProperty("shortDefinition", out var sd) ? sd.GetString() ?? "" : "",
                    Icon: el.TryGetProperty("icon", out var ic) ? ic.GetString() : null,
                    Order: el.TryGetProperty("order", out var o) && o.ValueKind == JsonValueKind.Number
                        ? o.GetInt32() : 0
                ))
                .Where(x => !string.IsNullOrWhiteSpace(x.Slug))
                .ToList();
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Failed to parse concepts.json");
            return result;
        }

        foreach (var (slug, title, shortDef, icon, order) in catalog)
        {
            db.ChangeTracker.Clear();
            var slugLc = slug.ToLowerInvariant();
            var concept = await db.Concepts.FirstOrDefaultAsync(c => c.Slug == slugLc, ct);
            if (concept == null)
            {
                concept = new Concept
                {
                    Id = Guid.NewGuid(),
                    Slug = slugLc,
                    Title = title,
                    ShortDefinition = shortDef,
                    IconName = icon,
                    Order = order,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                };
                db.Concepts.Add(concept);
            }
            else
            {
                concept.Title = title;
                concept.ShortDefinition = shortDef;
                concept.IconName = icon;
                concept.Order = order;
                concept.UpdatedAt = DateTime.UtcNow;
            }
            await db.SaveChangesAsync(ct);
            result[slugLc] = concept.Id;
        }

        log.LogInformation("Upserted {Count} concepts", result.Count);
        return result;
    }

    /// <summary>
    /// Загружает practice.json из папки этапа и апсертит требования практики.
    /// Требования, которых нет в файле, помечаются Archived = true (мягкое
    /// удаление, чтобы сохранить ссылки UserPracticeFulfillments).
    /// </summary>
    private async Task UpsertPracticeRequirementsAsync(Section section, string sectionDir, CancellationToken ct)
    {
        var path = Path.Combine(sectionDir, "practice.json");
        if (!File.Exists(path))
        {
            // Нет practice.json — архивируем все ранее заведённые требования этого этапа.
            await db.PracticeRequirements
                .Where(pr => pr.SectionId == section.Id && !pr.Archived)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(pr => pr.Archived, true)
                    .SetProperty(pr => pr.UpdatedAt, DateTime.UtcNow), ct);
            return;
        }

        List<RequirementSpec> specs;
        try
        {
            using var doc = JsonDocument.Parse(await File.ReadAllTextAsync(path, ct));
            if (!doc.RootElement.TryGetProperty("requirements", out var arr) || arr.ValueKind != JsonValueKind.Array)
            {
                specs = new();
            }
            else
            {
                specs = arr.EnumerateArray()
                    .Select((el, i) => new RequirementSpec
                    {
                        Code = el.TryGetProperty("code", out var c) ? c.GetString() ?? "" : "",
                        Title = el.TryGetProperty("title", out var t) ? t.GetString() ?? "" : "",
                        Description = el.TryGetProperty("description", out var d) ? d.GetString() ?? "" : "",
                        Kind = ParseKind(el.TryGetProperty("kind", out var k) ? k.GetString() : null),
                        ParamsJson = el.TryGetProperty("params", out var pj) ? pj.GetRawText() : "{}",
                        Order = i,
                        IsOptional = el.TryGetProperty("isOptional", out var o) && o.ValueKind == JsonValueKind.True,
                        RewardBuyingPower = el.TryGetProperty("rewardBuyingPower", out var rb)
                            && rb.ValueKind == JsonValueKind.Number ? rb.GetInt32() : 0,
                        ConceptSlugsJson = el.TryGetProperty("concepts", out var cs) ? cs.GetRawText() : "[]",
                    })
                    .Where(s => !string.IsNullOrWhiteSpace(s.Code))
                    .ToList();
            }
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Failed to parse practice.json in {Dir}", sectionDir);
            return;
        }

        var existing = await db.PracticeRequirements
            .Where(pr => pr.SectionId == section.Id)
            .ToListAsync(ct);

        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var spec in specs)
        {
            seen.Add(spec.Code);
            var req = existing.FirstOrDefault(pr => pr.Code.Equals(spec.Code, StringComparison.OrdinalIgnoreCase));
            if (req == null)
            {
                req = new PracticeRequirement
                {
                    Id = Guid.NewGuid(),
                    SectionId = section.Id,
                    Code = spec.Code,
                    CreatedAt = DateTime.UtcNow,
                };
                db.PracticeRequirements.Add(req);
            }
            req.Title = spec.Title;
            req.Description = spec.Description;
            req.Kind = spec.Kind;
            req.ParamsJson = spec.ParamsJson;
            req.Order = spec.Order;
            req.IsOptional = spec.IsOptional;
            req.RewardBuyingPower = spec.RewardBuyingPower;
            req.ConceptSlugsJson = spec.ConceptSlugsJson;
            req.Archived = false;
            req.UpdatedAt = DateTime.UtcNow;
        }

        // Архивируем требования, которые исчезли из practice.json.
        foreach (var orphan in existing.Where(pr => !seen.Contains(pr.Code)))
        {
            orphan.Archived = true;
            orphan.UpdatedAt = DateTime.UtcNow;
        }

        await db.SaveChangesAsync(ct);
    }

    /// <summary>
    /// Заменяет связи LessonConcept для урока согласно frontmatter
    /// (introduces / deepens / applies). Удаление-затем-вставка, потому что
    /// concept-связи легко становятся висячими при правках.
    /// </summary>
    private async Task UpsertLessonConceptsAsync(
        Lesson lesson,
        Dictionary<string, string> meta,
        Dictionary<string, Guid> conceptIdBySlug,
        CancellationToken ct)
    {
        await db.LessonConcepts.Where(lc => lc.LessonId == lesson.Id).ExecuteDeleteAsync(ct);

        void AddRole(string key, ConceptRole role, int depth)
        {
            if (!meta.TryGetValue(key, out var raw)) return;
            foreach (var slug in ParseSlugList(raw))
            {
                if (!conceptIdBySlug.TryGetValue(slug, out var conceptId))
                {
                    log.LogWarning("Lesson {Lesson}: unknown concept slug '{Slug}' (role {Role})",
                        lesson.Slug, slug, role);
                    continue;
                }
                db.LessonConcepts.Add(new LessonConcept
                {
                    LessonId = lesson.Id,
                    ConceptId = conceptId,
                    Role = role,
                    Depth = depth,
                });
            }
        }

        AddRole("introduces", ConceptRole.Introduce, 1);
        AddRole("deepens", ConceptRole.Deepen, 2);
        AddRole("applies", ConceptRole.Apply, 3);

        await db.SaveChangesAsync(ct);
    }

    private async Task ImportQuizAsync(Lesson lesson, string json, CancellationToken ct)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Array) return;

            var quiz = await db.Quizzes
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
                await db.QuizQuestions.Where(q => q.QuizId == quiz.Id).ExecuteDeleteAsync(ct);
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
                db.QuizQuestions.Add(question);
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

    private static Dictionary<string, string> ParseFrontmatter(string frontmatter)
    {
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (string.IsNullOrWhiteSpace(frontmatter)) return map;

        foreach (var rawLine in frontmatter.Split('\n'))
        {
            var line = rawLine.TrimEnd('\r');
            if (string.IsNullOrWhiteSpace(line) || line.TrimStart().StartsWith('#')) continue;

            var idx = line.IndexOf(':');
            if (idx <= 0) continue;

            var key = line[..idx].Trim();
            var value = line[(idx + 1)..].Trim();

            if (value.Length >= 2 &&
                ((value[0] == '"' && value[^1] == '"') || (value[0] == '\'' && value[^1] == '\'')))
            {
                value = value[1..^1];
            }

            if (key.Length > 0) map[key] = value;
        }

        return map;
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

    /// <summary>
    /// Парсит inline-список из frontmatter: "[a, b, c]" → ["a","b","c"];
    /// "a" → ["a"]; пустая строка → []. YAML-список с переносом строк
    /// сейчас не поддерживается (frontmatter — плоский parser); пиши инлайн.
    /// </summary>
    private static IEnumerable<string> ParseSlugList(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) yield break;

        var trimmed = raw.Trim();
        if (trimmed.StartsWith('[') && trimmed.EndsWith(']'))
        {
            trimmed = trimmed[1..^1];
        }

        foreach (var part in trimmed.Split(','))
        {
            var s = part.Trim().Trim('"', '\'').Trim();
            if (!string.IsNullOrEmpty(s)) yield return s.ToLowerInvariant();
        }
    }

    private static PracticeKind ParseKind(string? raw) => raw?.Trim() switch
    {
        "OpenPosition" or "openPosition" or "open_position" => PracticeKind.OpenPosition,
        "HoldUntilEvent" or "holdUntilEvent" or "hold_until_event" => PracticeKind.HoldUntilEvent,
        "PlaceLimitOrder" or "placeLimitOrder" or "place_limit_order" => PracticeKind.PlaceLimitOrder,
        "CancelOrder" or "cancelOrder" or "cancel_order" => PracticeKind.CancelOrder,
        "ClosePosition" or "closePosition" or "close_position" => PracticeKind.ClosePosition,
        "ReachBuyingPower" or "reachBuyingPower" or "reach_buying_power" => PracticeKind.ReachBuyingPower,
        _ => PracticeKind.Custom,
    };

    /// <summary>
    /// Метаданные этапа: расширенный stages.json приоритетнее sections.json.
    /// При отсутствии обоих файлов раздел получает titleize-название.
    /// </summary>
    private static Dictionary<string, StageMeta> LoadStageMeta(string lessonsDir)
    {
        var map = new Dictionary<string, StageMeta>(StringComparer.OrdinalIgnoreCase);

        var stagesPath = Path.Combine(lessonsDir, "stages.json");
        if (File.Exists(stagesPath))
        {
            try
            {
                using var doc = JsonDocument.Parse(File.ReadAllText(stagesPath));
                if (doc.RootElement.TryGetProperty("stages", out var arr) && arr.ValueKind == JsonValueKind.Array)
                {
                    foreach (var el in arr.EnumerateArray())
                    {
                        var id = el.TryGetProperty("id", out var idEl) ? idEl.GetString() : null;
                        if (string.IsNullOrWhiteSpace(id)) continue;

                        map[id!.ToLowerInvariant()] = new StageMeta
                        {
                            Title = el.TryGetProperty("title", out var t) ? t.GetString() : null,
                            Subtitle = el.TryGetProperty("subtitle", out var s) ? s.GetString() : null,
                            Order = el.TryGetProperty("order", out var o) && o.ValueKind == JsonValueKind.Number
                                ? o.GetInt32() : 0,
                            Kind = el.TryGetProperty("kind", out var k) ? k.GetString() : "stage",
                            IsOptional = el.TryGetProperty("isOptional", out var io) && io.ValueKind == JsonValueKind.True,
                            IconName = el.TryGetProperty("icon", out var ic) ? ic.GetString() : null,
                            Tint = el.TryGetProperty("tint", out var tn) ? tn.GetString() : null,
                            Goal = el.TryGetProperty("goal", out var g) ? g.GetString() : null,
                            TargetMinutes = el.TryGetProperty("targetMinutes", out var tm) && tm.ValueKind == JsonValueKind.Number
                                ? tm.GetInt32() : (int?)null,
                            UnlockRuleJson = el.TryGetProperty("unlockRule", out var ur)
                                && ur.ValueKind != JsonValueKind.Null ? ur.GetRawText() : null,
                        };
                    }
                }
            }
            catch { /* битый stages.json — fallback на sections.json */ }
        }

        if (map.Count > 0) return map;

        // Fallback: sections.json (старый формат).
        var sectionsPath = Path.Combine(lessonsDir, "sections.json");
        if (!File.Exists(sectionsPath)) return map;
        try
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(sectionsPath));
            if (doc.RootElement.TryGetProperty("sections", out var arr) && arr.ValueKind == JsonValueKind.Array)
            {
                var order = 0;
                foreach (var el in arr.EnumerateArray())
                {
                    var id = el.TryGetProperty("id", out var idEl) ? idEl.GetString() : null;
                    if (!string.IsNullOrWhiteSpace(id))
                    {
                        map[id!.ToLowerInvariant()] = new StageMeta
                        {
                            Title = el.TryGetProperty("title", out var t) ? t.GetString() : null,
                            Subtitle = el.TryGetProperty("subtitle", out var s) ? s.GetString() : null,
                            Order = order,
                            Kind = "stage",
                            IconName = el.TryGetProperty("icon", out var ic) ? ic.GetString() : null,
                            Tint = el.TryGetProperty("tint", out var tn) ? tn.GetString() : null,
                        };
                    }
                    order++;
                }
            }
        }
        catch { }
        return map;
    }

    private class StageMeta
    {
        public string? Title { get; init; }
        public string? Subtitle { get; init; }
        public int Order { get; init; }
        public string? Kind { get; init; } = "stage";
        public bool IsOptional { get; init; }
        public string? IconName { get; init; }
        public string? Tint { get; init; }
        public string? Goal { get; init; }
        public int? TargetMinutes { get; init; }
        public string? UnlockRuleJson { get; init; }
    }

    private class RequirementSpec
    {
        public string Code { get; init; } = string.Empty;
        public string Title { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
        public PracticeKind Kind { get; init; }
        public string ParamsJson { get; init; } = "{}";
        public int Order { get; init; }
        public bool IsOptional { get; init; }
        public int RewardBuyingPower { get; init; }
        public string ConceptSlugsJson { get; init; } = "[]";
    }
}
