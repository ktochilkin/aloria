import 'package:aloria/core/theme/components/list_items.dart';
import 'package:aloria/core/widgets/state_placeholder.dart';
import 'package:aloria/features/market/application/orders_provider.dart';
import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:aloria/features/market/presentation/positions/widgets/order_tile.dart';
import 'package:aloria/features/market/presentation/positions/widgets/portfolio_empty_card.dart';
import 'package:aloria/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Секция заявок на вкладке «Портфель»: активные первыми, затем по
/// времени; empty/loading/error состояния.
class OrdersListSection extends ConsumerWidget {
  const OrdersListSection({super.key, required this.orders});

  /// Заявки клиента.
  final AsyncValue<List<ClientOrder>> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return orders.when(
      data: (list) {
        final sorted = [...list]
          ..sort((a, b) {
            final activeCmp = (b.isActive ? 1 : 0) - (a.isActive ? 1 : 0);
            if (activeCmp != 0) return activeCmp;
            final aTime = a.updateTime ?? a.transTime;
            final bTime = b.updateTime ?? b.transTime;
            if (aTime != null && bTime != null) {
              return bTime.compareTo(aTime);
            }
            return b.id.compareTo(a.id);
          });
        if (sorted.isEmpty) {
          return PortfolioEmptyCard(
            text: AppLocalizations.of(context)!.portfolioEmptyOrders,
          );
        }

        return AppListSection(
          children: sorted.map((order) => OrderTile(order: order)).toList(),
        );
      },
      loading: () => const PortfolioSectionLoader(),
      error: (e, _) => StatePlaceholder(
        icon: Icons.cloud_off_outlined,
        title: 'Не получилось загрузить заявки',
        message: 'Проверь соединение и попробуй ещё раз.',
        actionLabel: 'Обновить',
        onAction: () => ref.invalidate(ordersProvider),
      ),
    );
  }
}
