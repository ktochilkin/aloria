import 'package:aloria/features/learn/presentation/widgets/lesson_allocation_pie.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_charts_extra.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_compound_growth.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_divgap_chart.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_foundations.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_inflation_erosion.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_leverage_seesaw.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_orderbook_2col.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_pack_bondfund.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_pack_bonds.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_pack_charts.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_pack_engine.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_pack_engine2.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_pack_games.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_pack_gauges.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_pack_new.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_pack_slidergames.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_rework.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_scam_flags.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_static_blocks.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_style_directions.dart';
import 'package:flutter/material.dart';

/// Строит интерактивный/визуальный блок урока по имени директивы.
typedef LessonBlockBuilder = Widget Function(BuildContext context, Color tint);

/// Реестр учебных блоков-директив. В теле урока строка вида `:::имя` на
/// отдельной строке заменяется на соответствующий виджет. Текст вокруг
/// директивы рендерится обычным markdown. Набор после ревью — 39 блоков
/// (см. docs/block-verdicts.md).
const Map<String, LessonBlockBuilder> lessonBlockBuilders = {
  'callout': _calloutDemo,
  'number-accent': _numberAccent,
  'compare-cards': _compareCards,
  'flow-broker': _flowBroker,
  'timeline-tplus': _timelineTplus,
  'compound-growth': _compoundGrowth,
  'divgap-chart': _divgapChart,
  'orderbook-2col': _orderbook2col,
  'leverage-seesaw': _leverageSeesaw,
  'scam-flags': _scamFlags,
  'allocation-pie': _allocationPie,
  'index-vs-fund': _indexVsFund,
  'pnl-live': _pnlLive,
  'inflation-erosion': _inflationErosion,
  'eat-the-book': _eatTheBook,
  'limit-or-wait': _limitOrWait,
  'matching-mini': _matchingMini,
  'book-vs-tape': _bookVsTape,
  'margin-call': _marginCall,
  'compound-race': _compoundRace,
  'bond-yield-flip': _bondYieldFlip,
  'coupon-cashflow': _couponCashflow,
  'nkd-sawtooth': _nkdSawtooth,
  'ytm-gauge': _ytmGauge,
  'rate-move-gauge': _rateMoveGauge,
  'real-yield': _realYield,
  'rubles-paper-flow': _rublesPaperFlow,
  'donothing-fork': _doNothingFork,
  'candle-anatomy': _candleAnatomy,
  'sort-by-risk': _sortByRisk,
  'scam-sorter': _scamSorter,
  'order-status': _orderStatus,
  'spread-roundtrip': _spreadRoundtrip,
  'bond-to-rubles': _bondToRubles,
  'rating-yield': _ratingYield,
  'tax-saldo': _taxSaldo,
  'start-early': _startEarly,
  'phone-vs-garage': _phoneVsGarage,
  'read-the-tape': _readTheTape,
  // новые
  'order-builder': _orderBuilder,
  'candle-from-trades': _candleFromTrades,
  'diversification-dice': _diversificationDice,
  'spread-gauge': _spreadGauge,
  'if-then-rule': _ifThenRule,
  // кандидаты визуального направления (витрина lab/02-style-directions)
  'style-airy': _styleAiry,
  'style-crisp': _styleCrisp,
  'style-warm': _styleWarm,
  // витрина основ дизайн-системы (lab/03-foundations)
  'kit-card': _kitCard,
  'kit-tokens': _kitTokens,
  'kit-bits': _kitBits,
};

Widget _calloutDemo(BuildContext context, Color tint) =>
    LessonCalloutDemo(tint: tint);

Widget _numberAccent(BuildContext context, Color tint) =>
    LessonNumberAccent(tint: tint);

Widget _compareCards(BuildContext context, Color tint) =>
    LessonCompareCards(tint: tint);

Widget _flowBroker(BuildContext context, Color tint) =>
    LessonFlowBroker(tint: tint);

Widget _timelineTplus(BuildContext context, Color tint) =>
    LessonTimelineTplus(tint: tint);

Widget _compoundGrowth(BuildContext context, Color tint) =>
    LessonCompoundGrowth(tint: tint);

Widget _divgapChart(BuildContext context, Color tint) =>
    LessonDivGapChart(tint: tint);

Widget _orderbook2col(BuildContext context, Color tint) =>
    LessonOrderbookTwoCol(tint: tint);

Widget _leverageSeesaw(BuildContext context, Color tint) =>
    LessonLeverageSeesaw(tint: tint);

Widget _scamFlags(BuildContext context, Color tint) =>
    LessonScamFlags(tint: tint);

Widget _allocationPie(BuildContext context, Color tint) =>
    LessonAllocationPie(tint: tint);

Widget _indexVsFund(BuildContext context, Color tint) =>
    LessonIndexVsFund(tint: tint);

Widget _pnlLive(BuildContext context, Color tint) => LessonPnlLive(tint: tint);

Widget _inflationErosion(BuildContext context, Color tint) =>
    LessonInflationErosion(tint: tint);

Widget _eatTheBook(BuildContext context, Color tint) =>
    LessonEatTheBook(tint: tint);

Widget _limitOrWait(BuildContext context, Color tint) =>
    LessonLimitOrWait(tint: tint);

Widget _matchingMini(BuildContext context, Color tint) =>
    LessonMatchBook(tint: tint);

Widget _bookVsTape(BuildContext context, Color tint) =>
    LessonBookVsTape(tint: tint);

Widget _marginCall(BuildContext context, Color tint) =>
    LessonMarginCallDial(tint: tint);

Widget _compoundRace(BuildContext context, Color tint) =>
    LessonCompoundRace(tint: tint);

Widget _bondYieldFlip(BuildContext context, Color tint) =>
    LessonBondYieldFlip(tint: tint);

Widget _couponCashflow(BuildContext context, Color tint) =>
    LessonCouponCashflow(tint: tint);

Widget _nkdSawtooth(BuildContext context, Color tint) =>
    LessonNkdSawtooth(tint: tint);

Widget _ytmGauge(BuildContext context, Color tint) =>
    LessonYtmDial(tint: tint);

Widget _rateMoveGauge(BuildContext context, Color tint) =>
    LessonRateReaction(tint: tint);

Widget _realYield(BuildContext context, Color tint) =>
    LessonRealYield(tint: tint);

Widget _rublesPaperFlow(BuildContext context, Color tint) =>
    LessonRublesPaperFlow(tint: tint);

Widget _doNothingFork(BuildContext context, Color tint) =>
    LessonDoNothingFork(tint: tint);

Widget _candleAnatomy(BuildContext context, Color tint) =>
    LessonCandleAnatomy(tint: tint);

Widget _sortByRisk(BuildContext context, Color tint) =>
    LessonSortByRisk(tint: tint);

Widget _scamSorter(BuildContext context, Color tint) =>
    LessonScamSorter(tint: tint);

Widget _orderStatus(BuildContext context, Color tint) =>
    LessonOrderStatusJourney(tint: tint);

Widget _spreadRoundtrip(BuildContext context, Color tint) =>
    LessonSpreadRoundtrip(tint: tint);

Widget _bondToRubles(BuildContext context, Color tint) =>
    LessonBondToRubles(tint: tint);

Widget _ratingYield(BuildContext context, Color tint) =>
    LessonRatingYield(tint: tint);

Widget _taxSaldo(BuildContext context, Color tint) =>
    LessonTaxSaldo(tint: tint);

Widget _startEarly(BuildContext context, Color tint) =>
    LessonStartEarly(tint: tint);

Widget _phoneVsGarage(BuildContext context, Color tint) =>
    LessonPhoneVsGarage(tint: tint);

Widget _readTheTape(BuildContext context, Color tint) =>
    LessonReadTheTape(tint: tint);

Widget _orderBuilder(BuildContext context, Color tint) =>
    LessonOrderBuilder(tint: tint);

Widget _candleFromTrades(BuildContext context, Color tint) =>
    LessonCandleFromTrades(tint: tint);

Widget _diversificationDice(BuildContext context, Color tint) =>
    LessonDiversificationDice(tint: tint);

Widget _spreadGauge(BuildContext context, Color tint) =>
    LessonSpreadGauge(tint: tint);

Widget _ifThenRule(BuildContext context, Color tint) =>
    LessonIfThenRule(tint: tint);

Widget _styleAiry(BuildContext context, Color tint) =>
    StyleDirectionAiry(tint: tint);

Widget _styleCrisp(BuildContext context, Color tint) =>
    StyleDirectionCrisp(tint: tint);

Widget _styleWarm(BuildContext context, Color tint) =>
    StyleDirectionWarm(tint: tint);

Widget _kitCard(BuildContext context, Color tint) =>
    KitCanonicalBlock(tint: tint);

Widget _kitTokens(BuildContext context, Color tint) => KitTokens(tint: tint);

Widget _kitBits(BuildContext context, Color tint) => KitBits(tint: tint);

/// Сегмент тела урока: либо markdown-текст, либо именованный блок-директива.
sealed class LessonSegment {
  const LessonSegment();
}

class LessonText extends LessonSegment {
  const LessonText(this.markdown);

  final String markdown;
}

class LessonBlock extends LessonSegment {
  const LessonBlock(this.name);

  final String name;
}

final _directive = RegExp(r'^:::([a-z0-9-]+)\s*$');

/// Разбивает тело урока на текстовые сегменты и блоки-директивы. Неизвестные
/// директивы пропускаются (строка просто выкидывается), чтобы опечатка не
/// ломала рендер урока.
List<LessonSegment> parseLessonSegments(String body) {
  final segments = <LessonSegment>[];
  final buffer = StringBuffer();

  void flush() {
    final t = buffer.toString().trim();
    if (t.isNotEmpty) segments.add(LessonText(t));
    buffer.clear();
  }

  for (final line in body.split('\n')) {
    final match = _directive.firstMatch(line.trim());
    if (match != null && lessonBlockBuilders.containsKey(match.group(1))) {
      flush();
      segments.add(LessonBlock(match.group(1)!));
    } else {
      buffer.writeln(line);
    }
  }
  flush();
  return segments;
}
