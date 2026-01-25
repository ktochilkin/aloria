import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/domain/order_book.dart';
import 'package:flutter/material.dart';

/// Виджет для отображения биржевого стакана (order book)
class OrderBookWidget extends StatelessWidget {
  const OrderBookWidget({
    super.key,
    required this.book,
    this.onSelectPrice,
    this.maxLevels = 8,
  });

  final OrderBook? book;
  final ValueChanged<double>? onSelectPrice;
  final int maxLevels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final asks = (book?.asks ?? const <OrderBookLevel>[])
        .take(maxLevels)
        .toList();
    final bids = (book?.bids ?? const <OrderBookLevel>[])
        .take(maxLevels)
        .toList();
    final maxVolume = [
      ...asks.map((e) => e.volume.abs()),
      ...bids.map((e) => e.volume.abs()),
    ].fold<double>(0, (p, v) => v > p ? v : p);
    final label = book == null
        ? 'ждём первую пачку...'
        : 'обновлено в ${TimeOfDay.fromDateTime(book!.ts).format(context)}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Стакан',
                    style: text.labelMedium?.copyWith(color: scheme.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: OrderBookSide(
                    title: 'Покупка',
                    isAsk: false,
                    levels: bids,
                    maxVolume: maxVolume,
                    onSelectPrice: onSelectPrice,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OrderBookSide(
                    title: 'Продажа',
                    isAsk: true,
                    levels: asks,
                    maxVolume: maxVolume,
                    onSelectPrice: onSelectPrice,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Виджет для отображения одной стороны стакана (покупка или продажа)
class OrderBookSide extends StatelessWidget {
  const OrderBookSide({
    super.key,
    required this.title,
    required this.isAsk,
    required this.levels,
    required this.maxVolume,
    this.onSelectPrice,
  });

  final String title;
  final bool isAsk;
  final List<OrderBookLevel> levels;
  final double maxVolume;
  final ValueChanged<double>? onSelectPrice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = isAsk ? AppColors.error : AppColors.success;
    return Column(
      crossAxisAlignment: isAsk
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isAsk
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Icon(
              isAsk ? Icons.north_east : Icons.south_west,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(title, style: text.labelMedium?.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 8),
        if (levels.isEmpty)
          Text(
            'нет заявок',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          ...levels.map(
            (level) => OrderBookRow(
              level: level,
              isAsk: isAsk,
              maxVolume: maxVolume <= 0 ? 1 : maxVolume,
              color: color,
              onSelectPrice: onSelectPrice,
            ),
          ),
      ],
    );
  }
}

/// Виджет для отображения одной строки в стакане заявок
class OrderBookRow extends StatelessWidget {
  const OrderBookRow({
    super.key,
    required this.level,
    required this.isAsk,
    required this.maxVolume,
    required this.color,
    this.onSelectPrice,
  });

  final OrderBookLevel level;
  final bool isAsk;
  final double maxVolume;
  final Color color;
  final ValueChanged<double>? onSelectPrice;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ratio = (level.volume / maxVolume).clamp(0.12, 1.0);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onSelectPrice != null ? () => onSelectPrice!(level.price) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Align(
              alignment: isAsk ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                alignment: isAsk ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: isAsk
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  if (!isAsk) ...[
                    Text(
                      level.price.toStringAsFixed(2),
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${level.volume.toStringAsFixed(0)} лотов',
                      style: text.bodySmall,
                    ),
                  ] else ...[
                    Text(
                      '${level.volume.toStringAsFixed(0)} лотов',
                      style: text.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      level.price.toStringAsFixed(2),
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

/// Скелетон для стакана заявок (отображается во время загрузки)
class OrderBookSkeleton extends StatelessWidget {
  const OrderBookSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            6,
            (index) => Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              height: 38,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Виджет для отображения ошибки загрузки стакана
class OrderBookError extends StatelessWidget {
  const OrderBookError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: text.bodyMedium?.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
