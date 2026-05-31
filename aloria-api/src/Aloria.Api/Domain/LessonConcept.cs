namespace Aloria.Api.Domain;

/// <summary>Роль урока по отношению к концепции в спиральном курсе.</summary>
public enum ConceptRole
{
    /// Концепция впервые вводится в курсе этим уроком.
    Introduce = 1,

    /// Концепция возвращается с большей глубиной (следующая итерация спирали).
    Deepen = 2,

    /// Концепция применяется на практике в задаче этого урока.
    Apply = 3,
}

/// <summary>
/// Связь N:M между уроком и концепцией с ролью. Один урок может одновременно
/// вводить одну концепцию, углублять вторую и применять третью.
/// Составной ключ: (LessonId, ConceptId, Role).
/// </summary>
public class LessonConcept
{
    public Guid LessonId { get; set; }
    public Lesson? Lesson { get; set; }

    public Guid ConceptId { get; set; }
    public Concept? Concept { get; set; }

    public ConceptRole Role { get; set; }

    /// Глубина возврата: 1 — введение, 2 — углубление, 3 — синтез/применение.
    /// Помогает UI подсветить уровень в карточке концепции.
    public int Depth { get; set; } = 1;
}
