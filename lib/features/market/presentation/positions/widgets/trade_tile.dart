import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/domain/portfolio_trade.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/numeric_text.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:flutter/material.dart';

/// Плитка сделки в портфеле: что и когда купили/продали, по какой цене
/// и на какую сумму.
class TradeTile extends StatelessWidget {
  const TradeTile({super.key, required this.trade});

  /// Сделка.
  final PortfolioTrade trade;

  String _time(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$d.$mo · $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final isBuy = trade.side == OrderSide.buy;
    final sideColor = isBuy ? AppColors.success : AppColors.error;
    final label = trade.symbol.length > 2
        ? trade.symbol.substring(0, 2)
        : trade.symbol;
    final qty = trade.qty ?? trade.qtyUnits;
    final volume =
        trade.volume ?? ((trade.price ?? 0) * (trade.qtyUnits ?? qty ?? 0));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          InstrumentAvatar(symbol: trade.symbol, label: label, size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      trade.symbol,
                      style: text.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: sideColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isBuy ? 'Покупка' : 'Продажа',
                        style: text.labelMedium?.copyWith(
                          color: sideColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _time(trade.date),
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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
                trade.price != null
                    ? '${qty ?? '—'} × ${trade.price!.toStringAsFixed(2)}'
                    : '${qty ?? '—'} шт.',
                style: monoNum(size: 14, color: scheme.onSurface),
              ),
              if (volume > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${volume.toStringAsFixed(2)} ₽',
                  style: monoNum(
                    size: 13,
                    weight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
