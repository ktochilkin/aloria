import 'dart:convert';

import 'package:aloria/features/settings/domain/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сериализация настроек в SharedPreferences.
///
/// Формат — единый JSON под ключом [_key]. Так миграции при добавлении
/// новых полей сводятся к мерджу со значениями по умолчанию.
class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _key = 'app_settings_v1';

  final SharedPreferences _prefs;

  /// Загружает текущие настройки. Если в хранилище ничего нет — пишет
  /// дефолты (первичная инициализация) и возвращает их же.
  Future<AppSettings> loadOrInit() async {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      await save(AppSettings.defaults);
      return AppSettings.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        // Мерджим с дефолтами на случай, если кто-то добавил поле.
        final merged = <String, Object?>{
          ...AppSettings.defaults.toJson(),
          ...decoded,
        };
        return AppSettings.fromJson(merged);
      }
    } catch (_) {
      // Битый JSON — сбрасываем в дефолты.
    }
    await save(AppSettings.defaults);
    return AppSettings.defaults;
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  Future<void> clear() => _prefs.remove(_key);
}
