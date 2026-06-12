import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/features/market/presentation/numeric_text.dart';
import 'package:aloria/features/market/presentation/positions/widgets/position_details_sheet.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:flutter/material.dart';

/// Плитка позиции в списке портфеля: аватар, тикер, средняя цена,
/// количество и нереализованная П/У. Тап открывает шторку деталей.
class PositionTile extends StatelessWidget {
  const PositionTile({super.key, required this.position});

  /// Позиция портфеля.
  final Position position;

  /// Денежная позиция (свободные рубли) — показывается как сумма, а не «шт.».
  bool get _isCash => position.symbol.toUpperCase() == 'RUB';

  /// Количество без хвоста «.00» у целых значений.
  String get _qty => position.quantity == position.quantity.roundToDouble()
      ? position.quantity.toStringAsFixed(0)
      : position.quantity.toStringAsFixed(2);

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
      onTap: () => showPositionDetails(context, position),
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
                  if (_isCash)
                    Text(
                      'Свободные деньги',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
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
                  _isCash
                      ? '${position.quantity.toStringAsFixed(2)} ₽'
                      : '$_qty шт.',
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
