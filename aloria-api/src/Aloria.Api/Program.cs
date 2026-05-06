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
    // Награда — в виртуальных рублях покупательной способности. XP отключён в UI,
    // он остаётся в БД как технический счётчик, но за ачивки его не выдаём.
    var defaults = new[]
    {
        new Achievement { Id = Guid.NewGuid(), Code = "first_lesson",      Title = "Первый шаг",           Description = "Прочитан первый урок. Каждый путь начинается с одного шага.",                            IconName = "menu_book",             Condition = AchievementCondition.LessonsCompleted,    ConditionThreshold = 1,  RewardBuyingPower = 250,  Order = 1 },
        new Achievement { Id = Guid.NewGuid(), Code = "five_lessons",      Title = "Втягиваюсь",           Description = "Пройдено 5 уроков. Можно сказать, разогрелись.",                                          IconName = "auto_stories",          Condition = AchievementCondition.LessonsCompleted,    ConditionThreshold = 5,  RewardBuyingPower = 1000, Order = 2 },
        new Achievement { Id = Guid.NewGuid(), Code = "ten_lessons",       Title = "Дошли до полуфинала",  Description = "Пройдено 10 уроков. Уже понятно, как устроен рынок.",                                    IconName = "auto_stories",          Condition = AchievementCondition.LessonsCompleted,    ConditionThreshold = 10, RewardBuyingPower = 2500, Order = 3 },
        new Achievement { Id = Guid.NewGuid(), Code = "first_quiz",        Title = "Самопроверка",         Description = "Сдан первый тест. Понимание подтверждено.",                                              IconName = "fact_check",            Condition = AchievementCondition.QuizzesPassed,       ConditionThreshold = 1,  RewardBuyingPower = 500,  Order = 4 },
        new Achievement { Id = Guid.NewGuid(), Code = "five_quizzes",      Title = "Пятёрка по тестам",    Description = "Пять тестов сданы без ошибок. Это уровень.",                                             IconName = "school",                Condition = AchievementCondition.QuizzesPassed,       ConditionThreshold = 5,  RewardBuyingPower = 1500, Order = 5 },
        new Achievement { Id = Guid.NewGuid(), Code = "ten_quizzes",       Title = "Знаток теории",        Description = "Десять тестов сданы. Теорию знаешь как родную.",                                          IconName = "workspace_premium",     Condition = AchievementCondition.QuizzesPassed,       ConditionThreshold = 10, RewardBuyingPower = 3500, Order = 6 },
        new Achievement { Id = Guid.NewGuid(), Code = "streak_3",          Title = "Три дня подряд",       Description = "Заходишь в приложение три дня подряд. Привычка формируется.",                            IconName = "local_fire_department", Condition = AchievementCondition.StreakDays,          ConditionThreshold = 3,  RewardBuyingPower = 500,  Order = 7 },
        new Achievement { Id = Guid.NewGuid(), Code = "streak_7",          Title = "Неделя в потоке",      Description = "Неделя без перерывов. Серьёзный заход.",                                                  IconName = "local_fire_department", Condition = AchievementCondition.StreakDays,          ConditionThreshold = 7,  RewardBuyingPower = 1500, Order = 8 },
        new Achievement { Id = Guid.NewGuid(), Code = "streak_30",         Title = "Месяц упорства",       Description = "30 дней подряд. Это уже лайфстайл.",                                                      IconName = "verified",              Condition = AchievementCondition.StreakDays,          ConditionThreshold = 30, RewardBuyingPower = 5000, Order = 9 },
        new Achievement { Id = Guid.NewGuid(), Code = "first_trade",       Title = "Первая сделка",        Description = "Открыта первая позиция в симуляторе. Теория встретила практику.",                         IconName = "rocket_launch",         Condition = AchievementCondition.FirstPositionOpened, ConditionThreshold = 0,  RewardBuyingPower = 1000, Order = 10 },
    };
    db.Achievements.AddRange(defaults);
    await db.SaveChangesAsync();
}
