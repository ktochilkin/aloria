import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Провайдер для отслеживания текущего активного инструмента на экране торговли
/// Используется только для информационных целей, автоматическая очистка не требуется
/// так как провайдеры с keepAlive не создают утечек памяти
final activeTradeInstrumentProvider =
    StateProvider<({String symbol, String exchange})?>((_) => null);
