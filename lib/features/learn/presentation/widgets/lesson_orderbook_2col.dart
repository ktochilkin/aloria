import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Интерактивный двухколоночный стакан (как в торговле): слева покупка, справа
/// продажа. Слайдер «купить по рынку» съедает заявки на продажу от лучшей цены
/// вверх и показывает среднюю цену исполнения и проскальзывание.
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

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Покупка',
                    style: text.labelMedium?.copyWith(color: AppColors.success)),
              ),
              Expanded(
                child: Text('Продажа',
                    textAlign: TextAlign.right,
                    style: text.labelMedium?.copyWith(color: AppColors.error)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < _bids.length; i++)
            Row(
              children: [
                Expanded(
                  child: _Row(
                    level: _bids[i],
                    maxVol: maxVol,
                    color: AppColors.success,
                    isAsk: false,
                    dimmed: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Row(
                    level: _asks[i],
                    maxVol: maxVol,
                    color: AppColors.error,
                    isAsk: true,
                    dimmed: eaten[i],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Купить по рынку: ${_lots.round()} лот.',
                  style: text.bodySmall),
              Expanded(
                child: Slider(
                  value: _lots,
                  max: 40,
                  divisions: 40,
                  activeColor: widget.tint,
                  onChanged: (v) => setState(() => _lots = v),
                ),
              ),
            ],
          ),
          if (_lots >= 1)
            Row(
              children: [
                Icon(slip > 0.05 ? Icons.trending_down : Icons.check_circle_outline,
                    size: 16,
                    color: slip > 0.05 ? AppColors.error : AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Средняя '),
                      TextSpan(
                          text: avg.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(
                          text: slip > 0.05
                              ? '  ·  −${slip.toStringAsFixed(2)}% к лучшей цене'
                              : '  ·  по лучшей цене'),
                    ]),
                    style: text.bodySmall,
                  ),
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
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment:
                    isAsk ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isAsk) ...[
                    Text(level.price.toStringAsFixed(2),
                        style: text.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Text('${level.vol}', style: text.bodySmall),
                  ] else ...[
                    Text('${level.vol}', style: text.bodySmall),
                    const SizedBox(width: 6),
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
