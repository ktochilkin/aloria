import 'package:aloria/features/settings/data/settings_repository.dart';
import 'package:aloria/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (_) => SharedPreferences.getInstance(),
);

final settingsRepositoryProvider = FutureProvider<SettingsRepository>(
  (ref) async => SettingsRepository(
    await ref.watch(_sharedPreferencesProvider.future),
  ),
);

/// Текущие настройки. До тех пор пока репозиторий грузится, отдаём дефолты —
/// чтобы UI не приходилось обрабатывать loading-state на каждом экране.
final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  final repoAsync = ref.watch(settingsRepositoryProvider);
  return repoAsync.maybeWhen(
    data: SettingsController.new,
    orElse: () => SettingsController.uninitialized(),
  );
});

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(SettingsRepository repository)
      : _repository = repository,
        super(AppSettings.defaults) {
    _bootstrap();
  }

  /// Заглушка на время инициализации. setX-методы становятся no-op.
  SettingsController.uninitialized()
      : _repository = null,
        super(AppSettings.defaults);

  final SettingsRepository? _repository;

  Future<void> _bootstrap() async {
    final repo = _repository;
    if (repo == null) return;
    state = await repo.loadOrInit();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final next = state.copyWith(themeMode: mode);
    state = next;
    await _repository?.save(next);
  }

  /// `null` = следовать системной локали.
  Future<void> setLocaleTag(String? tag) async {
    final next = state.copyWith(localeTag: tag);
    state = next;
    await _repository?.save(next);
  }

  Future<void> setLearningMode(bool enabled) async {
    final next = state.copyWith(learningMode: enabled);
    state = next;
    await _repository?.save(next);
  }
}
