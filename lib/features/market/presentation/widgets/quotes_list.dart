import 'package:aloria/features/market/domain/market_price.dart';
import 'package:flutter/material.dart';

/// Виджет для отображения ленты последних сделок
class QuotesList extends StatelessWidget {
  const QuotesList({super.key, required this.history, this.maxItems = 5});

  final List<MarketPrice> history;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final reversed = history.reversed.take(maxItems).toList();
    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: reversed.length,
        separatorBuilder: (_, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = reversed[index];
          final time = item.ts.toLocal();
          final timeStr =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
          return ListTile(
            dense: true,
            title: Text(item.price.toStringAsFixed(2)),
            subtitle: Text(timeStr),
          );
        },
      ),
    );
  }
}
