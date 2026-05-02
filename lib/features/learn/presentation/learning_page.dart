/// Точка входа фичи «Обучение». Пере-экспортирует страницы из отдельных
/// файлов, чтобы существующий роутинг (lib/router.dart) продолжал работать
/// с одного импорта `learning_page.dart`.
library;

export 'learning_index_page.dart' show LearningPage;
export 'learning_section_page.dart' show LearningSectionPage;
export 'lesson_page.dart' show LessonPage;
