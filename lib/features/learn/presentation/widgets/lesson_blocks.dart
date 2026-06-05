import 'package:aloria/features/learn/presentation/widgets/lesson_compound_growth.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_liquidity_orderbook.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_rate_price_seesaw.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_risk_fork.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_scam_flags.dart';
import 'package:flutter/material.dart';

/// Строит интерактивный/визуальный блок урока по имени директивы.
typedef LessonBlockBuilder = Widget Function(BuildContext context, Color tint);

/// Реестр учебных блоков-директив. В теле урока строка вида `:::имя` на
/// отдельной строке заменяется на соответствующий виджет. Текст вокруг
/// директивы рендерится обычным markdown.
const Map<String, LessonBlockBuilder> lessonBlockBuilders = {
  'orderbook-liquidity': _orderbookLiquidity,
  'compound-growth': _compoundGrowth,
  'rate-price-seesaw': _ratePriceSeesaw,
  'risk-fork': _riskFork,
  'scam-flags': _scamFlags,
};

Widget _orderbookLiquidity(BuildContext context, Color tint) =>
    LessonLiquidityOrderbook(tint: tint);

Widget _compoundGrowth(BuildContext context, Color tint) =>
    LessonCompoundGrowth(tint: tint);

Widget _ratePriceSeesaw(BuildContext context, Color tint) =>
    LessonRatePriceSeesaw(tint: tint);

Widget _riskFork(BuildContext context, Color tint) => LessonRiskFork(tint: tint);

Widget _scamFlags(BuildContext context, Color tint) =>
    LessonScamFlags(tint: tint);

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
