import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Запись прогресса по одному уроку.
class LessonProgressEntry {
  const LessonProgressEntry({
    required this.lessonId,
    required this.read,
    this.lastViewedAt,
    this.lastQuizScore,
    this.lastQuizTotal,
  });

  /// Идентификатор в формате `"<sectionId>/<lessonId>"`.
  final String lessonId;
  final bool read;
  final DateTime? lastViewedAt;
  final int? lastQuizScore;
  final int? lastQuizTotal;

  bool get hasQuizResult => lastQuizScore != null && lastQuizTotal != null;

  bool get quizPassed =>
      hasQuizResult && lastQuizScore == lastQuizTotal && lastQuizTotal! > 0;

  LessonProgressEntry copyWith({
    bool? read,
    DateTime? lastViewedAt,
    int? lastQuizScore,
    int? lastQuizTotal,
  }) {
    return LessonProgressEntry(
      lessonId: lessonId,
      read: read ?? this.read,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      lastQuizScore: lastQuizScore ?? this.lastQuizScore,
      lastQuizTotal: lastQuizTotal ?? this.lastQuizTotal,
    );
  }

  Map<String, dynamic> toJson() => {
    'read': read,
    if (lastViewedAt != null)
      'lastViewedAt': lastViewedAt!.toIso8601String(),
    if (lastQuizScore != null) 'lastQuizScore': lastQuizScore,
    if (lastQuizTotal != null) 'lastQuizTotal': lastQuizTotal,
  };

  factory LessonProgressEntry.fromJson(String lessonId, Map<String, dynamic> j) {
    final ts = j['lastViewedAt'] as String?;
    return LessonProgressEntry(
      lessonId: lessonId,
      read: j['read'] as bool? ?? false,
      lastViewedAt: ts != null ? DateTime.tryParse(ts) : null,
      lastQuizScore: (j['lastQuizScore'] as num?)?.toInt(),
      lastQuizTotal: (j['lastQuizTotal'] as num?)?.toInt(),
    );
  }
}

/// Локальное хранилище прогресса обучения.
///
/// Не хранит ничего чувствительного — обычные SharedPreferences.
/// Ключ-композит формируется как `"<sectionId>/<lessonId>"`,
/// чтобы исключить коллизии между разделами.
class LearningProgressRepository {
  LearningProgressRepository(this._prefs);

  static const String _storageKey = 'aloria.learning.progress.v1';
  static const String _lastVisitedKey = 'aloria.learning.lastVisited.v1';

  final SharedPreferences _prefs;

  static String compositeId(String sectionId, String lessonId) =>
      '$sectionId/$lessonId';

  /// Читает все записи прогресса.
  Map<String, LessonProgressEntry> loadAll() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const {};
      final result = <String, LessonProgressEntry>{};
      decoded.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          result[key] = LessonProgressEntry.fromJson(key, value);
        }
      });
      return result;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _saveAll(Map<String, LessonProgressEntry> entries) async {
    final encoded = entries.map((k, v) => MapEntry(k, v.toJson()));
    await _prefs.setString(_storageKey, jsonEncode(encoded));
  }

  /// Помечает урок как просмотренный (прочитанный).
  Future<Map<String, LessonProgressEntry>> markRead(
    String sectionId,
    String lessonId,
  ) async {
    final all = Map<String, LessonProgressEntry>.from(loadAll());
    final id = compositeId(sectionId, lessonId);
    final current = all[id];
    all[id] = (current ??
            LessonProgressEntry(lessonId: id, read: false))
        .copyWith(read: true, lastViewedAt: DateTime.now());
    await _saveAll(all);
    await _saveLastVisited(sectionId, lessonId);
    return all;
  }

  /// Применяет серверный снимок прогресса: для каждого урока выставляет
  /// локальный флаг `read` ровно как на сервере. Используется при заходе
  /// на «Обучение» — сервер становится источником истины, локальный кэш
  /// перетягивается под него (включая снятие флага, если на сервере
  /// прохождение было удалено, например через админ-сброс).
  ///
  /// Записи `lastQuizScore` / `lastViewedAt` не трогаются — это локальная
  /// телеметрия.
  Future<Map<String, LessonProgressEntry>> applyServerSnapshot(
    Iterable<
            ({String sectionId, String lessonId, bool serverCompleted})>
        snapshot,
  ) async {
    final all = Map<String, LessonProgressEntry>.from(loadAll());
    var changed = false;
    for (final s in snapshot) {
      final id = compositeId(s.sectionId, s.lessonId);
      final current = all[id];
      final isRead = current?.read ?? false;
      if (s.serverCompleted == isRead) continue;
      all[id] = (current ?? LessonProgressEntry(lessonId: id, read: false))
          .copyWith(read: s.serverCompleted);
      changed = true;
    }
    if (changed) await _saveAll(all);
    return all;
  }

  /// Сохраняет результат теста урока. Не меняет флаг `read`.
  Future<Map<String, LessonProgressEntry>> saveQuizResult(
    String sectionId,
    String lessonId, {
    required int score,
    required int total,
  }) async {
    final all = Map<String, LessonProgressEntry>.from(loadAll());
    final id = compositeId(sectionId, lessonId);
    final current = all[id] ?? LessonProgressEntry(lessonId: id, read: true);
    all[id] = current.copyWith(
      read: true,
      lastViewedAt: DateTime.now(),
      lastQuizScore: score,
      lastQuizTotal: total,
    );
    await _saveAll(all);
    await _saveLastVisited(sectionId, lessonId);
    return all;
  }

  /// Сохраняет ссылку на последний открытый урок для карточки «Продолжить».
  Future<void> _saveLastVisited(String sectionId, String lessonId) async {
    await _prefs.setString(
      _lastVisitedKey,
      jsonEncode({'sectionId': sectionId, 'lessonId': lessonId}),
    );
  }

  /// Идентификаторы последнего открытого урока.
  ({String sectionId, String lessonId})? lastVisited() {
    final raw = _prefs.getString(_lastVisitedKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final s = decoded['sectionId'] as String?;
      final l = decoded['lessonId'] as String?;
      if (s == null || l == null) return null;
      return (sectionId: s, lessonId: l);
    } catch (_) {
      return null;
    }
  }

  /// Полный сброс прогресса.
  Future<void> reset() async {
    await _prefs.remove(_storageKey);
    await _prefs.remove(_lastVisitedKey);
  }
}
