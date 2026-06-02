namespace Aloria.Api.Domain;

/// <summary>Уровень владения концепцией ученика — монотонно растёт.</summary>
public enum ConceptMasteryLevel
{
    None = 0,
    Familiar = 1,      // встретил концепцию (Introduce-урок)
    Understands = 2,   // углублённо разобрал (Deepen-урок) или сдал квиз
    Applied = 3,       // применил на практике через PracticeRequirement
}

/// <summary>
/// Уровень владения концепцией у конкретного пользователя. Не понижается.
/// Источники подъёма хранятся в SourcesJson для аудита и UI «откуда я знаю».
/// </summary>
public class UserConceptMastery
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid ConceptId { get; set; }

    public ConceptMasteryLevel Level { get; set; }

    /// JSON-массив записей: [{"at":"…","from":"lesson","ref":"<lessonId>","role":"introduce","raised":"familiar"}]
    public string SourcesJson { get; set; } = "[]";

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
