using Aloria.Api.Data;
using Aloria.Api.Domain;
using Aloria.Api.Endpoints;
using Aloria.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;

var builder = WebApplication.CreateBuilder(args);

// ----- Конфигурация БД ----------------------------------------------------
var dbProvider = builder.Configuration["Db:Provider"] ?? "sqlite";
var sqliteConnStr = builder.Configuration.GetConnectionString("Sqlite")
    ?? "Data Source=aloria.db";
// для будущего:
// var pgConnStr = builder.Configuration.GetConnectionString("Postgres");

if (dbProvider == "sqlite")
{
    builder.Services.AddDbContext<AloriaDbContext>(o => o.UseSqlite(sqliteConnStr));
}
// else if (dbProvider == "postgres")
// {
//     builder.Services.AddDbContext<AloriaDbContext>(o => o.UseNpgsql(pgConnStr));
// }
else
{
    throw new InvalidOperationException($"Unknown Db:Provider '{dbProvider}'");
}

// ----- Сервисы ------------------------------------------------------------
builder.Services.AddScoped<UserService>();
builder.Services.AddScoped<GrantService>();
builder.Services.AddScoped<QuizService>();
builder.Services.AddScoped<AchievementEvaluator>();
builder.Services.AddScoped<AuditLogger>();
builder.Services.AddScoped<MarkdownLessonImporter>();
builder.Services.AddScoped<IBrokerageGateway, StubBrokerageGateway>();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddOpenApi();

builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
    .AllowAnyOrigin()
    .AllowAnyMethod()
    .AllowAnyHeader()
    .WithExposedHeaders("Idempotency-Key")));

// HTTP-only для локальной разработки и доступа с iPhone в локалке.
// На вебе мобилки нет требования к TLS пока сидим за nginx/реверсом.
builder.WebHost.ConfigureKestrel(o =>
{
    var port = int.Parse(builder.Configuration["Port"] ?? "5050");
    o.ListenAnyIP(port);
});

var app = builder.Build();

// ----- Bootstrap БД -------------------------------------------------------
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AloriaDbContext>();
    await db.Database.EnsureCreatedAsync();

    // Авто-импорт markdown уроков из Flutter-проекта при первом запуске
    if (!await db.Sections.AnyAsync())
    {
        var importer = scope.ServiceProvider.GetRequiredService<MarkdownLessonImporter>();
        var contentRoot = app.Environment.ContentRootPath;
        var lessonsDir = Path.GetFullPath(Path.Combine(contentRoot, "../../..", "assets", "lessons"));
        var imported = await importer.ImportFromFlutterAsync(lessonsDir);
        app.Logger.LogInformation("Seeded {Count} lessons from {Dir}", imported, lessonsDir);

        await SeedDefaultAchievementsAsync(db);
    }
}

// ----- Pipeline -----------------------------------------------------------
app.UseCors();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
    app.MapOpenApi();
}

// Раздача загруженных картинок
var uploadsPath = Path.Combine(app.Environment.ContentRootPath, "uploads");
Directory.CreateDirectory(uploadsPath);
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(uploadsPath),
    RequestPath = "/uploads",
});

app.MapGet("/", () => Results.Ok(new { name = "aloria-api", version = "0.1.0", time = DateTime.UtcNow }));
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.MapLearningEndpoints();
app.MapQuizEndpoints();
app.MapProgressEndpoints();
app.MapAdminEndpoints();

app.Run();

// ---------------------------------------------------------------------------
static async Task SeedDefaultAchievementsAsync(AloriaDbContext db)
{
    var defaults = new[]
    {
        new Achievement { Id = Guid.NewGuid(), Code = "first_lesson",  Title = "Первый урок",      Description = "Завершён первый урок обучения.", IconName = "menu_book",    Condition = AchievementCondition.LessonsCompleted, ConditionThreshold = 1,  RewardXp = 25, Order = 1 },
        new Achievement { Id = Guid.NewGuid(), Code = "five_lessons",  Title = "Пятёрка уроков",   Description = "Завершено 5 уроков.",            IconName = "auto_stories",  Condition = AchievementCondition.LessonsCompleted, ConditionThreshold = 5,  RewardXp = 75, Order = 2 },
        new Achievement { Id = Guid.NewGuid(), Code = "first_quiz",    Title = "Первая проверка",  Description = "Сдан первый тест.",              IconName = "fact_check",    Condition = AchievementCondition.QuizzesPassed,    ConditionThreshold = 1,  RewardXp = 25, Order = 3 },
        new Achievement { Id = Guid.NewGuid(), Code = "five_quizzes",  Title = "Пять тестов",      Description = "Сдано 5 тестов.",                IconName = "school",        Condition = AchievementCondition.QuizzesPassed,    ConditionThreshold = 5,  RewardXp = 75, Order = 4 },
        new Achievement { Id = Guid.NewGuid(), Code = "streak_3",      Title = "Три дня подряд",   Description = "Серия 3 дня.",                   IconName = "local_fire_department", Condition = AchievementCondition.StreakDays,    ConditionThreshold = 3,  RewardXp = 30, Order = 5 },
        new Achievement { Id = Guid.NewGuid(), Code = "streak_7",      Title = "Неделя в Aloria",  Description = "Серия 7 дней.",                  IconName = "local_fire_department", Condition = AchievementCondition.StreakDays,    ConditionThreshold = 7,  RewardXp = 80, Order = 6 },
        new Achievement { Id = Guid.NewGuid(), Code = "xp_100",        Title = "Сотка XP",         Description = "Набрано 100 XP.",                IconName = "trending_up",   Condition = AchievementCondition.TotalXp,          ConditionThreshold = 100, RewardXp = 0,  Order = 7 },
        new Achievement { Id = Guid.NewGuid(), Code = "xp_500",        Title = "Полтыщи XP",       Description = "Набрано 500 XP.",                IconName = "trending_up",   Condition = AchievementCondition.TotalXp,          ConditionThreshold = 500, RewardXp = 0,  Order = 8 },
        new Achievement { Id = Guid.NewGuid(), Code = "first_trade",   Title = "Первая сделка",    Description = "Открыта первая позиция.",         IconName = "rocket_launch", Condition = AchievementCondition.FirstPositionOpened, ConditionThreshold = 0, RewardXp = 50, Order = 9 },
    };
    db.Achievements.AddRange(defaults);
    await db.SaveChangesAsync();
}
