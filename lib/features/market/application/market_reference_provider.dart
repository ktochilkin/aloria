import 'dart:async';

import 'package:aloria/core/logging/logger.dart';
import 'package:aloria/features/market/data/market_reference_repository.dart';
import 'package:aloria/features/market/domain/reference_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Справочник мира Алории с бэка aloria-api.
///
/// Каталог живой: режиссёр пере-пушит его целиком, например при смене
/// руководителя компании, поэтому провайдер сам перезапрашивается раз в
/// 5 минут (по образцу market_news_provider). Если запрос упал или бэк отдал
/// пустой каталог, возвращается статический фолбэк: вкладка «Компании»
/// работает всегда.
const _autoRefresh = Duration(minutes: 5);

final marketReferenceProvider = FutureProvider<ReferenceCatalog>((ref) async {
  final timer = Timer(_autoRefresh, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final repo = ref.watch(marketReferenceRepositoryProvider);
  try {
    final catalog = await repo.fetchReference();
    if (catalog.isEmpty) {
      appLogger.i('reference: каталог с бэка пуст, статический фолбэк');
      return const ReferenceCatalog.fallback();
    }
    return catalog;
  } catch (e) {
    appLogger.w('reference: бэк недоступен, статический фолбэк ($e)');
    return const ReferenceCatalog.fallback();
  }
});
