import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:flutter/material.dart';

/// Интерактивный двухколоночный стакан (как в торговле): слева покупка, справа
/// продажа. Слайдер «купить по рынку» съедает заявки на продажу от лучшей цены
/// вверх и показывает среднюю цену исполнения и проскальзывание. Собран на
/// block_kit (стиль «воздух»): обёртка — LessonBlockCard, слайдер — BlockSlider,
/// итог — BlockMetric/BlockChip. Сами строки стакана с барами глубины —
/// доменная суть блока, оставлены как кастомная вёрстка.
class LessonOrderbookTwoCol extends StatefulWidget {
  const LessonOrderbookTwoCol({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonOrderbookTwoCol> createState() => _LessonOrderbookTwoColState();
}

class _Lvl {
  const _Lvl(this.price, this.vol);
  final double price;
  final int vol;
}

class _LessonOrderbookTwoColState extends State<LessonOrderbookTwoCol> {
  // bids: по убыванию цены; asks: по возрастанию (лучший ask первый).
  static const _bids = <_Lvl>[
    _Lvl(311.20, 16),
    _Lvl(311.00, 13),
    _Lvl(310.80, 21),
    _Lvl(310.50, 9),
  ];
  static const _asks = <_Lvl>[
    _Lvl(311.50, 14),
    _Lvl(311.70, 11),
    _Lvl(312.00, 18),
    _Lvl(312.40, 25),
  ];

  double _lots = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final maxVol = [..._bids, ..._asks]
        .map((l) => l.vol)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    // Сколько asks съедает рыночная покупка _lots.
    var remaining = _lots.round();
    var cost = 0.0;
    var filled = 0;
    final eaten = <bool>[];
    for (final a in _asks) {
      if (remaining <= 0) {
        eaten.add(false);
        continue;
      }
      final take = remaining < a.vol ? remaining : a.vol;
      cost += take * a.price;
      filled += take;
      remaining -= take;
      eaten.add(true);
    }
    final best = _asks.first.price;
    final avg = filled > 0 ? cost / filled : best;
    final slip = (avg - best) / best * 100;

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Стакан',
      subtitle: 'Заявки на покупку и продажу по уровням цены',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Покупка',
                    style: text.labelMedium
                        ?.copyWith(color: BlockChartColors.success)),
              ),
              Expanded(
                child: Text('Продажа',
                    textAlign: TextAlign.right,
                    style: text.labelMedium
                        ?.copyWith(color: BlockChartColors.error)),
              ),
            ],
          ),
          const SizedBox(height: BlockSpacing.s),
          for (var i = 0; i < _bids.length; i++)
            Row(
              children: [
                Expanded(
                  child: _Row(
                    level: _bids[i],
                    maxVol: maxVol,
                    color: BlockChartColors.success,
                    isAsk: false,
                    dimmed: false,
                  ),
                ),
                const SizedBox(width: BlockSpacing.s),
                Expanded(
                  child: _Row(
                    level: _asks[i],
                    maxVol: maxVol,
                    color: BlockChartColors.error,
                    isAsk: true,
                    dimmed: eaten[i],
                  ),
                ),
              ],
            ),
          const SizedBox(height: BlockSpacing.m),
          BlockSlider(
            tint: widget.tint,
            label: 'Купить по рынку',
            valueLabel: '${_lots.round()} лот.',
            value: _lots,
            min: 0,
            max: 40,
            divisions: 40,
            onChanged: (v) => setState(() => _lots = v),
          ),
          const SizedBox(height: BlockSpacing.s),
          if (_lots >= 1)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: BlockMetric(
                    label: 'средняя цена исполнения',
                    value: avg.toStringAsFixed(2),
                    color: widget.tint,
                  ),
                ),
                BlockChip(
                  text: slip > 0.005
                      ? '−${slip.toStringAsFixed(2)}% к лучшей'
                      : 'по лучшей цене',
                  tint: widget.tint,
                  tone: slip > 0.005 ? BlockTone.error : BlockTone.success,
                ),
              ],
            )
          else
            Text('Двигай слайдер — заявка съедает стакан сверху вниз.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.level,
    required this.maxVol,
    required this.color,
    required this.isAsk,
    required this.dimmed,
  });

  final _Lvl level;
  final double maxVol;
  final Color color;
  final bool isAsk;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final frac = (level.vol / maxVol).clamp(0.08, 1.0);
    return AnimatedOpacity(
      opacity: dimmed ? 0.25 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        height: 30,
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Stack(
          children: [
            Align(
              alignment: isAsk ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BlockRadii.innerBr,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BlockSpacing.s),
              child: Row(
                mainAxisAlignment:
                    isAsk ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isAsk) ...[
                    Text(level.price.toStringAsFixed(2),
                        style: text.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: BlockSpacing.s),
                    Text('${level.vol}',
                        style: text.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ] else ...[
                    Text('${level.vol}',
                        style: text.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(width: BlockSpacing.s),
                    Text(level.price.toStringAsFixed(2),
                        style: text.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
