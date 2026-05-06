import 'package:flutter/material.dart';

/// Хранится в SharedPreferences, читается на старте приложения.
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.localeTag,
    required this.learningMode,
  });

  /// Тема UI: system / light / dark.
  final ThemeMode themeMode;

  /// Тег локали. `null` = «как в системе». Иначе — `'ru'` / `'en'`.
  final String? localeTag;

  /// Включён ли «режим обучения интерфейсу» — подсветки и подсказки.
  final bool learningMode;

  /// Дефолтные значения при первом запуске.
  static const AppSettings defaults = AppSettings(
    themeMode: ThemeMode.system,
    localeTag: null,
    learningMode: false,
  );

  AppSettings copyWith({
    ThemeMode? themeMode,
    Object? localeTag = _sentinel,
    bool? learningMode,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      localeTag: identical(localeTag, _sentinel)
          ? this.localeTag
          : localeTag as String?,
      learningMode: learningMode ?? this.learningMode,
    );
  }

  Map<String, Object?> toJson() => {
        'themeMode': themeMode.name,
        'localeTag': localeTag,
        'learningMode': learningMode,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final theme = (json['themeMode'] as String?) ?? 'system';
    final mode = ThemeMode.values.firstWhere(
      (m) => m.name == theme,
      orElse: () => ThemeMode.system,
    );
    return AppSettings(
      themeMode: mode,
      localeTag: json['localeTag'] as String?,
      learningMode: (json['learningMode'] as bool?) ?? false,
    );
  }

  Locale? toLocale() {
    final tag = localeTag;
    if (tag == null || tag.isEmpty) return null;
    return Locale(tag);
  }
}

const _sentinel = Object();
