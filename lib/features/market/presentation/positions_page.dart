import 'package:aloria/core/theme/components/list_items.dart';
import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/core/widgets/top_notification.dart';
import 'package:aloria/features/auth/application/auth_controller.dart';
import 'package:aloria/features/market/application/orders_provider.dart';
import 'package:aloria/features/market/application/portfolio_summary_provider.dart';
import 'package:aloria/features/market/application/positions_provider.dart';
import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:aloria/features/market/domain/portfolio_summary.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  Future<void> _handleQuizStart(_PortfolioQuiz quiz) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuizSheet(quiz: quiz),
    );

    if (result == true && mounted) {
      await _showSuccessDialog(quiz);
    }
  }

  Future<void> _openTopUp() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _TopUpPage(onQuizTap: _handleQuizStart),
      ),
    );
  }

  Future<void> _showSuccessDialog(_PortfolioQuiz quiz) async {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Поздравляем!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вы прошли тест «${quiz.title}». Счёт будет пополнен на ${quiz.reward} вирт. ₽.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              quiz.successNote,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
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
              gradient: LinearGradient(
                colors: [
                  scheme.surface.withValues(alpha: 0.96),
                  scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
            ),
            child: Text('Нет открытых позиций', style: text.bodyMedium),
          );
        }

        return AppListSection(
          children: items
              .map((p) => _PositionExpansionTile(position: p))
              .toList(),
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
              gradient: LinearGradient(
                colors: [
                  scheme.surface.withValues(alpha: 0.96),
                  scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
            ),
            child: Text('Заявок нет', style: text.bodyMedium),
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
                    Text(
                      qty != null ? 'Объём: $qty' : 'Объём: —',
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Цена: $priceLabel',
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    if (filled > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Исполнено: $filled',
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
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

    final positionsList = widget.positions.maybeWhen(
      data: (l) => l.where((p) => p.quantity != 0).toList(),
      orElse: () => const <Position>[],
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, context.bottomNavBarPadding),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _PortfolioBalanceCard(
                summary: widget.summary,
                onLogout: widget.onLogout,
              ),
              const SizedBox(height: 12),
              _PortfolioTilesGrid(
                positions: positionsList,
                onTopUp: _openTopUp,
                onMarket: () => context.go('/market'),
              ),
              const SizedBox(height: 18),
              _PortfolioTabsHeader(
                selected: tab,
                positionsCount: positionsCount,
                ordersCount: activeOrdersCount,
                onSelected: (next) {
                  ref.read(portfolioTabProvider.notifier).state = next;
                },
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

class _PortfolioBalanceCard extends StatelessWidget {
  const _PortfolioBalanceCard({
    required this.summary,
    required this.onLogout,
  });

  final AsyncValue<PortfolioSummary> summary;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Покупательная способность',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  tooltip: 'Выйти',
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  color: scheme.onSurfaceVariant,
                  icon: const Icon(Icons.logout),
                  onPressed: () => onLogout(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: summary.when(
              data: (value) => RichText(
                text: TextSpan(
                  style: text.headlineMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                    height: 1.05,
                    letterSpacing: -0.3,
                  ),
                  children: [
                    TextSpan(text: _formatMoney(value.buyingPower)),
                    TextSpan(
                      text: value.currency == 'RUB' ? ' ₽' : ' ${value.currency}',
                      style: text.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => SizedBox(
                height: 30,
                child: Row(
                  children: [
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Загружаем…',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              error: (e, _) => Text(
                'Нет данных',
                style: text.bodyLarge?.copyWith(color: scheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMoney(double v) {
  final fixed = v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final neg = intPart.startsWith('-');
  final abs = neg ? intPart.substring(1) : intPart;
  final buf = StringBuffer();
  for (var i = 0; i < abs.length; i++) {
    if (i > 0 && (abs.length - i) % 3 == 0) buf.write(' ');
    buf.write(abs[i]);
  }
  return '${neg ? '-' : ''}$buf.${parts[1]}';
}

class _PortfolioTilesGrid extends StatelessWidget {
  const _PortfolioTilesGrid({
    required this.positions,
    required this.onTopUp,
    required this.onMarket,
  });

  final List<Position> positions;
  final VoidCallback onTopUp;
  final VoidCallback onMarket;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Position? leader;
    Position? laggard;
    for (final p in positions) {
      final pl = p.unrealisedPl;
      if (pl == null) continue;
      if (pl > 0) {
        if (leader == null || (leader.unrealisedPl ?? 0) < pl) leader = p;
      } else if (pl < 0) {
        if (laggard == null || (laggard.unrealisedPl ?? 0) > pl) laggard = p;
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PortfolioTile(
                icon: Icons.add_rounded,
                title: 'Пополнить',
                subtitle: '${_portfolioQuizzes.length} тестов',
                tint: scheme.primary,
                background: scheme.primary.withValues(alpha: 0.10),
                onTap: onTopUp,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PortfolioTile(
                icon: Icons.show_chart_rounded,
                title: 'Рынок',
                subtitle: 'Найти инструмент',
                tint: scheme.secondary,
                background: scheme.secondary.withValues(alpha: 0.10),
                onTap: onMarket,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MoverTile(
                title: 'Лидер',
                position: leader,
                positive: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MoverTile(
                title: 'Аутсайдер',
                position: laggard,
                positive: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PortfolioTile extends StatelessWidget {
  const _PortfolioTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: tint, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoverTile extends StatelessWidget {
  const _MoverTile({
    required this.title,
    required this.position,
    required this.positive,
  });

  final String title;
  final Position? position;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = positive ? AppColors.success : AppColors.error;
    final hasData = position != null && position!.unrealisedPl != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                positive ? Icons.trending_up : Icons.trending_down,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasData) ...[
            Text(
              position!.symbol,
              style: text.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${positive ? '+' : ''}${_formatMoney(position!.unrealisedPl!)} ₽',
              style: text.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ] else ...[
            Text(
              '—',
              style: text.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'нет позиций',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopUpPage extends StatelessWidget {
  const _TopUpPage({required this.onQuizTap});

  final Future<void> Function(_PortfolioQuiz quiz) onQuizTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расширить доступ'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
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
          ..._portfolioQuizzes.map(
            (quiz) => _QuizCard(
              quiz: quiz,
              onTap: () async {
                Navigator.of(context).pop();
                await onQuizTap(quiz);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({required this.quiz, required this.onTap});

  final _PortfolioQuiz quiz;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.85),
              scheme.secondaryContainer.withValues(alpha: 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.onPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '+${quiz.reward} вирт. ₽',
                    style: text.labelMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(quiz.description, style: text.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.help_outline, size: 18, color: scheme.onPrimary),
                const SizedBox(width: 6),
                Text(
                  '${quiz.questions.length} вопросов',
                  style: text.bodySmall?.copyWith(color: scheme.onPrimary),
                ),
                const SizedBox(width: 14),
                Icon(
                  Icons.monetization_on_outlined,
                  size: 18,
                  color: scheme.onPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  '+${quiz.reward}',
                  style: text.bodySmall?.copyWith(color: scheme.onPrimary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.onPrimary,
                side: BorderSide(
                  color: scheme.onPrimary.withValues(alpha: 0.6),
                ),
                backgroundColor: scheme.surface.withValues(alpha: 0.08),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Пройти тест'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizSheet extends StatefulWidget {
  const _QuizSheet({required this.quiz});

  final _PortfolioQuiz quiz;

  @override
  State<_QuizSheet> createState() => _QuizSheetState();
}

class _QuizSheetState extends State<_QuizSheet> {
  int _currentIndex = 0;
  final Map<int, Set<int>> _answers = {};

  void _toggleOption(int optionIndex) {
    final question = widget.quiz.questions[_currentIndex];
    final current = _answers[_currentIndex] != null
        ? {..._answers[_currentIndex]!}
        : <int>{};

    if (question.allowsMultiple) {
      if (current.contains(optionIndex)) {
        current.remove(optionIndex);
      } else {
        current.add(optionIndex);
      }
    } else {
      current
        ..clear()
        ..add(optionIndex);
    }

    setState(() {
      _answers[_currentIndex] = current;
    });
  }

  bool _isQuizPassed() {
    for (final entry in widget.quiz.questions.asMap().entries) {
      final selected = _answers[entry.key] ?? <int>{};
      final correct = entry.value.options
          .asMap()
          .entries
          .where((o) => o.value.isCorrect)
          .map((o) => o.key)
          .toSet();

      if (selected.length != correct.length || !selected.containsAll(correct)) {
        return false;
      }
    }
    return true;
  }

  void _goNext() {
    final selected = _answers[_currentIndex] ?? <int>{};
    if (selected.isEmpty) {
      showTopNotification(context, 'Выберите вариант ответа', isError: true);
      return;
    }

    if (_currentIndex < widget.quiz.questions.length - 1) {
      setState(() {
        _currentIndex += 1;
      });
      return;
    }

    final success = _isQuizPassed();
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      showTopNotification(
        context,
        'Есть неверные ответы, попробуйте ещё раз',
        isError: true,
      );
    }
  }

  void _goBack() {
    if (_currentIndex == 0) return;
    setState(() {
      _currentIndex -= 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final question = widget.quiz.questions[_currentIndex];
    final selected = _answers[_currentIndex] ?? <int>{};

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer.withValues(alpha: 0.9),
                      scheme.secondaryContainer.withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.quiz.title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Вопрос ${_currentIndex + 1} из ${widget.quiz.questions.length}',
                      style: text.bodySmall?.copyWith(color: scheme.onPrimary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(question.text, style: text.titleMedium),
                    const SizedBox(height: 8),
                    if (question.allowsMultiple)
                      Text(
                        'Можно выбрать несколько вариантов',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Text(
                        'Выберите один вариант',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 12),
                    ...question.options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      final isActive = selected.contains(index);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? scheme.primary
                                : scheme.outline.withValues(alpha: 0.6),
                          ),
                          color: isActive
                              ? scheme.primary.withValues(alpha: 0.08)
                              : scheme.surface,
                        ),
                        child: question.allowsMultiple
                            ? CheckboxListTile(
                                value: isActive,
                                onChanged: (_) => _toggleOption(index),
                                title: Text(
                                  option.text,
                                  style: text.bodyMedium,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              )
                            : ListTile(
                                onTap: () => _toggleOption(index),
                                leading: Icon(
                                  isActive
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: isActive
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                                title: Text(
                                  option.text,
                                  style: text.bodyMedium,
                                ),
                              ),
                      );
                    }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _currentIndex == 0 ? null : _goBack,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                      label: const Text('Назад'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _goNext,
                      child: Text(
                        _currentIndex == widget.quiz.questions.length - 1
                            ? 'Завершить'
                            : 'Далее',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioQuiz {
  const _PortfolioQuiz({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.successNote,
    required this.questions,
  });

  final String id;
  final String title;
  final String description;
  final int reward;
  final String successNote;
  final List<_QuizQuestion> questions;
}

class _QuizQuestion {
  const _QuizQuestion({
    required this.text,
    required this.allowsMultiple,
    required this.options,
  });

  final String text;
  final bool allowsMultiple;
  final List<_QuizOption> options;
}

class _QuizOption {
  const _QuizOption({required this.text, required this.isCorrect});

  final String text;
  final bool isCorrect;
}

const List<_PortfolioQuiz> _portfolioQuizzes = [
  _PortfolioQuiz(
    id: 'diversification',
    title: 'Базовая диверсификация',
    description:
        'Разберитесь, как распределять капитал между активами и странами, чтобы снизить волатильность.',
    reward: 5000,
    successNote:
        'Отличная работа! Вы умеете распределять риски и повышать устойчивость портфеля.',
    questions: [
      _QuizQuestion(
        text: 'Что даёт диверсификация портфеля?',
        allowsMultiple: true,
        options: [
          _QuizOption(
            text:
                'Снижает зависимость от результата одной компании или сектора',
            isCorrect: true,
          ),
          _QuizOption(
            text: 'Гарантирует фиксированную доходность 20% в год',
            isCorrect: false,
          ),
          _QuizOption(
            text: 'Смягчает просадки за счёт разных классов активов',
            isCorrect: true,
          ),
          _QuizOption(
            text: 'Уменьшает вероятность коротких просадок',
            isCorrect: true,
          ),
        ],
      ),
      _QuizQuestion(
        text:
            'Какой минимальный набор секторов помогает стартовой диверсификации?',
        allowsMultiple: false,
        options: [
          _QuizOption(text: 'Один сектор для концентрации', isCorrect: false),
          _QuizOption(text: 'Три–пять секторов', isCorrect: true),
          _QuizOption(
            text: 'Десять и более секторов всегда обязательны',
            isCorrect: false,
          ),
        ],
      ),
      _QuizQuestion(
        text: 'Как распределить валюты в долгосрочном портфеле?',
        allowsMultiple: true,
        options: [
          _QuizOption(
            text: 'Использовать одну валюту для простоты',
            isCorrect: false,
          ),
          _QuizOption(
            text: 'Смешивать основные мировые валюты и локальную',
            isCorrect: true,
          ),
          _QuizOption(
            text: 'Учитывать валюту расходов и целей',
            isCorrect: true,
          ),
          _QuizOption(text: 'Игнорировать валютные риски', isCorrect: false),
        ],
      ),
    ],
  ),
  _PortfolioQuiz(
    id: 'goals',
    title: 'Цели и горизонт',
    description:
        'Свяжите сроки, цели и риск-профиль, чтобы выбирать подходящие активы.',
    reward: 3500,
    successNote:
        'Вы умеете увязывать инвестиции с целями — это ключ к дисциплине и росту капитала.',
    questions: [
      _QuizQuestion(
        text: 'Что учитывать при выборе горизонта инвестиций?',
        allowsMultiple: true,
        options: [
          _QuizOption(text: 'Срок, когда понадобятся деньги', isCorrect: true),
          _QuizOption(text: 'Личную толерантность к риску', isCorrect: true),
          _QuizOption(text: 'Погоду на следующей неделе', isCorrect: false),
          _QuizOption(text: 'Валюту будущих расходов', isCorrect: true),
        ],
      ),
      _QuizQuestion(
        text: 'Какой инструмент чаще выбирают для цели через 1–2 года?',
        allowsMultiple: false,
        options: [
          _QuizOption(
            text: 'Краткосрочные облигации или депозиты',
            isCorrect: true,
          ),
          _QuizOption(text: 'Высокорисковые акций роста', isCorrect: false),
          _QuizOption(text: 'Долгосрочные венчурные фонды', isCorrect: false),
        ],
      ),
      _QuizQuestion(
        text: 'Как поступать с риском, если цель близка по времени?',
        allowsMultiple: false,
        options: [
          _QuizOption(
            text: 'Снижать долю рискованных активов',
            isCorrect: true,
          ),
          _QuizOption(
            text: 'Увеличивать волатильные активы ради доходности',
            isCorrect: false,
          ),
          _QuizOption(
            text: 'Не учитывать срок, если есть дивиденды',
            isCorrect: false,
          ),
        ],
      ),
    ],
  ),
  _PortfolioQuiz(
    id: 'riskcontrol',
    title: 'Контроль риска',
    description:
        'Научитесь определять приемлемые просадки и подбирать размер позиции.',
    reward: 4200,
    successNote:
        'Вы уверенно управляете просадками и контролируете риск — так держать!',
    questions: [
      _QuizQuestion(
        text: 'Что помогает удерживать риск на позиции под контролем?',
        allowsMultiple: true,
        options: [
          _QuizOption(
            text: 'Лимиты на долю позиции в портфеле',
            isCorrect: true,
          ),
          _QuizOption(text: 'Открывать позицию на весь счёт', isCorrect: false),
          _QuizOption(
            text: 'Использовать стоп-лоссы или алерты',
            isCorrect: true,
          ),
          _QuizOption(
            text: 'Игнорировать новости и просадки',
            isCorrect: false,
          ),
        ],
      ),
      _QuizQuestion(
        text: 'Какую просадку допустимо закладывать на позицию без плеча?',
        allowsMultiple: false,
        options: [
          _QuizOption(
            text: 'Любую, главное дождаться восстановления',
            isCorrect: false,
          ),
          _QuizOption(
            text: 'Ту, что соответствует личному риск-профилю и горизонту',
            isCorrect: true,
          ),
          _QuizOption(
            text: 'Фиксированно 2% для всех активов',
            isCorrect: false,
          ),
        ],
      ),
      _QuizQuestion(
        text: 'Как соотнести доходность и риск при отборе активов?',
        allowsMultiple: true,
        options: [
          _QuizOption(
            text: 'Смотреть на ожидаемую доходность без учёта волатильности',
            isCorrect: false,
          ),
          _QuizOption(
            text: 'Сравнивать потенциальную просадку с целями и горизонтом',
            isCorrect: true,
          ),
          _QuizOption(
            text: 'Не превышать заранее заданный лимит риска на портфель',
            isCorrect: true,
          ),
          _QuizOption(
            text: 'Покупать только то, что уже растёт',
            isCorrect: false,
          ),
        ],
      ),
    ],
  ),
];

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
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Активы',
            count: positionsCount,
            selected: selected == _PortfolioTab.positions,
            onTap: () => onSelected(_PortfolioTab.positions),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: 'Заявки',
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

class _PositionExpansionTile extends StatelessWidget {
  const _PositionExpansionTile({required this.position});

  final Position position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final label = position.symbol.length > 2
        ? position.symbol.substring(0, 2)
        : position.symbol;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        title: Row(
          children: [
            InstrumentAvatar(symbol: position.symbol, label: label, size: 36),
            const SizedBox(width: 4),
            Expanded(child: Text(position.symbol, style: text.titleMedium)),
          ],
        ),
        subtitle: Text(
          'Средняя ${position.averagePrice.toStringAsFixed(2)} ${position.currency}',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${position.quantity.toStringAsFixed(2)} шт.',
              style: text.bodyLarge,
            ),
            if (position.unrealisedPl != null) ...[
              const SizedBox(height: 4),
              Text(
                '${position.unrealisedPl! >= 0 ? '+' : ''}${position.unrealisedPl!.toStringAsFixed(2)} ${position.currency}',
                style: text.bodySmall?.copyWith(
                  color: position.unrealisedPl! >= 0
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _buildInfoRow(
                  context,
                  label: 'Тикер',
                  value: position.symbol,
                  description: 'Краткое название инструмента на бирже.',
                ),
                _buildInfoRow(
                  context,
                  label: 'Количество',
                  value: '${position.quantity} шт.',
                  description: 'Количество ценных бумаг в вашем портфеле.',
                ),
                _buildInfoRow(
                  context,
                  label: 'Средняя цена',
                  value: '${position.averagePrice} ${position.currency}',
                  description:
                      'Цена покупки (усредненная, если было несколько сделок).',
                ),
                _buildInfoRow(
                  context,
                  label: 'Текущая стоимость',
                  value: '${position.currentVolume} ${position.currency}',
                  description: 'Рыночная стоимость всего пакета бумаг сейчас.',
                ),
                if (position.unrealisedPl != null)
                  _buildInfoRow(
                    context,
                    label: 'Нереализованная П/У',
                    value:
                        '${position.unrealisedPl! >= 0 ? '+' : ''}${position.unrealisedPl!.toStringAsFixed(2)} ${position.currency}',
                    description:
                        'Текущая доходность позиции (прибыль или убыток).',
                  ),
                _buildInfoRow(
                  context,
                  label: 'Биржа',
                  value: position.exchange,
                  description: 'Торговая площадка, где куплен инструмент.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    required String description,
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
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
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
