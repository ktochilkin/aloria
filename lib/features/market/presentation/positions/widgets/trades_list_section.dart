import 'package:aloria/core/theme/components/list_items.dart';
import 'package:aloria/core/widgets/state_placeholder.dart';
import 'package:aloria/features/market/application/trades_provider.dart';
import 'package:aloria/features/market/domain/portfolio_trade.dart';
import 'package:aloria/features/market/presentation/positions/widgets/portfolio_empty_card.dart';
import 'package:aloria/features/market/presentation/positions/widgets/trade_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Секция «Сделки» на вкладке портфеля: история исполнений, свежие сверху.
class TradesListSection extends ConsumerWidget {
  const TradesListSection({super.key, required this.trades});

  /// Сделки по портфелю.
  final AsyncValue<List<PortfolioTrade>> trades;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return trades.when(
      data: (list) {
        if (list.isEmpty) {
          return const PortfolioEmptyCard(
            icon: Icons.receipt_long_outlined,
            text: 'Сделок пока нет',
          );
        }
        return AppListSection(
          children: [
            for (final t in list.take(50)) TradeTile(trade: t),
          ],
        );
      },
      loading: () => const PortfolioSectionLoader(),
      error: (e, _) => StatePlaceholder(
        icon: Icons.cloud_off_outlined,
        title: 'Не получилось загрузить сделки',
        message: 'Проверь соединение и попробуй ещё раз.',
        actionLabel: 'Обновить',
        onAction: () => ref.invalidate(tradesProvider),
      ),
    );
  }
}
