import 'dart:math' as math;

import 'package:aloria/features/market/domain/macro_state.dart';
import 'package:aloria/features/market/domain/portfolio_summary.dart';

/// Обесценивание денег с момента старта ученика в мире Алории.
///
/// Ключевая идея: обесцениваются ДЕНЬГИ, а не портфель. Активы — реальные,
/// их цены сами живут в мире; поэтому показываем рост цен, потерю
/// покупательной способности свободных денег и номинальную vs реальную
/// доходность портфеля.
class PurchasingPowerInfo {
  const PurchasingPowerInfo({
    required this.cyclesSinceStart,
    required this.priceGrowthPct,
    required this.cashLossPct,
    required this.freeCash,
    required this.freeCashThen,
    required this.nominalReturnPct,
    required this.realReturnPct,
  });

  /// Сколько циклов («лет» Алории) прошло со старта ученика.
  final int cyclesSinceStart;

  /// Накопленный рост цен с момента старта, % (уровень цен − 1).
  final double priceGrowthPct;

  /// Сколько покупательной способности потеряли свободные деньги, %.
  final double cashLossPct;

  /// Свободные деньги сейчас (покупательная способность портфеля).
  final double freeCash;

  /// Сколько «тогдашних» денег эквивалентны сегодняшним свободным.
  final double freeCashThen;

  /// Номинальная доходность портфеля со старта, %.
  final double nominalReturnPct;

  /// Реальная доходность (номинальная с поправкой на рост цен), %.
  final double realReturnPct;
}

/// Прототипный расчёт на мок-данных: старт ученика считаем 3 цикла назад,
/// рост цен выводим из текущего темпа инфляции (1 цикл = «год»), номинальную
/// доходность демонстрируем фиксированной. Позже все три числа заменит бэк:
/// уровень цен от режиссёра + зафиксированный уровень на момент первого входа.
PurchasingPowerInfo buildMockPurchasingPower(
  MacroState macro,
  PortfolioSummary? summary,
) {
  const cycles = 3;
  final annualInflation = macro.inflation <= 0 ? 4.0 : macro.inflation;
  final priceLevel = math.pow(1 + annualInflation / 100, cycles).toDouble();
  final priceGrowthPct = (priceLevel - 1) * 100;
  final cashLossPct = (1 - 1 / priceLevel) * 100;

  // Демонстрационная номинальная доходность: чуть меньше роста цен, чтобы
  // был виден смысл реальной доходности (может быть и отрицательной).
  final nominalReturnPct = priceGrowthPct * 0.7;
  final realReturnPct = ((1 + nominalReturnPct / 100) / priceLevel - 1) * 100;

  final freeCash = summary?.buyingPower ?? 0;

  return PurchasingPowerInfo(
    cyclesSinceStart: cycles,
    priceGrowthPct: priceGrowthPct,
    cashLossPct: cashLossPct,
    freeCash: freeCash,
    freeCashThen: freeCash / priceLevel,
    nominalReturnPct: nominalReturnPct,
    realReturnPct: realReturnPct,
  );
}

/// Форматирует процент со знаком: «+8,4%» / «−4,2%».
String signedPct(double v) =>
    '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(1)}%';
