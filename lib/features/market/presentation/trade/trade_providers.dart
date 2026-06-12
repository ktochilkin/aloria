import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Вкладка блока «Пульс рынка» на торговом экране.
enum FeedTab { news, tape, orderBook }

/// Выбранная вкладка «Пульса рынка» по символу — переживает уход со страницы.
final feedTabProvider = StateProvider.family<FeedTab, String>((ref, symbol) {
  // Сохраняем состояние вкладки, чтобы не сбрасывалось
  ref.keepAlive();
  return FeedTab.news;
});

/// Позиция прокрутки торговой страницы по символу — восстанавливается
/// при возврате на инструмент.
final scrollPositionProvider = StateProvider.family<double, String>(
  (ref, symbol) => 0.0,
);
