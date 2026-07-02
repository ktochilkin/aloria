using Aloria.Director.Core.Model;

namespace Aloria.Director.Core.News;

/// <summary>
/// Нарратор превращает спек события в историю. Реализации: LLM (OpenRouter)
/// в хосте и шаблонный fallback здесь, в ядре. Нарратор НИКОГДА не решает
/// величину движения цены — только текст и выбор жертвы из пула кандидатов.
/// </summary>
public interface INarrator
{
    Task<NewsStory> NarrateAsync(NewsDraft draft, CancellationToken ct = default);
}
