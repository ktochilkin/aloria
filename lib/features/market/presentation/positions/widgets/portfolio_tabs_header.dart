import 'package:aloria/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Вкладки портфеля: позиции или заявки.
enum PortfolioTab { positions, orders }

/// Выбранная вкладка портфеля — переживает уход со страницы.
final portfolioTabProvider = StateProvider<PortfolioTab>(
  (_) => PortfolioTab.positions,
);

/// Хедер с вкладками «Позиции / Заявки» и счётчиками — подчёркнутая
/// активная вкладка над списком.
class PortfolioTabsHeader extends StatelessWidget {
  const PortfolioTabsHeader({
    super.key,
    required this.selected,
    required this.positionsCount,
    required this.ordersCount,
    required this.onSelected,
  });

  /// Активная вкладка.
  final PortfolioTab selected;

  /// Количество открытых позиций (бейдж).
  final int positionsCount;

  /// Количество активных заявок (бейдж).
  final int ordersCount;

  /// Колбэк выбора вкладки.
  final ValueChanged<PortfolioTab> onSelected;

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
            selected: selected == PortfolioTab.positions,
            onTap: () => onSelected(PortfolioTab.positions),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: l.portfolioTabOrders,
            count: ordersCount,
            selected: selected == PortfolioTab.orders,
            onTap: () => onSelected(PortfolioTab.orders),
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
