using Aloria.Api.Data;
using Aloria.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Services;

/// <summary>
/// Мок-наполнение экономического мира на шаге 1: секторы, компании тестовой
/// вселенной (совпадают с инструментами TEREX), стартовое макросостояние и
/// случайные новости. Позже писателем новостей/макро станет ИИ-режиссёр —
/// этот сидер уйдёт. Тексты — нейтрально-реалистичные, без обещаний доходности
/// и игровой лексики (см. CLAUDE.md §6).
/// </summary>
public static class MarketMockSeeder
{
    private record CompanySeed(string Symbol, string Name, string Theme, string SectorSlug);

    private static readonly (string Slug, string Title)[] SectorSeeds =
    {
        ("finance",   "Финансы"),
        ("consumer",  "Потребительский сектор"),
        ("retail",    "Ритейл"),
        ("food",      "Общепит"),
        ("logistics", "Логистика"),
        ("tech",      "Технологии"),
        ("travel",    "Туризм"),
    };

    private static readonly CompanySeed[] CompanySeeds =
    {
        new("ALBK", "Банк Алория",    "системный банк",           "finance"),
        new("ICEC", "Холодок и Ко",   "производитель мороженого", "consumer"),
        new("DRNK", "ЖивВода",        "напитки и вода",           "consumer"),
        new("HOME", "ДомоТехника",    "бытовая техника",          "consumer"),
        new("SHOP", "РядомМаркет",    "магазины у дома",          "retail"),
        new("FAST", "ШустроЕд",       "сеть быстрого питания",    "food"),
        new("BRED", "Тёплый Хлеб",    "кафе и пекарни",           "food"),
        new("MOVE", "ЕдемБыстро",     "доставка и логистика",     "logistics"),
        new("DIGI", "ЦифраЛаб",       "онлайн-сервисы и IT",      "tech"),
        new("TRVL", "Свободный Путь", "туризм и отдых",           "travel"),
    };

    private static readonly string[] EventTypes =
        { "earnings", "dividend", "guidance", "operations", "product" };

    /// <summary>Идемпотентный засев: секторы/компании/макро/новости — только если пусто.</summary>
    public static async Task SeedAsync(AloriaDbContext db, CancellationToken ct = default)
    {
        if (!await db.Sectors.AnyAsync(ct))
        {
            var sectors = SectorSeeds.Select((s, i) => new Sector
            {
                Id = Guid.NewGuid(), Slug = s.Slug, Title = s.Title, Order = i,
            }).ToList();
            db.Sectors.AddRange(sectors);

            var bySlug = sectors.ToDictionary(s => s.Slug);
            var companies = CompanySeeds.Select((c, i) => new Company
            {
                Id = Guid.NewGuid(), Symbol = c.Symbol, Name = c.Name, Theme = c.Theme,
                SectorId = bySlug[c.SectorSlug].Id, Order = i,
            }).ToList();
            db.Companies.AddRange(companies);
            await db.SaveChangesAsync(ct);
        }

        if (!await db.MacroStates.AnyAsync(ct))
        {
            db.MacroStates.Add(new MacroState
            {
                Id = Guid.NewGuid(),
                Regime = "expansion",
                KeyRate = 7.5,
                Inflation = 4.2,
                CycleDay = 1,
                CycleLength = 10,
                Source = "mock",
                UpdatedAt = DateTime.UtcNow,
            });
            await db.SaveChangesAsync(ct);
        }

        if (!await db.NewsItems.AnyAsync(ct))
        {
            await GenerateNewsAsync(db, count: 48, ct);
        }
    }

    /// <summary>Перегенерация мок-новостей (для админа): чистит и засевает заново.</summary>
    public static async Task RegenerateNewsAsync(AloriaDbContext db, int count, CancellationToken ct = default)
    {
        await db.NewsItems.ExecuteDeleteAsync(ct);
        await GenerateNewsAsync(db, count, ct);
    }

    private static async Task GenerateNewsAsync(AloriaDbContext db, int count, CancellationToken ct)
    {
        var rnd = new Random(20260629);
        var companies = await db.Companies.OrderBy(c => c.Order).ToListAsync(ct);
        var sectorBySymbol = CompanySeeds.ToDictionary(c => c.Symbol, c => c.SectorSlug);
        var now = DateTime.UtcNow;
        var items = new List<NewsItem>(count);

        for (var i = 0; i < count; i++)
        {
            var publish = now.AddMinutes(-rnd.Next(0, 7 * 24 * 60));

            // ~15% новостей — макро (без тикера/сектора).
            if (rnd.Next(100) < 15)
            {
                var (mh, mc, ms) = PickMacro(rnd);
                items.Add(new NewsItem
                {
                    Id = Guid.NewGuid(),
                    Headline = mh, Content = mc, Sentiment = ms,
                    PublishDate = publish, EventType = "macro", Scope = "macro",
                    Symbols = string.Empty, SectorSlug = null,
                    Urgency = 1 + rnd.Next(3), Source = "mock", CreatedAt = now,
                });
                continue;
            }

            var company = companies[rnd.Next(companies.Count)];
            var type = EventTypes[rnd.Next(EventTypes.Length)];
            var (h, c, s) = PickCompany(rnd, type, company.Name);
            items.Add(new NewsItem
            {
                Id = Guid.NewGuid(),
                Headline = h, Content = c, Sentiment = s,
                PublishDate = publish, EventType = type, Scope = "company",
                Symbols = company.Symbol,
                SectorSlug = sectorBySymbol.GetValueOrDefault(company.Symbol),
                Urgency = 1 + rnd.Next(3), Source = "mock", CreatedAt = now,
            });
        }

        db.NewsItems.AddRange(items);
        await db.SaveChangesAsync(ct);
    }

    // --- Шаблоны новостей --------------------------------------------------
    // Знак новости (sentiment) здесь случаен и независим: на шаге 1 это просто
    // разнообразие. Связь «сюрприз vs ожидания → цена» появится с ИИ-режиссёром.

    private static readonly string[] Sentiments = { "positive", "negative", "neutral" };

    private static (string, string, string) PickCompany(Random rnd, string type, string name)
    {
        var s = Sentiments[rnd.Next(Sentiments.Length)];
        return (type, s) switch
        {
            ("earnings", "positive") => ($"{name}: выручка выше ожиданий",
                $"{name} отчиталась о росте выручки и марже выше прогнозов аналитиков. Дальше важно, насколько хороший результат уже заложен в текущую цену.", s),
            ("earnings", "negative") => ($"{name}: прибыль под давлением издержек",
                $"{name} показала рост издержек и снижение маржи в свежем отчёте. Инвесторы пересматривают ожидания по будущим периодам.", s),
            ("earnings", _) => ($"{name} отчиталась без сюрпризов",
                $"Результаты {name} совпали с консенсусом — заметных отклонений от ожиданий нет. Реакция рынка зависит от того, чего ждали до публикации.", "neutral"),

            ("dividend", "positive") => ($"{name} рекомендовала дивиденды выше прошлого года",
                $"Совет директоров {name} рекомендовал дивиденды выше прошлогодних. Закрытие реестра ожидается в ближайшем цикле выплат.", s),
            ("dividend", "negative") => ($"{name} может урезать дивиденды",
                $"{name} рассматривает сокращение дивидендов ради сохранения денежного потока. Часть инвесторов, ориентированных на выплаты, пересматривает позиции.", s),
            ("dividend", _) => ($"{name} подтвердила дивидендную политику",
                $"{name} оставила дивидендную политику без изменений. Конкретный размер выплаты определят по итогам отчётного периода.", "neutral"),

            ("guidance", "positive") => ($"{name} повысила годовой прогноз",
                $"Менеджмент {name} повысил прогноз по выручке на год. Поддержит ли это котировки — покажет реакция стакана.", s),
            ("guidance", "negative") => ($"{name} снизила прогноз",
                $"{name} понизила ожидания по выручке из-за слабого спроса. Рынок закладывает более осторожный сценарий.", s),
            ("guidance", _) => ($"{name} сохранила прогноз",
                $"{name} подтвердила прежний годовой прогноз. Сигнал нейтральный — ориентиры не изменились.", "neutral"),

            ("operations", "positive") => ($"{name} расширяет операции",
                $"{name} сообщила о расширении сети и росте операционных показателей. Эффект на маржу будет виден в следующих отчётах.", s),
            ("operations", "negative") => ($"Сбой в работе {name}",
                $"{name} столкнулась со сбоем в логистике, часть заказов задержана. Краткосрочно это давит на издержки.", s),
            ("operations", _) => ($"{name}: операционное обновление",
                $"{name} опубликовала плановое операционное обновление без существенных сюрпризов.", "neutral"),

            ("product", "positive") => ($"{name} запускает новый продукт",
                $"{name} вывела на рынок новый продукт и ждёт роста спроса. Окупаемость запуска оценят по динамике продаж.", s),
            ("product", "negative") => ($"{name} отзывает партию продукции",
                $"{name} отзывает партию продукции из-за брака. Возможны дополнительные издержки и просадка спроса.", s),
            _ => ($"{name} обновила линейку",
                $"{name} обновила продуктовую линейку в рамках обычного цикла.", "neutral"),
        };
    }

    private static readonly (string, string, string)[] MacroTemplates =
    {
        ("ЦБ Алории снизил ключевую ставку",
            "Регулятор снизил ключевую ставку на фоне замедления инфляции. Влияние на секторы разное: одни выигрывают от дешёвых денег, другим это меняет немногое.", "positive"),
        ("Инфляция в Алории ускорилась",
            "Свежие данные показали ускорение инфляции выше прогноза. Это повышает шанс ужесточения политики и переоценку риска.", "negative"),
        ("ЦБ Алории сохранил ключевую ставку",
            "Регулятор оставил ключевую ставку без изменений. Рынок ждёт сигналов о дальнейшей траектории.", "neutral"),
        ("Деловая активность замедляется",
            "Индекс деловой активности снизился второй период подряд. Циклические секторы реагируют сильнее защитных.", "negative"),
        ("Потребительский спрос восстанавливается",
            "Данные указывают на оживление потребительского спроса. Выигрыш по секторам неравномерный.", "positive"),
    };

    private static (string, string, string) PickMacro(Random rnd) =>
        MacroTemplates[rnd.Next(MacroTemplates.Length)];
}
