import 'dart:convert';

import 'package:aloria/features/learn/domain/learning_content_service.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Локальный кэш учебного контента (разделы + уроки) в SharedPreferences.
///
/// Стратегия загрузки — network-first с фолбэком (см. `learningSectionsProvider`):
/// при успешном ответе бэка контент сохраняется сюда; если сеть/бэк недоступны —
/// отдаётся последний сохранённый кэш. Иконка/цвет раздела не сериализуются —
/// они выводятся из slug ([LearningContentService.iconFor]/[tintFor]).
class LearningContentCache {
  LearningContentCache(this._prefs);

  static const _key = 'learning_content_cache_v1';

  /// Префикс ключей в SharedPreferences для тел уроков, кэшированных
  /// по `serverId`. Тела не лежат в основном кэше (списке этапов),
  /// потому что /stages/{slug} body не отдаёт — оно подгружается
  /// /lessons/{id} лениво и кэшируется отдельной записью.
  static const _bodyKeyPrefix = 'learning_lesson_body_v1:';

  final SharedPreferences _prefs;

  /// Сохраняет снимок контента. Best-effort: ошибки записи не пробрасываем.
  Future<void> save(List<LearningSection> sections) async {
    try {
      final data = {'sections': sections.map(_sectionToJson).toList()};
      await _prefs.setString(_key, jsonEncode(data));
    } catch (_) {
      // Кэш — вспомогательный, его сбой не должен ломать загрузку.
    }
  }

  /// Возвращает кэшированный контент или `null`, если кэша нет/он битый.
  List<LearningSection>? load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final sections = (data['sections'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_sectionFromJson)
          .toList();
      return sections.isEmpty ? null : sections;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _sectionToJson(LearningSection s) => {
        'id': s.id,
        'title': s.title,
        'subtitle': s.subtitle,
        'lessons': s.lessons.map(_lessonToJson).toList(),
      };

  LearningSection _sectionFromJson(Map<String, dynamic> j) {
    final id = j['id'] as String? ?? '';
    return LearningSection(
      id: id,
      title: j['title'] as String? ?? '',
      subtitle: j['subtitle'] as String? ?? '',
      icon: LearningContentService.iconFor(id),
      tint: LearningContentService.tintFor(id),
      lessons: (j['lessons'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_lessonFromJson)
          .toList(),
    );
  }

  Map<String, dynamic> _lessonToJson(Lesson l) => {
        'id': l.id,
        'title': l.title,
        'description': l.description,
        'academicDefinition': l.academicDefinition,
        'imageUrl': l.imageUrl,
        'body': l.body,
        'estimatedMinutes': l.estimatedMinutes,
        'serverId': l.serverId,
        'serverQuizId': l.serverQuizId,
        'serverCompleted': l.serverCompleted,
        'practiceSymbol': l.practiceSymbol,
        'practiceText': l.practiceText,
        'recallPrompt': l.recallPrompt,
        'recallAnswer': l.recallAnswer,
        'group': l.group,
      };

  Lesson _lessonFromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        academicDefinition: j['academicDefinition'] as String? ?? '',
        imageUrl: j['imageUrl'] as String? ?? '',
        body: j['body'] as String? ?? '',
        estimatedMinutes: (j['estimatedMinutes'] as num?)?.toInt(),
        serverId: j['serverId'] as String?,
        serverQuizId: j['serverQuizId'] as String?,
        serverCompleted: j['serverCompleted'] as bool? ?? false,
        practiceSymbol: j['practiceSymbol'] as String?,
        practiceText: j['practiceText'] as String?,
        recallPrompt: j['recallPrompt'] as String?,
        recallAnswer: j['recallAnswer'] as String?,
        group: j['group'] as String?,
      );

  // ---- per-lesson body cache ----

  /// Сохраняет тело урока (markdown + связанные поля) в отдельную запись
  /// SharedPreferences по `serverId`. Используется в `lesson_page.dart` —
  /// при заходе на урок сначала пытаемся достать тело из кэша, потом
  /// идём в сеть.
  Future<void> saveLessonBody(String serverId, Lesson lesson) async {
    try {
      await _prefs.setString(
        '$_bodyKeyPrefix$serverId',
        jsonEncode(_lessonToJson(lesson)),
      );
    } catch (_) {
      // best-effort
    }
  }

  Lesson? loadLessonBody(String serverId) {
    final raw = _prefs.getString('$_bodyKeyPrefix$serverId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return _lessonFromJson(j);
    } catch (_) {
      return null;
    }
  }
}
