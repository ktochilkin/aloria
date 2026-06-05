import 'package:aloria/features/learn/presentation/widgets/lesson_allocation_pie.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_charts_extra.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_compound_growth.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_divgap_chart.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_inflation_erosion.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_leverage_seesaw.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_liquidity_orderbook.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_orderbook_2col.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_predict_candle.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_rate_price_seesaw.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_risk_fork.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_scam_flags.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_static_blocks.dart';
import 'package:flutter/material.dart';

/// Строит интерактивный/визуальный блок урока по имени директивы.
typedef LessonBlockBuilder = Widget Function(BuildContext context, Color tint);

/// Реестр учебных блоков-директив. В теле урока строка вида `:::имя` на
/// отдельной строке заменяется на соответствующий виджет. Текст вокруг
/// директивы рендерится обычным markdown.
const Map<String, LessonBlockBuilder> lessonBlockBuilders = {
  'orderbook-liquidity': _orderbookLiquidity,
  'orderbook-2col': _orderbook2col,
  'compound-growth': _compoundGrowth,
  'divgap-chart': _divgapChart,
  'rate-price-seesaw': _ratePriceSeesaw,
  'leverage-seesaw': _leverageSeesaw,
  'risk-fork': _riskFork,
  'scam-flags': _scamFlags,
  'callout': _calloutDemo,
  'number-accent': _numberAccent,
  'compare-cards': _compareCards,
  'flow-broker': _flowBroker,
  'timeline-tplus': _timelineTplus,
  'allocation-pie': _allocationPie,
  'predict-candle': _predictCandle,
  'index-vs-fund': _indexVsFund,
  'pnl-live': _pnlLive,
  'inflation-erosion': _inflationErosion,
};

Widget _orderbookLiquidity(BuildContext context, Color tint) =>
    LessonLiquidityOrderbook(tint: tint);

Widget _orderbook2col(BuildContext context, Color tint) =>
    LessonOrderbookTwoCol(tint: tint);

Widget _compoundGrowth(BuildContext context, Color tint) =>
    LessonCompoundGrowth(tint: tint);

Widget _divgapChart(BuildContext context, Color tint) =>
    LessonDivGapChart(tint: tint);

Widget _ratePriceSeesaw(BuildContext context, Color tint) =>
    LessonRatePriceSeesaw(tint: tint);

Widget _leverageSeesaw(BuildContext context, Color tint) =>
    LessonLeverageSeesaw(tint: tint);

Widget _riskFork(BuildContext context, Color tint) => LessonRiskFork(tint: tint);

Widget _scamFlags(BuildContext context, Color tint) =>
    LessonScamFlags(tint: tint);

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

Widget _allocationPie(BuildContext context, Color tint) =>
    LessonAllocationPie(tint: tint);

Widget _predictCandle(BuildContext context, Color tint) =>
    LessonPredictCandle(tint: tint);

Widget _indexVsFund(BuildContext context, Color tint) =>
    LessonIndexVsFund(tint: tint);

Widget _pnlLive(BuildContext context, Color tint) => LessonPnlLive(tint: tint);

Widget _inflationErosion(BuildContext context, Color tint) =>
    LessonInflationErosion(tint: tint);

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
