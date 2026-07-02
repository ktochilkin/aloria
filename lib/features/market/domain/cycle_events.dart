import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/macro_state.dart';
import 'package:flutter/material.dart';

/// Событие календаря цикла.
class CycleEvent {
  CycleEvent({required this.day, required this.type, required this.title});

  final int day;
  final String type;
  final String title;
}

/// Цвет и иконка по типу события (масштабируется под облигации/деривативы).
({Color color, IconData icon}) cycleEventTypeMeta(String type) => switch (type) {
  'Отчётность' => (color: AppColors.primary, icon: Icons.assessment_rounded),
  'Дивиденды' => (color: AppColors.success, icon: Icons.payments_rounded),
  'Купон' => (color: AppColors.secondary, icon: Icons.receipt_long_rounded),
  'Ставка' => (color: AppColors.warning, icon: Icons.account_balance_rounded),
  'Погашение' => (color: AppColors.error, icon: Icons.event_available_rounded),
  _ => (color: AppColors.primary, icon: Icons.bolt_rounded),
};

/// Прототипный мок событий цикла из тестовой вселенной + текущего дня.
/// Позже заменит настоящее расписание от ИИ-режиссёра.
List<CycleEvent> buildMockCycleEvents(
  MacroState macro,
  List<MarketSecurity> securities,
) {
  final syms = securities.map((s) => s.symbol).toList();
  if (syms.isEmpty) return const [];
  String sym(int i) => syms[i % syms.length];
  final len = macro.cycleLength <= 0 ? 10 : macro.cycleLength;
  int d(int add) => ((macro.cycleDay + add - 1) % len) + 1;

  return [
    CycleEvent(day: d(1), type: 'Отчётность', title: 'Отчёт ${sym(0)}'),
    CycleEvent(day: d(1), type: 'Дивиденды', title: 'Отсечка ${sym(1)}'),
    CycleEvent(day: d(2), type: 'Купон', title: 'Купон ${sym(2)}'),
    CycleEvent(day: d(2), type: 'Отчётность', title: 'Отчёт ${sym(4)}'),
    CycleEvent(day: d(3), type: 'Ставка', title: 'Решение «ЦБ»'),
    CycleEvent(day: d(3), type: 'Дивиденды', title: 'Отсечка ${sym(5)}'),
    CycleEvent(day: d(4), type: 'Отчётность', title: 'Отчёт ${sym(3)}'),
    CycleEvent(day: d(5), type: 'Погашение', title: 'Погашение ${sym(6)}'),
    CycleEvent(day: d(6), type: 'Купон', title: 'Купон ${sym(7)}'),
    CycleEvent(day: d(7), type: 'Экспирация', title: 'Экспирация ${sym(8)}'),
  ]..sort((a, b) => a.day.compareTo(b.day));
}

/// Ближайшие события начиная с текущего дня (вперёд по циклу).
List<CycleEvent> upcomingCycleEvents(
  MacroState macro,
  List<MarketSecurity> securities, {
  int limit = 4,
}) {
  final len = macro.cycleLength <= 0 ? 10 : macro.cycleLength;
  final today = macro.cycleDay;
  int dist(int day) => (day - today + len) % len;
  final all = buildMockCycleEvents(macro, securities)
    ..sort((a, b) => dist(a.day).compareTo(dist(b.day)));
  return all.take(limit).toList();
}
