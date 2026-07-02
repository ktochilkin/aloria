using Aloria.Director.Core.Engine;
using Aloria.Director.Core.Model;

namespace Aloria.Director.Core.News;

/// <summary>
/// Шаблонный нарратор — офлайн-fallback: мир никогда не останавливается из-за
/// недоступности LLM. Тексты нейтрально-реалистичные, без обещаний доходности.
/// </summary>
public sealed class TemplateNarrator : INarrator
{
    private readonly Rng _rng;

    public TemplateNarrator(Rng rng) => _rng = rng;

    public Task<NewsStory> NarrateAsync(NewsDraft draft, CancellationToken ct = default)
        => Task.FromResult(Narrate(draft));

    public NewsStory Narrate(NewsDraft draft)
    {
        var spec = draft.Spec;
        var symbol = spec.Symbol
                     ?? (spec.CandidateSymbols.Count > 0 ? _rng.Pick(spec.CandidateSymbols) : null);
        var issuer = symbol is not null ? Universe.Issuers.FirstOrDefault(i => i.Symbol == symbol) : null;
        var bond = symbol is not null && issuer is null
            ? Universe.Bonds.FirstOrDefault(b => b.Symbol == symbol)
            : null;
        var name = issuer?.Name ?? bond?.Name ?? symbol ?? "рынок";
        var sentiment = spec.Sign > 0 ? Sentiment.Positive
            : spec.Sign < 0 ? Sentiment.Negative : Sentiment.Neutral;

        var (headline, body) = Compose(spec, name, draft.World);
        return new NewsStory
        {
            Headline = headline,
            Body = body,
            Sentiment = spec.Type is EventType.Coupon or EventType.DividendPayout ? Sentiment.Neutral : sentiment,
            ChosenSymbol = symbol,
        };
    }

    private (string, string) Compose(EventSpec spec, string name, WorldSnapshot w)
    {
        var strong = spec.Severity > 0.6;
        return spec.Type switch
        {
            EventType.Earnings when spec.SurpriseZ is { } z => z switch
            {
                > 0.7 => ($"{name}: отчёт лучше ожиданий",
                    $"{name} отчиталась о прибыли {Fmt(spec.Actual)} на акцию против ожидавшихся {Fmt(spec.Expected)}. Часть роста может быть уже заложена в цену — реакцию покажет стакан."),
                < -0.7 => ($"{name}: отчёт хуже ожиданий",
                    $"Прибыль {name} составила {Fmt(spec.Actual)} на акцию при консенсусе {Fmt(spec.Expected)}. Инвесторы пересматривают ожидания по будущим периодам."),
                _ => ($"{name} отчиталась в рамках ожиданий",
                    $"Результат {Fmt(spec.Actual)} на акцию почти совпал с консенсусом {Fmt(spec.Expected)}. Сильной реакции обычно не бывает, когда сюрприза нет."),
            },
            EventType.ExpectationNote => ($"Аналитики: чего ждать от {name}",
                $"Консенсус перед событием: {Fmt(spec.Expected)}. Помни: рынок реагирует не на сам результат, а на отклонение от ожиданий."),
            EventType.DividendDecision when spec.Sign >= 0 => ($"{name} рекомендовала дивиденды",
                $"Совет директоров {name} рекомендовал выплату {Fmt(spec.Actual)} на акцию. Отсечка — завтра, выплата — через день."),
            EventType.DividendDecision => ($"{name} урезает дивиденды",
                $"{name} сокращает выплату до {Fmt(spec.Actual)} на акцию ради устойчивости баланса. Для дивидендных инвесторов это неприятный сигнал."),
            EventType.DividendCutoff => ($"Отсечка по дивидендам {name}",
                $"Сегодня закрывается реестр под дивиденды {name}. Обрати внимание: после отсечки цена обычно опускается примерно на размер выплаты."),
            EventType.DividendPayout => ($"{name} выплатила дивиденды",
                $"Дивиденды {name} поступили акционерам. Это регулярная часть дохода долгосрочного портфеля."),
            EventType.Coupon => ($"Купон по облигации {name}",
                $"По выпуску {name} выплачен очередной купон. Стабильные купоны — то, за что облигации ценят консервативные инвесторы."),
            EventType.Maturity => ($"Погашение облигации {name}",
                $"Выпуск {name} погашен по номиналу. Держатели получили номинал и последний купон."),
            EventType.Default => ($"{name}: пропущен купон",
                $"{name} не исполнила обязательство по купону. Цена выпуска обвалилась к уровню ожидаемого возмещения, рейтинг — в дефолтную категорию. Это тот самый кредитный риск."),
            EventType.RateDecision when spec.Actual is { } d => d switch
            {
                > 0 => ("ЦБ Алории повысил ставку",
                    $"Регулятор поднял ключевую ставку на {d:0.##} п.п. до {w.KeyRate:0.##}%. Ожидания были {FmtDelta(spec.Expected)} — {SurpriseNote(spec)}"),
                < 0 => ("ЦБ Алории снизил ставку",
                    $"Регулятор снизил ключевую ставку на {Math.Abs(d):0.##} п.п. до {w.KeyRate:0.##}%. Ожидания были {FmtDelta(spec.Expected)} — {SurpriseNote(spec)}"),
                _ => ("ЦБ Алории сохранил ставку",
                    $"Ставка осталась {w.KeyRate:0.##}%. Ожидания были {FmtDelta(spec.Expected)} — {SurpriseNote(spec)}"),
            },
            EventType.MacroShock when spec.Sign < 0 => (strong
                    ? "Экономику Алории лихорадит" : "Макростатистика разочаровала",
                strong
                    ? "Выход слабых данных широким фронтом ударил по рынку: деловая активность падает, аппетит к риску снижается. Защитные секторы держатся лучше циклических."
                    : "Свежая статистика вышла слабее прогнозов. Реакция по секторам неравномерная — циклические чувствительнее защитных."),
            EventType.MacroShock => (strong ? "Экономика Алории ускоряется" : "Макроданные приятно удивили",
                "Статистика вышла лучше ожиданий: спрос восстанавливается, деловая активность растёт. Выигрыш по секторам неравномерный."),
            EventType.SectorShock when spec.Sign < 0 => ($"Сектор «{SectorTitle(spec)}» под давлением",
                "Отраслевые условия ухудшились: издержки растут, спрос слабеет. Компании сектора реагируют по-разному — смотри на долговую нагрузку."),
            EventType.SectorShock => ($"Сектор «{SectorTitle(spec)}» на подъёме",
                "Отраслевая конъюнктура улучшилась. Лидеры сектора получают преимущество, но часть роста рынок мог заложить заранее."),
            EventType.ProductNews when spec.Sign >= 0 => ($"{name} запускает новинку",
                $"{name} представила новый продукт и рассчитывает на рост спроса. Окупаемость запуска оценят по следующему отчёту."),
            EventType.ProductNews => ($"{name} отзывает продукт",
                $"{name} отзывает партию продукции — это дополнительные издержки и удар по репутации в моменте."),
            EventType.OperationsShock when spec.Sign >= 0 => ($"{name} расширяет операции",
                $"{name} сообщила об операционных улучшениях. Эффект на маржу будет виден в отчётности."),
            EventType.OperationsShock => ($"Сбой в работе {name}",
                $"{name} столкнулась с операционным сбоем. Краткосрочно это давит на издержки и расписание поставок."),
            _ => ($"Новости {name}", "Событие экономического мира Алории."),
        };
    }

    private static string SectorTitle(EventSpec spec) =>
        Universe.Sectors.FirstOrDefault(s => s.Slug == spec.SectorSlug)?.Title ?? "рынок";

    private static string Fmt(double? v) => v is { } x ? x.ToString("0.##") : "—";

    private static string FmtDelta(double? v) => v switch
    {
        null => "—",
        0 => "без изменений",
        > 0 => $"+{v:0.##} п.п.",
        _ => $"{v:0.##} п.п.",
    };

    private static string SurpriseNote(EventSpec spec) =>
        Math.Abs((spec.Actual ?? 0) - (spec.Expected ?? 0)) < 0.01
            ? "рынок это уже учитывал."
            : "решение стало сюрпризом, реакция может быть резкой.";
}
