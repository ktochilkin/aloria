import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/learn/data/learning_content_cache.dart';
import 'package:aloria/features/learn/data/learning_progress_repository.dart';
import 'package:aloria/features/learn/domain/learning_content_service.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Контент.
// ---------------------------------------------------------------------------

/// portfolioId, под которым обращаемся к aloria-api.
/// Когда появится полноценная авторизация — берём из auth-контроллера.
final aloriaPortfolioIdProvider =
    Provider<String>((_) => TradeOrder.defaultPortfolio);

/// Сервис учебного контента, ходящий в aloria-api.
final learningContentServiceProvider = Provider<LearningContentService>(
  (ref) => LearningContentService(ref.watch(learningApiClientProvider)),
);

/// Список разделов с уроками.
///
/// Network-first: грузим с бэка и сохраняем в локальный кэш; если сеть/бэк
/// недоступны — отдаём последний сохранённый кэш. Переиспользуется всеми
/// экранами обучения.
final learningSectionsProvider = FutureProvider<List<LearningSection>>(
  (ref) async {
    final service = ref.watch(learningContentServiceProvider);
    final portfolioId = ref.watch(aloriaPortfolioIdProvider);

    // Кэш — best-effort: если SharedPreferences ещё не готов, работаем как раньше.
    LearningContentCache? cache;
    try {
      cache = LearningContentCache(
        await ref.watch(_sharedPreferencesProvider.future),
      );
    } catch (_) {
      cache = null;
    }

    try {
      // Всегда пробуем свежий контент.
      final sections = await service.loadSections(portfolioId: portfolioId);
      await cache?.save(sections);
      return sections;
    } catch (e) {
      // Сеть/бэк недоступны — отдаём последний кэш, если он есть.
      final cached = cache?.load();
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow; // ни сети, ни кэша — UI покажет ошибку.
    }
  },
);

final learningIntroProvider = FutureProvider<String>((ref) {
  final service = ref.watch(learningContentServiceProvider);
  return service.loadIntro();
});

// ---------------------------------------------------------------------------
// Прогресс.
// ---------------------------------------------------------------------------

/// SharedPreferences для прогресса. Создаётся один раз при первом обращении.
final _sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (_) => SharedPreferences.getInstance(),
);

/// Репозиторий прогресса обучения.
final learningProgressRepositoryProvider =
    FutureProvider<LearningProgressRepository>((ref) async {
  final prefs = await ref.watch(_sharedPreferencesProvider.future);
  return LearningProgressRepository(prefs);
});

/// Снимок текущего состояния прогресса по урокам.
class LearningProgressState {
  const LearningProgressState({
    this.entries = const {},
    this.lastVisited,
  });

  /// Ключ — composite "sectionId/lessonId".
  final Map<String, LessonProgressEntry> entries;
  final ({String sectionId, String lessonId})? lastVisited;

  bool isLessonRead(String sectionId, String lessonId) {
    final key = LearningProgressRepository.compositeId(sectionId, lessonId);
    return entries[key]?.read ?? false;
  }

  LessonProgressEntry? entryFor(String sectionId, String lessonId) {
    final key = LearningProgressRepository.compositeId(sectionId, lessonId);
    return entries[key];
  }

  /// Сколько уроков из раздела помечены прочитанными.
  int readCountInSection(LearningSection section) {
    var count = 0;
    for (final lesson in section.lessons) {
      if (isLessonRead(section.id, lesson.id)) count++;
    }
    return count;
  }
}

class LearningProgressNotifier extends StateNotifier<LearningProgressState> {
  /// Основной конструктор: создаёт состояние из репозитория.
  LearningProgressNotifier(LearningProgressRepository repository)
      : _repository = repository,
        super(LearningProgressState(
          entries: repository.loadAll(),
          lastVisited: repository.lastVisited(),
        ));

  /// Заглушка на время инициализации SharedPreferences.
  /// Все мутирующие методы становятся no-op до момента появления репозитория.
  LearningProgressNotifier.uninitialized()
      : _repository = null,
        super(const LearningProgressState());

  final LearningProgressRepository? _repository;

  Future<void> markRead(String sectionId, String lessonId) async {
    final repo = _repository;
    if (repo == null) return;
    final updated = await repo.markRead(sectionId, lessonId);
    state = LearningProgressState(
      entries: updated,
      lastVisited: (sectionId: sectionId, lessonId: lessonId),
    );
  }

  /// Применяет серверный снимок: локальные `read` приводятся к серверному
  /// состоянию. Если серверный сброс удалил completion, локальный флаг тоже
  /// снимается. Не трогает `lastVisited` и историю тестов.
  Future<void> applyServerSnapshot(
    Iterable<({String sectionId, String lessonId, bool serverCompleted})>
        snapshot,
  ) async {
    final repo = _repository;
    if (repo == null) return;
    final updated = await repo.applyServerSnapshot(snapshot);
    state = LearningProgressState(
      entries: updated,
      lastVisited: state.lastVisited,
    );
  }

  Future<void> saveQuizResult({
    required String sectionId,
    required String lessonId,
    required int score,
    required int total,
  }) async {
    final repo = _repository;
    if (repo == null) return;
    final updated = await repo.saveQuizResult(
      sectionId,
      lessonId,
      score: score,
      total: total,
    );
    state = LearningProgressState(
      entries: updated,
      lastVisited: (sectionId: sectionId, lessonId: lessonId),
    );
  }

  Future<void> reset() async {
    await _repository?.reset();
    state = const LearningProgressState();
  }
}

/// Состояние прогресса. Пока репозиторий грузится — отдаёт пустое состояние,
/// чтобы UI не приходилось ловить отдельный loading на каждом экране.
final learningProgressProvider =
    StateNotifierProvider<LearningProgressNotifier, LearningProgressState>(
  (ref) {
    final repoAsync = ref.watch(learningProgressRepositoryProvider);
    return repoAsync.maybeWhen(
      data: LearningProgressNotifier.new,
      orElse: () => LearningProgressNotifier.uninitialized(),
    );
  },
);

/// Синхронизация прогресса с aloria-api: сервер — источник истины.
///
/// При готовности разделов и репозитория применяет снимок: для каждого
/// урока приводит локальный `read` к серверному `isCompleted`. Если урок
/// был сброшен на бэке (например, через админ-панель), локальный флаг
/// тоже снимется и UI обновится.
///
/// Локальные «оффлайн-чтения» (когда `markLessonComplete` не дошёл до
/// сервера) восстанавливаются естественно: lesson_page.dart дёргает
/// `complete` при каждом заходе на урок, бэк идемпотентен.
final learningProgressSyncProvider = Provider<void>((ref) {
  final sectionsAsync = ref.watch(learningSectionsProvider);
  final repoAsync = ref.watch(learningProgressRepositoryProvider);

  final sections = sectionsAsync.asData?.value;
  final repoReady = repoAsync.asData != null;
  if (sections == null || !repoReady) return;

  final snapshot =
      <({String sectionId, String lessonId, bool serverCompleted})>[];
  for (final s in sections) {
    for (final l in s.lessons) {
      snapshot.add((
        sectionId: s.id,
        lessonId: l.id,
        serverCompleted: l.serverCompleted,
      ));
    }
  }
  if (snapshot.isEmpty) return;

  Future.microtask(() {
    ref
        .read(learningProgressProvider.notifier)
        .applyServerSnapshot(snapshot);
  });
});

// ---------------------------------------------------------------------------
// Удобные derived-провайдеры.
// ---------------------------------------------------------------------------

/// Последний открытый урок (если он всё ещё есть в загруженном контенте).
final lastVisitedLessonProvider = Provider<({
  LearningSection section,
  Lesson lesson,
})?>((ref) {
  final sectionsAsync = ref.watch(learningSectionsProvider);
  final progress = ref.watch(learningProgressProvider);
  final last = progress.lastVisited;
  if (last == null) return null;
  return sectionsAsync.maybeWhen(
    data: (sections) => _pickPair(sections, last.sectionId, last.lessonId),
    orElse: () => null,
  );
});

/// Первый непрочитанный урок — используется как «начать обучение»,
/// когда ещё не было ни одного открытого урока.
final nextLessonHintProvider = Provider<({
  LearningSection section,
  Lesson lesson,
})?>((ref) {
  final sectionsAsync = ref.watch(learningSectionsProvider);
  final progress = ref.watch(learningProgressProvider);
  return sectionsAsync.maybeWhen(
    data: (sections) {
      for (final section in sections) {
        for (final lesson in section.lessons) {
          if (!progress.isLessonRead(section.id, lesson.id)) {
            return (section: section, lesson: lesson);
          }
        }
      }
      return null;
    },
    orElse: () => null,
  );
});

({LearningSection section, Lesson lesson})? _pickPair(
  List<LearningSection> sections,
  String sectionId,
  String lessonId,
) {
  for (final section in sections) {
    if (section.id != sectionId) continue;
    for (final lesson in section.lessons) {
      if (lesson.id == lessonId) {
        return (section: section, lesson: lesson);
      }
    }
  }
  return null;
}
