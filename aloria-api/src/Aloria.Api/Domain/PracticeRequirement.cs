namespace Aloria.Api.Domain;

/// <summary>Тип требования к практике — что должен сделать ученик на симуляторе.</summary>
public enum PracticeKind
{
    /// Купить инструмент заданного класса (например, любую акцию или ОФЗ).
    OpenPosition = 1,

    /// Дождаться рыночного события на удерживаемой позиции (купон, дивиденд).
    HoldUntilEvent = 2,

    /// Выставить заявку определённого типа (например, лимитную).
    PlaceLimitOrder = 3,

    /// Отменить активную заявку.
    CancelOrder = 4,

    /// Закрыть открытую позицию.
    ClosePosition = 5,

    /// Накопить покупательную способность до заданного уровня.
    ReachBuyingPower = 6,

    /// Произвольное требование, разбирается специализированным хендлером по коду.
    Custom = 99,
}

/// <summary>
/// Требование практики, закрывающее этап спирали. Каждое требование — таргет
/// на этапе, который проверяется событиями торгового движка через
/// PracticeEventDispatcher.
/// </summary>
public class PracticeRequirement
{
    public Guid Id { get; set; }
    public Guid SectionId { get; set; }
    public Section? Section { get; set; }

    /// Стабильный код требования (например, "buy-ofz"). Уникален в пределах этапа.
    public string Code { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;

    public PracticeKind Kind { get; set; }

    /// Параметры цели в JSON, специфичны для Kind. Примеры:
    ///   OpenPosition:   {"assetClass":"bond","minQty":1,"symbolIn":[…]}
    ///   HoldUntilEvent: {"eventType":"coupon","forSymbolFromRequirement":"buy-ofz"}
    public string ParamsJson { get; set; } = "{}";

    public int Order { get; set; }

    /// Если требование опционально — этап завершается без него.
    public bool IsOptional { get; set; }

    /// Награда в виртуальных рублях покупательной способности за выполнение.
    public int RewardBuyingPower { get; set; }

    /// Концепции, поднимаемые до уровня Applied при выполнении этого требования.
    /// Хранится как JSON массив slug'ов: ["risk","liquidity"].
    public string ConceptSlugsJson { get; set; } = "[]";

    /// Архивный флаг — для мягкого удаления когда требование исчезло из
    /// practice.json, но прогресс пользователя по нему сохранять надо.
    public bool Archived { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
