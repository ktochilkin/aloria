import 'package:aloria/core/push/push_categories.dart';
import 'package:aloria/core/push/push_controller.dart';
import 'package:aloria/core/storage/storage.dart';
import 'package:aloria/core/storage/storage_factory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Маска включённых категорий пушей (см. [PushCategory]).
///
/// Пока хранилище грузится, отдаём дефолт контракта — чтобы тумблерам
/// не приходилось обрабатывать loading-state.
final pushPrefsProvider =
    StateNotifierProvider<PushPrefsController, int>((ref) {
  final storageAsync = ref.watch(storageProvider);
  return storageAsync.maybeWhen(
    data: (storage) => PushPrefsController(ref, storage),
    orElse: () => PushPrefsController.uninitialized(ref),
  );
});

/// Настройки категорий пушей: локальная копия маски (мгновенный UI)
/// + best-effort синк на бэк через [PushController.syncCategories].
class PushPrefsController extends StateNotifier<int> {
  PushPrefsController(this._ref, Storage storage)
      : _storage = storage,
        super(PushCategory.defaultMask) {
    _bootstrap();
  }

  /// Заглушка на время инициализации хранилища. [toggle] становится no-op
  /// по записи, но состояние всё равно обновится после пересоздания провайдера.
  PushPrefsController.uninitialized(this._ref)
      : _storage = null,
        super(PushCategory.defaultMask);

  final Ref _ref;
  final Storage? _storage;

  Future<void> _bootstrap() async {
    final raw = await _storage?.read(PushCategory.storageKey);
    final mask = int.tryParse(raw ?? '');
    if (mask != null && mounted) state = mask;
  }

  /// Включена ли категория сейчас.
  bool isEnabled(PushCategory category) => category.enabledIn(state);

  /// Переключает категорию: мгновенно локально, затем синк маски на бэк.
  /// Ошибки сети не всплывают — маска уедет при следующей регистрации токена.
  Future<void> toggle(PushCategory category, bool enabled) async {
    final next = enabled ? (state | category.flag) : (state & ~category.flag);
    if (next == state) return;
    state = next;
    await _storage?.write(PushCategory.storageKey, '$next');
    await _ref.read(pushControllerProvider).syncCategories(next);
  }
}
