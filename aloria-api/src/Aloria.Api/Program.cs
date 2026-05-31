using Aloria.Api.Data;
using Aloria.Api.Domain;
using Aloria.Api.Endpoints;
using Aloria.Api.Services;
using Aloria.Api.Services.Push;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;

var builder = WebApplication.CreateBuilder(args);

// CLI: `dotnet run -- --seed` — переимпортировать markdown-уроки в существующую
// БД (идемпотентно, без сброса) и выйти, не поднимая сервер.
var seedOnly = args.Contains("--seed");

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
builder.Services.AddSingleton<IPushSender, FcmPushSender>();
builder.Services.AddScoped<PushDispatcher>();

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

    // Лёгкая ручная миграция для таблиц, добавленных уже после первого
    // создания БД. EnsureCreated к существующей БД новые таблицы не докатывает.
    await db.Database.ExecuteSqlRawAsync(@"
        CREATE TABLE IF NOT EXISTS ""UserEvents"" (
            ""Id"" TEXT NOT NULL CONSTRAINT ""PK_UserEvents"" PRIMARY KEY,
            ""UserId"" TEXT NOT NULL,
            ""Code"" TEXT NOT NULL,
            ""OccurredAt"" TEXT NOT NULL,
            CONSTRAINT ""FK_UserEvents_Users_UserId"" FOREIGN KEY (""UserId"")
                REFERENCES ""Users"" (""Id"") ON DELETE CASCADE
        );
        CREATE UNIQUE INDEX IF NOT EXISTS ""IX_UserEvents_UserId_Code""
            ON ""UserEvents"" (""UserId"", ""Code"");
    ");

    // Колонки practice* для уроков («попробуй вживую»). EnsureCreated не
    // докатывает новые колонки к существующей БД, а у SQLite нет ADD COLUMN IF
    // NOT EXISTS — поэтому добавляем через try/catch (идемпотентно). SQL —
    // строковые литералы (без интерполяции/конкатенации), чтобы не ловить EF1002/1003.
    try
    {
        await db.Database.ExecuteSqlRawAsync(
            "ALTER TABLE \"Lessons\" ADD COLUMN \"PracticeSymbol\" TEXT");
    }
    catch { /* колонка уже существует */ }
    try
    {
        await db.Database.ExecuteSqlRawAsync(
            "ALTER TABLE \"Lessons\" ADD COLUMN \"PracticeText\" TEXT");
    }
    catch { /* колонка уже существует */ }
    try
    {
        await db.Database.ExecuteSqlRawAsync(
            "ALTER TABLE \"Lessons\" ADD COLUMN \"RecallPrompt\" TEXT");
    }
    catch { /* колонка уже существует */ }
    try
    {
        await db.Database.ExecuteSqlRawAsync(
            "ALTER TABLE \"Lessons\" ADD COLUMN \"RecallAnswer\" TEXT");
    }
    catch { /* колонка уже существует */ }
    try
    {
        await db.Database.ExecuteSqlRawAsync(
            "ALTER TABLE \"Lessons\" ADD COLUMN \"Group\" TEXT");
    }
    catch { /* колонка уже существует */ }

    // Таблица разнесённого повторения (recall). EnsureCreated не создаёт её в
    // уже существующей БД — добавляем вручную, идемпотентно.
    await db.Database.ExecuteSqlRawAsync(@"
        CREATE TABLE IF NOT EXISTS ""ReviewItems"" (
            ""Id"" TEXT NOT NULL CONSTRAINT ""PK_ReviewItems"" PRIMARY KEY,
            ""UserId"" TEXT NOT NULL,
            ""LessonId"" TEXT NOT NULL,
            ""Repetitions"" INTEGER NOT NULL,
            ""EaseFactor"" REAL NOT NULL,
            ""IntervalDays"" INTEGER NOT NULL,
            ""NextDueAt"" TEXT NOT NULL,
            ""UpdatedAt"" TEXT NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS ""IX_ReviewItems_UserId_LessonId""
            ON ""ReviewItems"" (""UserId"", ""LessonId"");
    ");

    await db.Database.ExecuteSqlRawAsync(@"
        CREATE TABLE IF NOT EXISTS ""DeviceTokens"" (
            ""Id"" TEXT NOT NULL CONSTRAINT ""PK_DeviceTokens"" PRIMARY KEY,
            ""UserId"" TEXT NOT NULL,
            ""Token"" TEXT NOT NULL,
            ""Platform"" TEXT NOT NULL,
            ""Disabled"" INTEGER NOT NULL,
            ""CreatedAt"" TEXT NOT NULL,
            ""LastSeenAt"" TEXT NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS ""IX_DeviceTokens_Token""
            ON ""DeviceTokens"" (""Token"");
    ");

    // r11 — спиральная модель. Добавляем колонки Section/Lesson и новые
    // таблицы. ALTER в SQLite не поддерживает IF NOT EXISTS, поэтому
    // оборачиваем в try/catch. Это переходная мера до миграции на EF Migrations.
    foreach (var alter in new[]
    {
        "ALTER TABLE \"Sections\" ADD COLUMN \"Kind\" TEXT NOT NULL DEFAULT 'stage'",
        "ALTER TABLE \"Sections\" ADD COLUMN \"IsOptional\" INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE \"Sections\" ADD COLUMN \"IconName\" TEXT",
        "ALTER TABLE \"Sections\" ADD COLUMN \"Tint\" TEXT",
        "ALTER TABLE \"Sections\" ADD COLUMN \"Goal\" TEXT",
        "ALTER TABLE \"Sections\" ADD COLUMN \"TargetMinutes\" INTEGER",
        "ALTER TABLE \"Sections\" ADD COLUMN \"UnlockRuleJson\" TEXT",
        "ALTER TABLE \"Lessons\" ADD COLUMN \"RoleHint\" TEXT",
        "ALTER TABLE \"Lessons\" ADD COLUMN \"IsCapstone\" INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE \"Lessons\" ADD COLUMN \"PracticeRequirementCode\" TEXT",
    })
    {
        try { await db.Database.ExecuteSqlRawAsync(alter); }
        catch { /* колонка уже существует */ }
    }

    await db.Database.ExecuteSqlRawAsync(@"
        CREATE TABLE IF NOT EXISTS ""Concepts"" (
            ""Id"" TEXT NOT NULL CONSTRAINT ""PK_Concepts"" PRIMARY KEY,
            ""Slug"" TEXT NOT NULL,
            ""Title"" TEXT NOT NULL,
            ""ShortDefinition"" TEXT NOT NULL,
            ""IconName"" TEXT,
            ""Order"" INTEGER NOT NULL,
            ""CreatedAt"" TEXT NOT NULL,
            ""UpdatedAt"" TEXT NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS ""IX_Concepts_Slug"" ON ""Concepts"" (""Slug"");

        CREATE TABLE IF NOT EXISTS ""LessonConcepts"" (
            ""LessonId"" TEXT NOT NULL,
            ""ConceptId"" TEXT NOT NULL,
            ""Role"" INTEGER NOT NULL,
            ""Depth"" INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY (""LessonId"", ""ConceptId"", ""Role""),
            FOREIGN KEY (""LessonId"")  REFERENCES ""Lessons""  (""Id"") ON DELETE CASCADE,
            FOREIGN KEY (""ConceptId"") REFERENCES ""Concepts"" (""Id"") ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS ""IX_LessonConcepts_ConceptId_Role""
            ON ""LessonConcepts"" (""ConceptId"", ""Role"");

        CREATE TABLE IF NOT EXISTS ""PracticeRequirements"" (
            ""Id"" TEXT NOT NULL CONSTRAINT ""PK_PracticeRequirements"" PRIMARY KEY,
            ""SectionId"" TEXT NOT NULL,
            ""Code"" TEXT NOT NULL,
            ""Title"" TEXT NOT NULL,
            ""Description"" TEXT NOT NULL DEFAULT '',
            ""Kind"" INTEGER NOT NULL,
            ""ParamsJson"" TEXT NOT NULL DEFAULT '{}',
            ""Order"" INTEGER NOT NULL DEFAULT 0,
            ""IsOptional"" INTEGER NOT NULL DEFAULT 0,
            ""RewardBuyingPower"" INTEGER NOT NULL DEFAULT 0,
            ""ConceptSlugsJson"" TEXT NOT NULL DEFAULT '[]',
            ""Archived"" INTEGER NOT NULL DEFAULT 0,
            ""CreatedAt"" TEXT NOT NULL,
            ""UpdatedAt"" TEXT NOT NULL,
            FOREIGN KEY (""SectionId"") REFERENCES ""Sections"" (""Id"") ON DELETE CASCADE
        );
        CREATE UNIQUE INDEX IF NOT EXISTS ""IX_PracticeRequirements_SectionId_Code""
            ON ""PracticeRequirements"" (""SectionId"", ""Code"");
        CREATE INDEX IF NOT EXISTS ""IX_PracticeRequirements_Archived""
            ON ""PracticeRequirements"" (""Archived"");

        CREATE TABLE IF NOT EXISTS ""UserStageProgress"" (
            ""Id"" TEXT NOT NULL CONSTRAINT ""PK_UserStageProgress"" PRIMARY KEY,
            ""UserId"" TEXT NOT NULL,
            ""SectionId"" TEXT NOT NULL,
            ""Status"" INTEGER NOT NULL DEFAULT 0,
            ""LessonsCompletedCount"" INTEGER NOT NULL DEFAULT 0,
            ""PracticeFulfilledCount"" INTEGER NOT NULL DEFAULT 0,
            ""StartedAt"" TEXT,
            ""CompletedAt"" TEXT,
            ""UpdatedAt"" TEXT NOT NULL,
            FOREIGN KEY (""UserId"")    REFERENCES ""Users""    (""Id"") ON DELETE CASCADE,
            FOREIGN KEY (""SectionId"") REFERENCES ""Sections"" (""Id"") ON DELETE CASCADE
        );
        CREATE UNIQUE INDEX IF NOT EXISTS ""IX_UserStageProgress_UserId_SectionId""
            ON ""UserStageProgress"" (""UserId"", ""SectionId"");

        CREATE TABLE IF NOT EXISTS ""UserLessonProgress"" (
            ""Id"" TEXT NOT NULL CONSTRAINT ""PK_UserLessonProgress"" PRIMARY KEY,
            ""UserId"" TEXT NOT NULL,
            ""LessonId"" TEXT NOT NULL,
            ""Started"" INTEGER NOT NULL DEFAULT 0,
            ""RecallAttempted"" INTEGER NOT NULL DEFAULT 0,
            ""QuizPassed"" INTEGER NOT NULL DEFAULT 0,
            ""FirstOpenedAt"" TEXT,
            ""LastInteractionAt"" TEXT,
            ""UpdatedAt"" TEXT NOT NULL,
            FOREIGN KEY (""UserId"")   REFERENCES ""Users""   (""Id"") ON DELETE CASCADE,
            FOREIGN KEY (""LessonId"") REFERENCES ""Lessons"" (""Id"") ON DELETE CASCADE
        );
        CREATE UNIQUE INDEX IF NOT EXISTS ""IX_UserLessonProgress_UserId_LessonId""
            ON ""UserLessonProgress"" (""UserId"", ""LessonId"");

        CREATE TABLE IF NOT EXISTS ""UserConceptMastery"" (
            ""Id"" TEXT NOT NULL CONSTRAINT ""PK_UserConceptMastery"" PRIMARY KEY,
            ""UserId"" TEXT NOT NULL,
            ""ConceptId"" TEXT NOT NULL,
            ""Level"" INTEGER NOT NULL DEFAULT 0,
            ""SourcesJson"" TEXT NOT NULL DEFAULT '[]',
            ""UpdatedAt"" TEXT NOT NULL,
            FOREIGN KEY (""UserId"")    REFERENCES ""Users""    (""Id"") ON DELETE CASCADE,
            FOREIGN KEY (""ConceptId"") REFERENCES ""Concepts"" (""Id"") ON DELETE CASCADE
        );
        CREATE UNIQUE INDEX IF NOT EXISTS ""IX_UserConceptMastery_UserId_ConceptId""
            ON ""UserConceptMastery"" (""UserId"", ""ConceptId"");

        CREATE TABLE IF NOT EXISTS ""UserPracticeFulfillments"" (
            ""Id"" TEXT NOT NULL CONSTRAINT ""PK_UserPracticeFulfillments"" PRIMARY KEY,
            ""UserId"" TEXT NOT NULL,
            ""PracticeRequirementId"" TEXT NOT NULL,
            ""FulfilledAt"" TEXT NOT NULL,
            ""EvidenceJson"" TEXT NOT NULL DEFAULT '{}',
            ""IdempotencyKey"" TEXT NOT NULL,
            FOREIGN KEY (""UserId"") REFERENCES ""Users"" (""Id"") ON DELETE CASCADE,
            FOREIGN KEY (""PracticeRequirementId"") REFERENCES ""PracticeRequirements"" (""Id"") ON DELETE CASCADE
        );
        CREATE UNIQUE INDEX IF NOT EXISTS ""IX_UserPracticeFulfillments_UserId_PracticeRequirementId""
            ON ""UserPracticeFulfillments"" (""UserId"", ""PracticeRequirementId"");
        CREATE UNIQUE INDEX IF NOT EXISTS ""IX_UserPracticeFulfillments_IdempotencyKey""
            ON ""UserPracticeFulfillments"" (""IdempotencyKey"");

        CREATE TABLE IF NOT EXISTS ""TradeEvents"" (
            ""Id"" TEXT NOT NULL CONSTRAINT ""PK_TradeEvents"" PRIMARY KEY,
            ""UserId"" TEXT NOT NULL,
            ""Type"" INTEGER NOT NULL,
            ""Symbol"" TEXT NOT NULL DEFAULT '',
            ""AssetClass"" TEXT NOT NULL DEFAULT '',
            ""Qty"" REAL NOT NULL DEFAULT 0,
            ""Price"" REAL,
            ""OccurredAt"" TEXT NOT NULL,
            ""IdempotencyKey"" TEXT NOT NULL,
            ""PayloadJson"" TEXT NOT NULL DEFAULT '{}',
            FOREIGN KEY (""UserId"") REFERENCES ""Users"" (""Id"") ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS ""IX_TradeEvents_UserId_OccurredAt""
            ON ""TradeEvents"" (""UserId"", ""OccurredAt"");
        CREATE UNIQUE INDEX IF NOT EXISTS ""IX_TradeEvents_IdempotencyKey""
            ON ""TradeEvents"" (""IdempotencyKey"");
    ");

    // Импорт markdown-уроков: при первом запуске (пустая БД) либо явно по флагу
    // --seed. Импортёр идемпотентный — обновляет уроки по (section, slug) и
    // добавляет новые, поэтому повторный прогон безопасен.
    if (seedOnly || !await db.Sections.AnyAsync())
    {
        var importer = scope.ServiceProvider.GetRequiredService<MarkdownLessonImporter>();
        var contentRoot = app.Environment.ContentRootPath;
        var lessonsDir = Path.GetFullPath(Path.Combine(contentRoot, "../../..", "assets", "lessons"));
        var imported = await importer.ImportFromFlutterAsync(lessonsDir);
        app.Logger.LogInformation("Seeded {Count} lessons from {Dir}", imported, lessonsDir);
    }

    // Ачивки сидим один раз — только если их ещё нет (защита от дублей при --seed).
    if (!await db.Achievements.AnyAsync())
    {
        await SeedDefaultAchievementsAsync(db);
        app.Logger.LogInformation("Seeded default achievements");
    }

    if (!await db.Quizzes.AnyAsync(q => q.LessonId == null))
    {
        await SeedDefaultTopUpQuizzesAsync(db);
        app.Logger.LogInformation("Seeded default top-up quizzes");
    }
}

// Режим разового засева: уроки переимпортированы, сервер поднимать не нужно.
if (seedOnly)
{
    app.Logger.LogInformation("Seed completed (--seed), exiting without starting the server.");
    return;
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
app.MapDeviceEndpoints();

app.Run();

// ---------------------------------------------------------------------------
static async Task SeedDefaultTopUpQuizzesAsync(AloriaDbContext db)
{
    Quiz BuildQuiz(string slug, string title, string description, int reward, List<(string text, bool multi, List<(string, bool, string?)> options)> qs)
    {
        var quiz = new Quiz
        {
            Id = Guid.NewGuid(),
            Slug = slug,
            Title = title,
            Description = description,
            RewardXp = 0,
            RewardBuyingPower = reward,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };
        var qOrder = 0;
        foreach (var (qText, multi, opts) in qs)
        {
            var question = new QuizQuestion
            {
                Id = Guid.NewGuid(),
                QuizId = quiz.Id,
                Text = qText,
                AllowsMultiple = multi,
                Order = qOrder++,
            };
            var oOrder = 0;
            foreach (var (oText, isCorrect, expl) in opts)
            {
                question.Options.Add(new QuizOption
                {
                    Id = Guid.NewGuid(),
                    QuestionId = question.Id,
                    Text = oText,
                    IsCorrect = isCorrect,
                    Explanation = isCorrect ? expl : null,
                    Order = oOrder++,
                });
            }
            quiz.Questions.Add(question);
        }
        return quiz;
    }

    var quizzes = new[]
    {
        BuildQuiz(
            slug: "topup-diversification",
            title: "Базовая диверсификация",
            description: "Как распределять капитал между активами и секторами, чтобы снизить волатильность.",
            reward: 5000,
            qs: new()
            {
                ("Что даёт диверсификация портфеля?", true, new()
                {
                    ("Снижает зависимость от результата одной компании или сектора", true, "Распределяя капитал, ты не привязан к успеху или неудаче одного эмитента."),
                    ("Гарантирует фиксированную доходность 20% в год", false, null),
                    ("Смягчает просадки за счёт разных классов активов", true, null),
                    ("Уменьшает риск, что весь портфель упадёт одновременно", true, null),
                }),
                ("Какой минимальный набор секторов помогает стартовой диверсификации?", false, new()
                {
                    ("Один сектор для концентрации", false, null),
                    ("3–5 разных секторов", true, "Достаточно нескольких независимых секторов, чтобы разнести риск."),
                    ("Десять и более секторов всегда обязательны", false, null),
                }),
                ("Что относится к разным классам активов?", true, new()
                {
                    ("Акции", true, null),
                    ("Облигации", true, "Облигации движутся менее коррелированно с акциями."),
                    ("Денежная позиция (cash)", true, null),
                    ("Только акции одного сектора", false, null),
                }),
            }),

        BuildQuiz(
            slug: "topup-orders",
            title: "Типы заявок",
            description: "Чем отличается рыночная заявка от лимитной и когда какую использовать.",
            reward: 3000,
            qs: new()
            {
                ("Что делает рыночная заявка?", false, new()
                {
                    ("Покупает/продаёт прямо сейчас по лучшей доступной цене", true, "Рыночная заявка исполняется мгновенно — пожертвовать ценой ради скорости."),
                    ("Покупает только если цена дойдёт до указанной", false, null),
                    ("Гарантирует точную цену исполнения", false, null),
                }),
                ("Какие риски у рыночной заявки в тонком стакане?", true, new()
                {
                    ("Цена может «убежать» — исполнение по сильно худшей цене", true, null),
                    ("Заявка не исполнится никогда", false, null),
                    ("Можно проскользнуть через несколько уровней стакана", true, "В тонком стакане один большой ордер съедает несколько уровней цен сразу."),
                }),
                ("Когда уместна лимитная заявка?", true, new()
                {
                    ("Когда ты готов ждать ради нужной цены", true, null),
                    ("Когда хочешь купить любой ценой как можно быстрее", false, null),
                    ("Когда хочешь зафиксировать максимально допустимую цену покупки", true, "Лимитка — это твоя страховка от неожиданно высокой цены."),
                }),
            }),

        BuildQuiz(
            slug: "topup-risk",
            title: "Управление риском",
            description: "Как ограничивать потери на одну позицию и не сжигать портфель за неделю.",
            reward: 4000,
            qs: new()
            {
                ("Что такое позиция в плюсе?", false, new()
                {
                    ("Текущая стоимость пакета бумаг выше суммы покупки", true, "Это нереализованная прибыль — она зафиксируется только при закрытии позиции."),
                    ("Брокер автоматически зачислил доход", false, null),
                    ("Гарантия будущей прибыли", false, null),
                }),
                ("Какой простой способ ограничить убыток на одной позиции?", false, new()
                {
                    ("Выставить стоп-лосс заранее", true, "Стоп-лосс — это автозакрытие позиции, если цена дошла до триггера."),
                    ("Игнорировать просадку и ждать", false, null),
                    ("Доливать каждый раз, как цена падает", false, null),
                }),
                ("Сколько от портфеля разумно рисковать на одной сделке?", false, new()
                {
                    ("Не больше 1–2%", true, "Это позволяет ошибиться много раз и не потерять весь капитал."),
                    ("30–50% всё нормально", false, null),
                    ("Весь портфель — иначе нет смысла", false, null),
                }),
            }),
    };

    db.Quizzes.AddRange(quizzes);
    await db.SaveChangesAsync();
}

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
