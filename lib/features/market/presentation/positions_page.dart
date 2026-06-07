import 'package:aloria/core/theme/components/list_items.dart';
import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/core/widgets/top_notification.dart';
import 'package:aloria/features/auth/application/auth_controller.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/learn/presentation/widgets/server_quiz_block.dart';
import 'package:aloria/features/learning_mode/presentation/explainable.dart';
import 'package:aloria/features/market/application/orders_provider.dart';
import 'package:aloria/features/market/application/portfolio_summary_provider.dart';
import 'package:aloria/features/market/application/positions_provider.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:aloria/features/market/domain/portfolio_summary.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/numeric_text.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:aloria/features/settings/application/settings_controller.dart';
import 'package:aloria/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

enum _PortfolioTab { positions, orders }

final portfolioTabProvider = StateProvider<_PortfolioTab>(
  (_) => _PortfolioTab.positions,
);

class PositionsPage extends ConsumerWidget {
  const PositionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = ref.watch(positionsProvider);
    final summary = ref.watch(portfolioSummaryProvider);
    final orders = ref.watch(ordersProvider);
    final auth = ref.read(authControllerProvider.notifier);

    // Как только видим хотя бы одну ненулевую позицию — отправляем
    // событие «первая сделка» в aloria-api. Бэкенд идемпотентен,
    // повторные вызовы безопасны (UNIQUE индекс по userId+code).
    ref.listen<AsyncValue<List<Position>>>(positionsProvider, (prev, next) {
      next.whenData((list) {
        final hasPosition = list.any((p) => p.quantity != 0);
        if (!hasPosition) return;
        final portfolioId = ref.read(aloriaPortfolioIdProvider);
        final client = ref.read(learningApiClientProvider);
        // Огонь и забыли: ошибки сети не должны ломать UI.
        client.reportFirstPosition(portfolioId).catchError((_) {});
      });
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _PositionsBlock(
          positions: positions,
          summary: summary,
          orders: orders,
          onLogout: auth.logout,
        ),
      ),
    );
  }
}

class _PositionsBlock extends ConsumerStatefulWidget {
  const _PositionsBlock({
    required this.positions,
    required this.summary,
    required this.orders,
    required this.onLogout,
  });
  final AsyncValue<List<Position>> positions;
  final AsyncValue<PortfolioSummary> summary;
  final AsyncValue<List<ClientOrder>> orders;
  final Future<void> Function() onLogout;

  @override
  ConsumerState<_PositionsBlock> createState() => _PositionsBlockState();
}

class _PositionsBlockState extends ConsumerState<_PositionsBlock>
    with TickerProviderStateMixin {
  String _sideLabel(OrderSide side) =>
      side == OrderSide.buy ? 'Покупка' : 'Продажа';

  String _typeLabel(OrderType type) =>
      type == OrderType.limit ? 'Лимит' : 'Рыночная';

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.working:
        return 'Активна';
      case OrderStatus.filled:
        return 'Исполнена';
      case OrderStatus.canceled:
        return 'Отменена';
      case OrderStatus.rejected:
        return 'Отклонена';
      case OrderStatus.unknown:
        return 'Неизвестно';
    }
  }

  Color _statusColor(OrderStatus status, ColorScheme scheme) {
    switch (status) {
      case OrderStatus.working:
        return scheme.primary;
      case OrderStatus.filled:
        return scheme.secondary;
      case OrderStatus.canceled:
      case OrderStatus.rejected:
        return scheme.error;
      case OrderStatus.unknown:
        return scheme.outline;
    }
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '--:--';
    final local = value.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _handleCancelOrder(
    BuildContext context,
    WidgetRef ref,
    ClientOrder order,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить заявку?'),
        content: Text(
          'Вы уверены, что хотите отменить заявку на ${_sideLabel(order.side).toLowerCase()} ${order.symbol}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Нет'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final cancelOrder = ref.read(cancelOrderProvider);
      await cancelOrder(
        orderId: order.id,
        portfolio: order.portfolio,
        exchange: order.exchange,
      );

      if (context.mounted) {
        showTopNotification(context, 'Заявка отменена');
      }
    } catch (e) {
      if (context.mounted) {
        showTopNotification(context, 'Ошибка отмены: $e', isError: true);
      }
    }
  }

  Future<void> _openTopUp() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _TopUpPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tab = ref.watch(portfolioTabProvider);

    final positionsCount = widget.positions.maybeWhen(
      data: (l) => l.where((p) => p.quantity != 0).length,
      orElse: () => 0,
    );
    final activeOrdersCount = widget.orders.maybeWhen(
      data: (l) => l.where((o) => o.isActive).length,
      orElse: () => 0,
    );

    final positionsWidget = widget.positions.when(
      data: (list) {
        final items = list.where((p) => p.quantity != 0).take(50).toList();
        if (items.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outline),
            ),
            child: Text(
              AppLocalizations.of(context)!.portfolioEmptyPositions,
              style: text.bodyMedium,
            ),
          );
        }

        return AppListSection(
          children: items.map((p) => _PositionTile(position: p)).toList(),
        );
      },
      loading: () => const Center(
        child: SizedBox(
          height: 56,
          width: 56,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Center(child: Text('Ошибка позиций: $e')),
    );

    final ordersWidget = widget.orders.when(
      data: (orders) {
        final sorted = [...orders]
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
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outline),
            ),
            child: Text(
              AppLocalizations.of(context)!.portfolioEmptyOrders,
              style: text.bodyMedium,
            ),
          );
        }

        return AppListSection(
          children: sorted.map((order) {
            final statusColor = _statusColor(order.status, scheme);
            final label = _statusLabel(order.status);
            final filled = order.filledQtyBatch ?? order.filled ?? 0;
            final qty = order.qtyBatch ?? order.qty ?? order.qtyUnits;
            final priceLabel = order.type == OrderType.market
                ? 'По рынку'
                : (order.price != null ? order.price!.toStringAsFixed(2) : '—');
            return AppListTile(
              // Заявка на вкладке «Портфель», а торговля инструментом — в ветке
              // «Рынок». go_router переключает ветку и открывает инструмент;
              // push не годится — отрисовал бы страницу в неактивной ветке.
              onTap: () => context.go(
                '/market/${order.symbol}',
                extra: MarketSecurity(
                  symbol: order.symbol,
                  shortName: order.symbol,
                  exchange: order.exchange,
                ),
              ),
              title: order.symbol,
              subtitleWidget: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.labelMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_sideLabel(order.side)} · ${_typeLabel(order.type)} · ${_formatTime(order.updateTime ?? order.transTime)}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              trailing: Container(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _orderStat(
                      context,
                      'Объём:',
                      qty != null ? '$qty' : '—',
                      mono: qty != null,
                    ),
                    const SizedBox(height: 4),
                    _orderStat(
                      context,
                      'Цена:',
                      priceLabel,
                      mono: order.type != OrderType.market,
                    ),
                    if (filled > 0) ...[
                      const SizedBox(height: 4),
                      _orderStat(context, 'Исполнено:', '$filled', mono: true),
                    ],
                    if (order.isActive) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () =>
                            _handleCancelOrder(context, ref, order),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: Colors.orange, width: 1.5),
                          foregroundColor: Colors.orange,
                        ),
                        child: const Text(
                          'Отменить',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              isThreeLine: true,
              topAlignTrailing: true,
            );
          }).toList(),
        );
      },
      loading: () => const Center(
        child: SizedBox(
          height: 56,
          width: 56,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Center(child: Text('Ошибка заявок: $e')),
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, context.bottomNavBarPadding),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _PortfolioTitleBar(),
              const SizedBox(height: 12),
              Explainable(
                slug: 'portfolio.hero',
                borderRadius: BorderRadius.circular(20),
                child: _PortfolioHero(
                  summary: widget.summary,
                  positions: widget.positions,
                  onTopUp: _openTopUp,
                ),
              ),
              const SizedBox(height: 18),
              Explainable(
                slug: 'portfolio.tabs',
                borderRadius: BorderRadius.circular(8),
                child: _PortfolioTabsHeader(
                  selected: tab,
                  positionsCount: positionsCount,
                  ordersCount: activeOrdersCount,
                  onSelected: (next) {
                    ref.read(portfolioTabProvider.notifier).state = next;
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (tab == _PortfolioTab.positions)
                positionsWidget
              else
                ordersWidget,
            ]),
          ),
        ),
      ],
    );
  }
}

class _PortfolioTitleBar extends ConsumerWidget {
  const _PortfolioTitleBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final learningMode = ref.watch(
      settingsControllerProvider.select((s) => s.learningMode),
    );
    return Row(
      children: [
        Text(
          l.portfolioTitle,
          style: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.0,
            letterSpacing: -0.4,
            color: scheme.onSurface,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            tooltip: l.settingsLearningMode,
            padding: EdgeInsets.zero,
            iconSize: 22,
            visualDensity: VisualDensity.compact,
            color: learningMode
                ? AppColors.primary
                : scheme.onSurfaceVariant,
            icon: Icon(
              learningMode ? Icons.school : Icons.school_outlined,
            ),
            onPressed: () => ref
                .read(settingsControllerProvider.notifier)
                .setLearningMode(!learningMode),
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            tooltip: 'Прогресс',
            padding: EdgeInsets.zero,
            iconSize: 22,
            visualDensity: VisualDensity.compact,
            color: scheme.onSurfaceVariant,
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push('/progress'),
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            tooltip: l.settingsTitle,
            padding: EdgeInsets.zero,
            iconSize: 22,
            visualDensity: VisualDensity.compact,
            color: scheme.onSurfaceVariant,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ),
      ],
    );
  }
}

class _PortfolioHero extends StatelessWidget {
  const _PortfolioHero({
    required this.summary,
    required this.positions,
    required this.onTopUp,
  });

  final AsyncValue<PortfolioSummary> summary;
  final AsyncValue<List<Position>> positions;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final positionsList = positions.maybeWhen(
      data: (l) => l.where((p) => p.quantity != 0).toList(),
      orElse: () => const <Position>[],
    );

    final summaryValue = summary.maybeWhen(
      data: (s) => s,
      orElse: () => null,
    );

    final positionsTotal = positionsList.fold<double>(
      0,
      (s, p) => s + p.currentVolume.abs(),
    );
    final totalPl = positionsList.fold<double>(
      0,
      (s, p) => s + (p.unrealisedPl ?? 0),
    );
    final hasPl = positionsList.any((p) => p.unrealisedPl != null);
    final plPercent = positionsTotal > 0
        ? (totalPl / positionsTotal) * 100
        : 0.0;

    final buyingPower = summaryValue?.buyingPower ?? 0;
    final liquidationValue =
        summaryValue?.liquidationValue ?? buyingPower + positionsTotal;

    final currencySymbol = summaryValue?.currency == 'USD'
        ? '\$'
        : summaryValue?.currency == 'EUR'
            ? '€'
            : '₽';

    final isLoading = summary.isLoading && summaryValue == null;
    final hasError = summary.hasError && summaryValue == null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Диагональный sheen: едва заметный перелив угол-в-угол —
          // коралл сверху-слева, чистый центр, синий снизу-справа.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.12),
                      Colors.transparent,
                      AppColors.primary.withValues(alpha: 0.09),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(
            AppLocalizations.of(context)!.portfolioEvaluationCaption,
            style: text.bodySmall?.copyWith(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (isLoading)
            const _HeroLoading()
          else if (hasError)
            Text(
              'Нет данных',
              style: text.bodyLarge?.copyWith(color: scheme.error),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      maxLines: 1,
                      text: TextSpan(
                        style: GoogleFonts.nunito(
                          color: scheme.onSurface,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          letterSpacing: -0.8,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        children: [
                          TextSpan(text: _formatMoney(liquidationValue)),
                          TextSpan(
                            text: ' $currencySymbol',
                            style: GoogleFonts.nunito(
                              color: scheme.onSurfaceVariant,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _TopUpPill(onTap: onTopUp),
              ],
            ),
          const SizedBox(height: 14),
          const _HeroDivider(),
          const SizedBox(height: 12),
          _PortfolioSummaryRow(
            inPositions: positionsTotal,
            buyingPower: buyingPower,
            plPercent: hasPl ? plPercent : null,
            plPositive: totalPl >= 0,
            currencySymbol: currencySymbol,
          ),
          if (positionsList.isNotEmpty) ...[
            const SizedBox(height: 14),
            const _HeroDivider(),
            const SizedBox(height: 14),
            _PortfolioStackBar(positions: positionsList),
          ] else if (summaryValue != null && buyingPower > 0) ...[
            const SizedBox(height: 14),
            const _HeroDivider(),
            const SizedBox(height: 14),
            Text(
              'Нет открытых позиций · перейти к обзору рынка',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLoading extends StatelessWidget {
  const _HeroLoading();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          height: 32,
          width: 180,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: context.palette.heroBorder);
  }
}

class _TopUpPill extends StatelessWidget {
  const _TopUpPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)!.portfolioTopUp,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioSummaryRow extends StatelessWidget {
  const _PortfolioSummaryRow({
    required this.inPositions,
    required this.buyingPower,
    required this.plPercent,
    required this.plPositive,
    required this.currencySymbol,
  });

  final double inPositions;
  final double buyingPower;
  final double? plPercent;
  final bool plPositive;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plColor = plPositive ? AppColors.success : AppColors.error;
    final plText = plPercent == null
        ? '—'
        : '${plPositive ? '+' : '−'}${plPercent!.abs().toStringAsFixed(2)}%';

    final l = AppLocalizations.of(context)!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SummaryColumn(
              caption: l.portfolioInPositions,
              value: '${_formatMoneyCompact(inPositions)} $currencySymbol',
              valueColor: scheme.onSurface,
            ),
          ),
          const _ColumnDivider(),
          Expanded(
            child: _SummaryColumn(
              caption: l.portfolioBuyingPower,
              value: '${_formatMoneyCompact(buyingPower)} $currencySymbol',
              valueColor: AppColors.primary,
            ),
          ),
          const _ColumnDivider(),
          Expanded(
            child: _SummaryColumn(
              caption: l.portfolioPnl,
              value: plText,
              valueColor: plPercent == null ? scheme.onSurface : plColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.caption,
    required this.value,
    required this.valueColor,
  });

  final String caption;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          caption,
          style: GoogleFonts.nunito(
            fontSize: 10,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(
            fontSize: 15,
            color: valueColor,
            fontWeight: FontWeight.w600,
            height: 1.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ColumnDivider extends StatelessWidget {
  const _ColumnDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.palette.heroBorder,
    );
  }
}

/// Строка заявки «label значение» — значение моноширинным, если это число.
Widget _orderStat(
  BuildContext context,
  String label,
  String value, {
  required bool mono,
}) {
  final text = Theme.of(context).textTheme;
  return Text.rich(
    TextSpan(
      style: text.bodySmall,
      children: [
        TextSpan(text: '$label '),
        TextSpan(
          text: value,
          style: mono ? monoNum(size: 12, weight: FontWeight.w500) : null,
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    softWrap: false,
    textAlign: TextAlign.right,
  );
}

String _formatMoney(double v) {
  final fixed = v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final neg = intPart.startsWith('-');
  final abs = neg ? intPart.substring(1) : intPart;
  final buf = StringBuffer();
  for (var i = 0; i < abs.length; i++) {
    if (i > 0 && (abs.length - i) % 3 == 0) buf.write(' ');
    buf.write(abs[i]);
  }
  return '${neg ? '−' : ''}$buf,${parts[1]}';
}

String _formatMoneyCompact(double v) {
  final intPart = v.truncate().toString();
  final neg = intPart.startsWith('-');
  final abs = neg ? intPart.substring(1) : intPart;
  final buf = StringBuffer();
  for (var i = 0; i < abs.length; i++) {
    if (i > 0 && (abs.length - i) % 3 == 0) buf.write(' ');
    buf.write(abs[i]);
  }
  return '${neg ? '−' : ''}$buf';
}

class _PortfolioStackBar extends StatelessWidget {
  const _PortfolioStackBar({required this.positions});

  final List<Position> positions;

  // Палитра по спецификации: 6 цветов, 7-й (серый) — для «Прочих» в long-tail.
  static const _palette = [
    Color(0xFF5D8CFF),
    Color(0xFF7FA5FF),
    Color(0xFF9CBBFF),
    Color(0xFFFF9E7C),
    Color(0xFFFFB89A),
    Color(0xFFC8C8D0),
  ];
  static const _restColor = Color(0xFFC8C8D0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final sorted = [...positions]
      ..sort((a, b) => b.currentVolume.abs().compareTo(a.currentVolume.abs()));
    final total = sorted.fold<double>(0, (s, p) => s + p.currentVolume.abs());
    if (total <= 0) return const SizedBox.shrink();

    final topItems = <(Position pos, Color color, double share)>[];
    final useRest = sorted.length > 8;
    final visibleCount = useRest ? _palette.length - 1 : sorted.length;
    for (var i = 0; i < sorted.length && i < visibleCount; i++) {
      final share = sorted[i].currentVolume.abs() / total;
      topItems.add((sorted[i], _palette[i % _palette.length], share));
    }
    final restShare = useRest
        ? sorted
            .skip(visibleCount)
            .fold<double>(0, (s, p) => s + p.currentVolume.abs() / total)
        : 0.0;
    final hasRest = restShare > 0.001;

    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l.portfolioDistribution,
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Text(
              l.portfolioCount(sorted.length),
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 8,
          child: Row(
            children: [
              for (var i = 0; i < topItems.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: (topItems[i].$3 * 1000).round().clamp(1, 1000),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(color: topItems[i].$2),
                  ),
                ),
              ],
              if (hasRest) ...[
                const SizedBox(width: 2),
                Expanded(
                  flex: (restShare * 1000).round().clamp(1, 1000),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(color: _restColor),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final item in topItems)
              _LegendItem(
                color: item.$2,
                symbol: item.$1.symbol,
                share: item.$3,
              ),
            if (hasRest)
              _LegendItem(
                color: _restColor,
                symbol: 'Прочие',
                share: restShare,
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.symbol,
    required this.share,
  });

  final Color color;
  final String symbol;
  final double share;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          symbol,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${(share * 100).round()}%',
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}


class _TopUpQuizSummary {
  const _TopUpQuizSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardBuyingPower,
    required this.questionCount,
  });

  final String id;
  final String title;
  final String description;
  final double rewardBuyingPower;
  final int questionCount;

  factory _TopUpQuizSummary.fromJson(Map<String, dynamic> json) {
    return _TopUpQuizSummary(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      rewardBuyingPower: (json['rewardBuyingPower'] as num?)?.toDouble() ?? 0,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    );
  }
}

final _topUpQuizzesProvider =
    FutureProvider<List<_TopUpQuizSummary>>((ref) async {
  final client = ref.watch(learningApiClientProvider);
  final raw = await client.fetchTopUpQuizzes();
  return raw.map(_TopUpQuizSummary.fromJson).toList(growable: false);
});

class _TopUpPage extends ConsumerWidget {
  const _TopUpPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final list = ref.watch(_topUpQuizzesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расширить доступ'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(_topUpQuizzesProvider);
          await ref.read(_topUpQuizzesProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Подтвердите знания',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Каждый пройденный тест увеличивает покупательную способность. '
                    'Это мера допуска: чем уверенней понимаете рынок — тем больше операций открыто.',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            list.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Не удалось загрузить тесты: $e',
                  style: text.bodyMedium?.copyWith(color: scheme.error),
                ),
              ),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Тестов пока нет — добавь их в админке.',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final q in items) _TopUpQuizCard(quiz: q),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopUpQuizCard extends StatelessWidget {
  const _TopUpQuizCard({required this.quiz});

  final _TopUpQuizSummary quiz;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) =>
                    _TopUpQuizPage(quizId: quiz.id, title: quiz.title),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.heroBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        quiz.title,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (quiz.rewardBuyingPower > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '+${quiz.rewardBuyingPower.toStringAsFixed(0)} ₽',
                          style: text.labelMedium?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                if (quiz.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    quiz.description,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.help_outline,
                        size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${quiz.questionCount} ${_questionWord(quiz.questionCount)}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _questionWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'вопрос';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return 'вопроса';
    }
    return 'вопросов';
  }
}

class _TopUpQuizPage extends ConsumerWidget {
  const _TopUpQuizPage({required this.quizId, required this.title});

  final String quizId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ServerQuizBlock(
            quizId: quizId,
            tint: AppColors.primary,
            onPassed: (_) {},
          ),
        ],
      ),
    );
  }
}

class _PortfolioTabsHeader extends StatelessWidget {
  const _PortfolioTabsHeader({
    required this.selected,
    required this.positionsCount,
    required this.ordersCount,
    required this.onSelected,
  });

  final _PortfolioTab selected;
  final int positionsCount;
  final int ordersCount;
  final ValueChanged<_PortfolioTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          _TabButton(
            label: l.portfolioTabPositions,
            count: positionsCount,
            selected: selected == _PortfolioTab.positions,
            onTap: () => onSelected(_PortfolioTab.positions),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: l.portfolioTabOrders,
            count: ordersCount,
            selected: selected == _PortfolioTab.orders,
            onTap: () => onSelected(_PortfolioTab.orders),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: text.bodyLarge?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.16)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: text.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PositionTile extends StatelessWidget {
  const _PositionTile({required this.position});

  final Position position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final label = position.symbol.length > 2
        ? position.symbol.substring(0, 2)
        : position.symbol;

    return InkWell(
      // Тап по позиции открывает окно с деталями; переход в торговлю — кнопкой
      // внутри этого окна.
      onTap: () => _showPositionDetails(context, position),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            InstrumentAvatar(symbol: position.symbol, label: label, size: 36),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    position.symbol,
                    style: text.titleMedium?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      children: [
                        const TextSpan(text: 'Средняя '),
                        TextSpan(
                          text:
                              '${position.averagePrice.toStringAsFixed(2)} ${position.currency}',
                          style: monoNum(
                            size: 13,
                            weight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${position.quantity.toStringAsFixed(2)} шт.',
                  style: monoNum(size: 15, color: scheme.onSurface),
                ),
                if (position.unrealisedPl != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${position.unrealisedPl! >= 0 ? '+' : ''}${position.unrealisedPl!.toStringAsFixed(2)} ${position.currency}',
                    style: monoNum(
                      size: 13,
                      color: position.unrealisedPl! >= 0
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 2),
            SizedBox(
              width: 14,
              child: Transform.scale(
                scaleX: 0.65,
                scaleY: 1.7,
                child: Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Всплывашка со всей детальной информацией по позиции (раньше показывалась
/// при раскрытии плитки). Открывается по иконке-вопросу, чтобы сам тап по
/// позиции вёл в торговлю инструментом.
Future<void> _showPositionDetails(BuildContext context, Position position) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _PositionDetailsSheet(
      position: position,
      onTrade: () {
        Navigator.of(ctx).pop();
        context.go(
          '/market/${position.symbol}',
          extra: MarketSecurity(
            symbol: position.symbol,
            shortName: position.symbol,
            exchange: position.exchange,
          ),
        );
      },
    ),
  );
}

class _PositionDetailsSheet extends StatelessWidget {
  const _PositionDetailsSheet({required this.position, required this.onTrade});

  final Position position;
  final VoidCallback onTrade;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final label = position.symbol.length > 2
        ? position.symbol.substring(0, 2)
        : position.symbol;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                InstrumentAvatar(
                  symbol: position.symbol,
                  label: label,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    position.symbol,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      context,
                      label: 'Тикер',
                      value: position.symbol,
                      description: 'Краткое название инструмента на бирже.',
                    ),
                    _infoRow(
                      context,
                      label: 'Количество',
                      value: '${position.quantity} шт.',
                      description: 'Количество ценных бумаг в вашем портфеле.',
                      mono: true,
                    ),
                    _infoRow(
                      context,
                      label: 'Средняя цена',
                      value: '${position.averagePrice} ${position.currency}',
                      description:
                          'Цена покупки (усредненная, если было несколько сделок).',
                      mono: true,
                    ),
                    _infoRow(
                      context,
                      label: 'Текущая стоимость',
                      value: '${position.currentVolume} ${position.currency}',
                      description:
                          'Рыночная стоимость всего пакета бумаг сейчас.',
                      mono: true,
                    ),
                    if (position.unrealisedPl != null)
                      _infoRow(
                        context,
                        label: 'Нереализованная П/У',
                        value:
                            '${position.unrealisedPl! >= 0 ? '+' : ''}${position.unrealisedPl!.toStringAsFixed(2)} ${position.currency}',
                        description:
                            'Текущая доходность позиции (прибыль или убыток).',
                        mono: true,
                      ),
                    _infoRow(
                      context,
                      label: 'Биржа',
                      value: position.exchange,
                      description: 'Торговая площадка, где куплен инструмент.',
                    ),
                  ],
                ),
              ),
            ),
            // RUB — это денежная позиция (кэш), а не торгуемый инструмент,
            // поэтому кнопку перехода в торговлю для неё не показываем.
            if (position.symbol.toUpperCase() != 'RUB') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onTrade,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.show_chart, size: 18),
                  label: const Text('Торговать инструментом'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required String label,
    required String value,
    required String description,
    bool mono = false,
  }) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: mono
                      ? monoNum(size: 15, color: scheme.onSurface)
                      : text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
