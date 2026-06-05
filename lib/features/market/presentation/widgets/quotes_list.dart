import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/domain/market_price.dart';
import 'package:flutter/material.dart';

/// Лента последних сделок — компактные однострочные строки «цена · время»
/// с подсветкой направления тика (выше/ниже предыдущей сделки).
class QuotesList extends StatelessWidget {
  const QuotesList({super.key, required this.history, this.maxItems = 8});

  final List<MarketPrice> history;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reversed = history.reversed.take(maxItems).toList();

    if (reversed.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Center(
            child: Text(
              'Сделок пока нет',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < reversed.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 14,
                  endIndent: 14,
                  color: scheme.outline.withValues(alpha: 0.18),
                ),
              _TradeRow(
                price: reversed[i].price,
                ts: reversed[i].ts,
                // Следующий элемент в reversed — более старая сделка.
                previous: i + 1 < reversed.length
                    ? reversed[i + 1].price
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.price, required this.ts, this.previous});

  final double price;
  final DateTime ts;
  final double? previous;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final up = previous != null && price > previous!;
    final down = previous != null && price < previous!;
    final tickColor = up
        ? AppColors.success
        : down
            ? AppColors.error
            : scheme.onSurfaceVariant;

    final local = ts.toLocal();
    final timeStr =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          Icon(
            up
                ? Icons.arrow_drop_up
                : down
                    ? Icons.arrow_drop_down
                    : Icons.remove,
            size: 18,
            color: tickColor,
          ),
          const SizedBox(width: 2),
          Text(
            price.toStringAsFixed(2),
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: tickColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          Text(
            timeStr,
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
